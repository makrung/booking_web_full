const express = require('express');
const router = express.Router();
const admin = require('../../config/firebase');
const { authenticateToken } = require('../middleware/auth');

// Helpers
function tsToISO(ts) {
    try {
        if (!ts) return undefined;
        if (typeof ts.toDate === 'function') return ts.toDate().toISOString();
        if (ts instanceof Date) return ts.toISOString();
    } catch (_) {}
    return undefined;
}

function mapRequestDoc(doc) {
    const data = doc.data();
    return {
        id: doc.id,
        ...data,
        requestDate: tsToISO(data.requestDate),
        activityDate: tsToISO(data.activityDate),
        activityDates: Array.isArray(data.activityDates)
            ? data.activityDates
                    .map((d) => (typeof d?.toDate === 'function' ? d.toDate().toISOString() : undefined))
                    .filter(Boolean)
            : undefined,
        createdAt: tsToISO(data.createdAt),
        updatedAt: tsToISO(data.updatedAt),
        approvedDate: tsToISO(data.approvedDate),
    };
}

// POST: Create activity request (multi-day supported) + notifications
router.post('/activity-requests', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const userId = req.user.userId;

        const { courtId, courtName, activityDate, activityDates, responsiblePerson, activity } = req.body;

        if (!courtId || !courtName || (!activityDate && !activityDates) || !responsiblePerson || !activity) {
            return res.status(400).json({ success: false, message: 'ข้อมูลไม่ครบถ้วน' });
        }

        // Check user block and daily limit for requests
        try {
            const uDoc = await db.collection('users').doc(userId).get();
            if (uDoc.exists && uDoc.data().isRequestBlocked) {
                return res.status(403).json({ success: false, message: 'บัญชีของคุณถูกบล็อคการส่งคำขอ' });
            }
        } catch (_) {}

        // normalize dates
        let datesArray = [];
        if (Array.isArray(activityDates) && activityDates.length > 0) {
            datesArray = activityDates.map((d) => new Date(d)).filter((d) => !isNaN(d));
        } else if (activityDate) {
            const d = new Date(activityDate);
            if (!isNaN(d)) datesArray = [d];
        }
        if (datesArray.length === 0) {
            return res.status(400).json({ success: false, message: 'รูปแบบวันที่ไม่ถูกต้อง' });
        }

        // Daily limit: count activity requests created today by this user
        const today = new Date();
        const dayKey = today.toISOString().split('T')[0];
        let todayCount = 0;
        try {
            const snap = await db.collection('activityRequests')
                .where('userId', '==', userId)
                .get();
            snap.forEach(doc => {
                const cd = doc.data().createdAt;
                let key = '';
                if (cd && typeof cd.toDate === 'function') key = cd.toDate().toISOString().split('T')[0];
                else if (typeof cd === 'string') key = (cd.includes('T') ? new Date(cd).toISOString().split('T')[0] : cd);
                if (key === dayKey) todayCount++;
            });
        } catch (e) {
            console.warn('Daily limit check fallback for activity requests', e?.message || e);
        }
        if (todayCount >= 5) {
            return res.status(429).json({ success: false, message: 'วันนี้คุณส่งคำขอครบ 5 ครั้งแล้ว' });
        }

            // fetch requester profile for display
            let requesterName = undefined;
            let requesterStudentId = undefined;
            try {
                const userDoc = await db.collection('users').doc(userId).get();
                if (userDoc.exists) {
                    const u = userDoc.data();
                    requesterName = [u.firstName, u.lastName].filter(Boolean).join(' ').trim() || undefined;
                    requesterStudentId = u.studentId || u.userCode || undefined;
                }
            } catch (_) {}

            const payload = {
            userId,
            courtId,
            courtName,
            activityDate: datesArray[0],
            activityDates: datesArray,
                requesterName,
                requesterStudentId,
            responsiblePersonName: responsiblePerson.name,
            responsiblePersonId: responsiblePerson.id,
            responsiblePersonPhone: responsiblePerson.phone,
            responsiblePersonEmail: responsiblePerson.email,
            activityName: activity.name,
            activityDescription: activity.description,
            status: 'pending',
            requestDate: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        const ref = await db.collection('activityRequests').add(payload);

        // notifications (best-effort)
            try {
            const createdAt = admin.firestore.FieldValue.serverTimestamp();
            const datesText = datesArray
                .map((d) => (d instanceof Date ? d.toISOString().split('T')[0] : ''))
                .filter(Boolean)
                .join(', ');

            await db.collection('messages').add({
                userId,
                title: 'รับคำขอกิจกรรมแล้ว',
                body: `คำขอจัดกิจกรรมของคุณที่สนาม ${courtName} วันที่ ${datesText} ถูกส่งเรียบร้อย รอการอนุมัติจากแอดมิน`,
                type: 'activity_request',
                relatedId: ref.id,
                read: false,
                createdAt,
            });

            // Respect messagesBlocked flag
            let allowAdminMsg = true;
            try {
                const uDoc2 = await db.collection('users').doc(userId).get();
                if (uDoc2.exists && uDoc2.data().isMessagesBlocked) allowAdminMsg = false;
            } catch {}
            if (allowAdminMsg) {
                await db.collection('messages').add({
                    userId: 'admin',
                    title: 'มีคำขอกิจกรรมใหม่',
                        body: `${requesterName || userId} ขอจัดกิจกรรมที่สนาม ${courtName} วันที่ ${datesText}`,
                    type: 'activity_request',
                    relatedId: ref.id,
                    read: false,
                    createdAt,
                });
            }
        } catch (notifyErr) {
            console.warn('Activity request notifications failed:', notifyErr?.message || notifyErr);
        }

        res.json({ success: true, id: ref.id });
    } catch (err) {
        console.error('Error creating activity request:', err);
        res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดในการสร้างคำขอ', error: err.message });
    }
});

// GET: Admin list all activity requests (with index fallback)
router.get('/activity-requests', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const userDoc = await db.collection('users').doc(req.user.userId).get();
        if (!userDoc.exists || userDoc.data().role !== 'admin') {
            return res.status(403).json({ success: false, message: 'ไม่มีสิทธิ์เข้าถึง' });
        }

        let results = [];
        try {
            const snapshot = await db.collection('activityRequests').orderBy('requestDate', 'desc').get();
            snapshot.forEach((doc) => results.push(mapRequestDoc(doc)));
        } catch (e) {
            console.warn('Missing index for admin list, using fallback:', e?.message || e);
            const snapshot = await db.collection('activityRequests').get();
            snapshot.forEach((doc) => results.push(mapRequestDoc(doc)));
            results.sort((a, b) => (b.requestDate || '').localeCompare(a.requestDate || ''));
        }

        res.json({ success: true, activityRequests: results });
    } catch (err) {
        console.error('Error fetching activity requests:', err);
        res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดในการดึงข้อมูล', error: err.message });
    }
});

// PATCH: Admin edit an activity request fields even after approved/rejected (audit-lite)
router.patch('/activity-requests/:id', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const { id } = req.params;
        // admin only
        const userDoc = await db.collection('users').doc(req.user.userId).get();
        if (!userDoc.exists || userDoc.data().role !== 'admin') {
            return res.status(403).json({ success: false, message: 'ไม่มีสิทธิ์เข้าถึง' });
        }

        const allowed = ['activityName','activityDescription','responsiblePersonName','responsiblePersonId','responsiblePersonPhone','responsiblePersonEmail'];
        const payload = req.body || {};
        const update = {};
        for (const k of allowed) if (typeof payload[k] !== 'undefined') update[k] = payload[k];
        if (Object.keys(update).length === 0) return res.status(400).json({ success: false, message: 'ไม่มีข้อมูลสำหรับแก้ไข' });

        update.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await db.collection('activityRequests').doc(id).update(update);

        const updated = await db.collection('activityRequests').doc(id).get();
        return res.json({ success: true, activityRequest: mapRequestDoc(updated) });
    } catch (err) {
        console.error('Error editing activity request:', err);
        res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดในการแก้ไขคำขอ', error: err.message });
    }
});

// GET: My activity requests (with index fallback)
router.get('/activity-requests/my', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const userId = req.user.userId;

        let results = [];
        try {
            const snapshot = await db
                .collection('activityRequests')
                .where('userId', '==', userId)
                .orderBy('requestDate', 'desc')
                .get();
            snapshot.forEach((doc) => results.push(mapRequestDoc(doc)));
        } catch (e) {
            console.warn('Missing index for my list, using fallback:', e?.message || e);
            const snapshot = await db.collection('activityRequests').where('userId', '==', userId).get();
            snapshot.forEach((doc) => results.push(mapRequestDoc(doc)));
            results.sort((a, b) => (b.requestDate || '').localeCompare(a.requestDate || ''));
        }

        res.json({ success: true, requests: results });
    } catch (err) {
        console.error('Error fetching my activity requests:', err);
        res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดในการดึงข้อมูล', error: err.message });
    }
});

// GET: Activity requests for a specific court (accessible to authenticated users)
router.get('/activity-requests/for-court/:courtId', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const { courtId } = req.params;
        if (!courtId) return res.status(400).json({ success: false, message: 'courtId is required' });

        let results = [];
        try {
            const snapshot = await db.collection('activityRequests').where('courtId', '==', courtId).get();
            snapshot.forEach((doc) => results.push(mapRequestDoc(doc)));
        } catch (e) {
            // Fallback: scan and filter if compound index missing
            console.warn('Fallback fetch for activity-requests/for-court:', e?.message || e);
            const snapshot = await db.collection('activityRequests').get();
            snapshot.forEach((doc) => {
                const d = doc.data();
                if ((d?.courtId || '') === courtId) results.push(mapRequestDoc(doc));
            });
            // keep stable ordering
            results.sort((a, b) => (b.requestDate || '').localeCompare(a.requestDate || ''));
        }

        // Exclude rejected/cancelled requests since they should not block dates
        results = results.filter(r => {
            const s = (r.status || '').toString().toLowerCase();
            return s !== 'rejected' && s !== 'cancelled';
        });

        res.json({ success: true, activityRequests: results });
    } catch (err) {
        console.error('Error fetching activity requests for court:', err);
        res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดในการดึงข้อมูล', error: err.message });
    }
});

// PATCH: Approve/Reject request (creates bookings on approve, notify on both)
router.patch('/activity-requests/:id/status', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const { id } = req.params;
        const { status, rejectionReason } = req.body;

        const userDoc = await db.collection('users').doc(req.user.userId).get();
        if (!userDoc.exists || userDoc.data().role !== 'admin') {
            return res.status(403).json({ success: false, message: 'ไม่มีสิทธิ์เข้าถึง' });
        }

        if (!['approved', 'rejected'].includes(status)) {
            return res.status(400).json({ success: false, message: 'สถานะไม่ถูกต้อง' });
        }
        if (status === 'rejected' && (!rejectionReason || !rejectionReason.trim())) {
            return res.status(400).json({ success: false, message: 'กรุณาระบุเหตุผลเมื่อปฏิเสธคำขอ' });
        }

        const updateData = {
            status,
            approvedBy: req.user.userId,
            approvedDate: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (status === 'rejected') updateData.rejectionReason = rejectionReason;

            await db.collection('activityRequests').doc(id).update(updateData);

            const reqDoc = await db.collection('activityRequests').doc(id).get();
            const reqData = reqDoc.data();

        if (status === 'approved') {
                const dates = Array.isArray(reqData.activityDates) && reqData.activityDates.length > 0 ? reqData.activityDates : [reqData.activityDate];
                // build full-day time slots from court opening hours
                let timeSlots = [];
                try {
                    const courtDoc = await db.collection('courts').doc(reqData.courtId).get();
                    const court = courtDoc.exists ? courtDoc.data() : {};
                    const start = (court?.playStartTime || '09:00');
                    const end = (court?.playEndTime || '23:00');
                    const startH = parseInt(String(start).split(':')[0], 10);
                    const endH = parseInt(String(end).split(':')[0], 10);
                    for (let h = startH; h < endH; h++) {
                        const a = String(h).padStart(2, '0');
                        const b = String(h + 1).padStart(2, '0');
                        timeSlots.push(`${a}:00-${b}:00`);
                    }
                } catch (e) {
                    // default full day if court not found
                    for (let h = 9; h < 23; h++) {
                        const a = String(h).padStart(2, '0');
                        const b = String(h + 1).padStart(2, '0');
                        timeSlots.push(`${a}:00-${b}:00`);
                    }
                }

                // fetch user for display name/studentId
                let userName = undefined;
                let studentId = undefined;
                try {
                    const uDoc = await db.collection('users').doc(reqData.userId).get();
                    if (uDoc.exists) {
                        const u = uDoc.data();
                        userName = [u.firstName, u.lastName].filter(Boolean).join(' ').trim() || undefined;
                        studentId = u.studentId || u.userCode || undefined;
                    }
                } catch (_) {}

                const batch = db.batch();
                dates.forEach((ts) => {
                    const d = (typeof ts?.toDate === 'function' ? ts.toDate() : ts instanceof Date ? ts : null);
                    const dateStr = d ? d.toISOString().split('T')[0] : undefined;
                    const bookingRef = db.collection('bookings').doc();
                    batch.set(bookingRef, {
                        userId: reqData.userId,
                        userName: userName,
                        studentId: studentId ?? null,
                        courtId: reqData.courtId,
                        courtName: reqData.courtName,
                        date: dateStr,
                        timeSlots: timeSlots,
                        status: 'confirmed',
                        type: 'activity',
                        activityName: reqData.activityName,
                        activityDescription: reqData.activityDescription,
                        responsiblePerson: {
                            name: reqData.responsiblePersonName,
                            id: reqData.responsiblePersonId,
                            phone: reqData.responsiblePersonPhone,
                            email: reqData.responsiblePersonEmail,
                        },
                        activityRequestId: id,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                });
                await batch.commit();

                    const datesText = dates
                .map((d) => (typeof d?.toDate === 'function' ? d.toDate().toISOString().split('T')[0] : undefined))
                .filter(Boolean)
                .join(', ');
            await db.collection('messages').add({
                userId: reqData.userId,
                title: 'คำขอกิจกรรมได้รับการอนุมัติ',
                body: `แอดมินได้อนุมัติคำขอกิจกรรมที่สนาม ${reqData.courtName} สำหรับวันที่ ${datesText} แล้ว ระบบได้จองทั้งวันเรียบร้อย`,
                type: 'activity_request',
                relatedId: id,
                read: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        if (status === 'rejected') {
            await db.collection('messages').add({
                userId: reqData.userId,
                title: 'คำขอกิจกรรมไม่ได้รับการอนุมัติ',
                body: `เหตุผล: ${rejectionReason || '-'} \nคำขอที่สนาม ${reqData.courtName}`,
                type: 'activity_request',
                relatedId: id,
                read: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        res.json({ success: true, message: status === 'approved' ? 'อนุมัติคำขอเรียบร้อยแล้ว' : 'ปฏิเสธคำขอเรียบร้อยแล้ว' });
    } catch (err) {
        console.error('Error updating activity request status:', err);
        res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดในการอัปเดตสถานะ', error: err.message });
    }
});

// GET: request detail
router.get('/activity-requests/:id', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const { id } = req.params;

        const doc = await db.collection('activityRequests').doc(id).get();
        if (!doc.exists) {
            return res.status(404).json({ success: false, message: 'ไม่พบคำขอกิจกรรม' });
        }

        res.json({ success: true, activityRequest: mapRequestDoc(doc) });
    } catch (err) {
        console.error('Error fetching activity request:', err);
        res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดในการดึงข้อมูล', error: err.message });
    }
});

// DELETE: Admin delete an activity request
router.delete('/activity-requests/:id', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const { id } = req.params;
        // admin only
        const userDoc = await db.collection('users').doc(req.user.userId).get();
        if (!userDoc.exists || userDoc.data().role !== 'admin') {
            return res.status(403).json({ success: false, message: 'ไม่มีสิทธิ์เข้าถึง' });
        }
        const ref = db.collection('activityRequests').doc(id);
        const doc = await ref.get();
        if (!doc.exists) return res.status(404).json({ success: false, message: 'ไม่พบคำขอกิจกรรม' });
        await ref.delete();
        return res.json({ success: true, message: 'ลบคำขอกิจกรรมสำเร็จ' });
    } catch (err) {
        console.error('Error deleting activity request:', err);
        res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดในการลบคำขอ', error: err.message });
    }
});

module.exports = router;
