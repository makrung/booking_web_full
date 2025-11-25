const admin = require('../../config/firebase');
const { getNumericSetting, getBooleanSetting } = require('./settings.service');

// Helper: parse 'HH:MM' to minutes since midnight
function parseHHMM(str) {
	if (!str || typeof str !== 'string') return null;
	const parts = str.split(':');
	if (parts.length !== 2) return null;
	const h = Number(parts[0]);
	const m = Number(parts[1]);
	if (Number.isNaN(h) || Number.isNaN(m)) return null;
	return h * 60 + m;
}

// Helper: get earliest start time (minutes) from array of timeSlots like ['08:00-09:00', ...]
function getEarliestStartMinutes(timeSlots) {
	if (!Array.isArray(timeSlots) || timeSlots.length === 0) return null;
	let minStart = Infinity;
	for (const slot of timeSlots) {
		if (typeof slot !== 'string' || !slot.includes('-')) continue;
		const [startStr] = slot.split('-');
		const mins = parseHHMM(startStr);
		if (mins !== null) {
			minStart = Math.min(minStart, mins);
		}
	}
	return minStart === Infinity ? null : minStart;
}

// Helper: normalize booking.date to YYYY-MM-DD (supports string or Firestore timestamp)
function normalizeDateField(dateField) {
	try {
		if (!dateField) return null;
		if (typeof dateField === 'string') {
			if (dateField.includes('T')) {
				return new Date(dateField).toISOString().split('T')[0];
			}
			return dateField;
		}
		if (dateField.toDate) {
			return dateField.toDate().toISOString().split('T')[0];
		}
		return null;
	} catch {
		return null;
	}
}

// Apply penalty and consume a right for a set of users (owner + participants)
async function applyGroupPenaltyAndBan({ bookingDocRef, booking, involvedUserIds, ownerUserId, dateStr, reason }) {
	const db = admin.firestore();
	// configurable penalty for auto-cancel (no check-in within grace period)
	const penaltyPoints = await getNumericSetting('penalty_no_checkin_auto_cancel', 50);

	// Idempotency check per booking
	if (booking.noShowProcessed || booking.penaltyApplied) {
		return { skipped: true };
	}

	// Mark booking as auto-cancelled first
		await bookingDocRef.update({
		status: 'cancelled',
		autoCancelled: true,
		noShowProcessed: true,
			cancellationReason: reason || 'ไม่เช็คอินภายในเวลาที่กำหนดหลังเวลาเริ่ม',
		expiredAt: admin.firestore.FieldValue.serverTimestamp(),
		updatedAt: admin.firestore.FieldValue.serverTimestamp()
	});

	// For each user: add penalty record, deduct points, and consume rights on that date
	// Policy: No-show should additionally consume an extra right as a penalty, beyond the booking's original use
	// This makes remaining rights decrease when a no-show occurs.
	const extraPenaltyRights = Number(await getNumericSetting('no_show_extra_rights_penalty', 1));
	const rightsToIncrement = 1 /* baseline to mark the cancelled booking as consumed */ + Math.max(0, extraPenaltyRights);
	for (const uid of involvedUserIds) {
		try {
			// Create penalty entry if not exists for this booking+user
			const existing = await db.collection('penalties')
				.where('bookingId', '==', bookingDocRef.id)
				.where('userId', '==', uid)
				.limit(1)
				.get();
			if (existing.empty) {
				await db.collection('penalties').add({
					userId: uid,
					bookingId: bookingDocRef.id,
					penaltyPoints,
					  reason: reason || 'ไม่เช็คอินภายในเวลาที่กำหนดหลังเวลาเริ่ม',
					courtName: booking.courtName || null,
					bookingDate: booking.date || dateStr,
					timeSlots: booking.timeSlots || [],
					bookingType: booking.bookingType || 'regular',
					createdAt: admin.firestore.FieldValue.serverTimestamp()
				});
			}

			// Update user doc: deduct points and increment consumed right for this date
			const userRef = db.collection('users').doc(uid);
			const userSnap = await userRef.get();
			if (userSnap.exists) {
				const userData = userSnap.data();
				const currentPoints = Number(userData.points || 0);
				const newPoints = Math.max(0, currentPoints - penaltyPoints);
				const key = `consumedRightsByDate.${dateStr}`;
				await userRef.set({
					points: newPoints,
					// increment baseline + extra penalty
					[key]: admin.firestore.FieldValue.increment(rightsToIncrement),
					updatedAt: admin.firestore.FieldValue.serverTimestamp()
				}, { merge: true });
			}
		} catch (err) {
			console.error(`Failed to apply penalty/ban for user ${uid} on booking ${bookingDocRef.id}:`, err);
		}
	}

	return { skipped: false };
}

// Main worker: find today's bookings not checked-in and past configured minutes from start, then auto-cancel and penalize
async function checkAndExpireMissedCheckins() {
	const db = admin.firestore();
	const now = new Date();
	const todayStr = now.toISOString().split('T')[0];
	const nowMinutes = now.getHours() * 60 + now.getMinutes();

	// Query pending bookings
	const pendingSnap = await db.collection('bookings')
		.where('status', '==', 'pending')
		.get();
	// Query confirmed bookings
	const confirmedSnap = await db.collection('bookings')
		.where('status', '==', 'confirmed')
		.get();

	const candidates = [...pendingSnap.docs, ...confirmedSnap.docs];

	for (const doc of candidates) {
		const data = doc.data();
		// ข้ามการตรวจสอบ auto-cancel สำหรับการจองที่แอดมินสร้าง
		if (data.adminCreated === true) continue;
		const dateStr = normalizeDateField(data.date);
		if (dateStr !== todayStr) continue; // only process today

		// Do not penalize activity bookings
		const bType = (data.bookingType || data.type || 'regular');
		if (String(bType).toLowerCase() === 'activity') continue;

		// Skip if already checked in according to current policy
		let requireQR = true, requireLoc = true;
		try {
			requireQR = await getBooleanSetting('require_qr_verification', true);
		} catch {}
		try {
			requireLoc = await getBooleanSetting('require_location_verification', true);
		} catch {}
		const hasQR = data.isQRVerified === true;
		const hasLoc = data.isLocationVerified === true;
		const isCheckedIn = data.status === 'checked-in';
		const consideredVerified = isCheckedIn && (!requireQR || hasQR) && (!requireLoc || hasLoc);
		if (consideredVerified) continue;

		const earliestStart = getEarliestStartMinutes(data.timeSlots);
		if (earliestStart === null) continue;

				// If now is more than configured minutes after earliest start and not checked-in yet
				const graceMins = await getNumericSetting('checkin_grace_minutes', 15);
				if (nowMinutes > (earliestStart + Number(graceMins))) {
			const ownerId = data.userId;
			const participants = Array.isArray(data.participantsUserIds) ? data.participantsUserIds : [];
			const involved = [ownerId, ...participants].filter(Boolean);
			await applyGroupPenaltyAndBan({
				bookingDocRef: doc.ref,
				booking: data,
				involvedUserIds: involved,
				ownerUserId: ownerId,
				dateStr,
						reason: `ไม่เช็คอินภายใน ${graceMins} นาทีหลังเวลาเริ่ม (ยกเลิกอัตโนมัติ)`
			});
		}
	}
}

let intervalHandle = null;

function startBookingExpiryWatcher({ intervalMs = 60 * 1000 } = {}) {
	if (intervalHandle) return; // already running
	console.log(`🕒 Starting booking expiry watcher (interval ${intervalMs} ms)`);
	intervalHandle = setInterval(async () => {
		try {
			await checkAndExpireMissedCheckins();
		} catch (err) {
			console.error('Error in booking expiry watcher:', err);
		}
	}, intervalMs);
}

function stopBookingExpiryWatcher() {
	if (intervalHandle) {
		clearInterval(intervalHandle);
		intervalHandle = null;
	}
}

module.exports = {
	startBookingExpiryWatcher,
	stopBookingExpiryWatcher,
	checkAndExpireMissedCheckins,
	// export helpers for potential reuse
	parseHHMM,
	getEarliestStartMinutes,
	normalizeDateField
};

