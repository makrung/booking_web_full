const express = require('express');
const router = express.Router();
const admin = require('../../config/firebase');
const { authenticateToken } = require('../middleware/auth');
const { isBookingActuallyExpired } = require('../../penalty-protection');
const { checkAndExpireMissedCheckins } = require('../services/booking_expiry_service');
const { getNumericSetting, getBooleanSetting } = require('../services/settings.service');

function isAllowedUniversityEmail(email) {
    if (!email || typeof email !== 'string') return false;
    const e = email.toLowerCase().trim();
    return e.endsWith('@silpakorn.edu') || e.endsWith('@su.ac.th');
}

// ดูรายการการจองทั้งหมด (ต้อง login)
router.get('/bookings', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const bookingsRef = db.collection('bookings');
        const snapshot = await bookingsRef.get();
        
        const bookings = [];
        snapshot.forEach(doc => {
            bookings.push({
                id: doc.id,
                ...doc.data()
            });
        });

        res.json({ success: true, bookings });
    } catch (err) {
        console.error('Get bookings error:', err);
        res.status(500).json({ success: false, error: err.message });
    }
});

// ดูรายการการจองทั้งหมด (สำหรับ Schedule page)
router.get('/all-bookings', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        console.log('Fetching all bookings for schedule view...'); // Debug
        
        const bookingsRef = db.collection('bookings');
        const snapshot = await bookingsRef.get();
        
        const bookings = [];
        snapshot.forEach(doc => {
            const data = doc.data();
            bookings.push({
                id: doc.id,
                ...data,
                // แปลง timestamp เป็น ISO string
                createdAt: data.createdAt ? data.createdAt.toDate().toISOString() : null,
                updatedAt: data.updatedAt ? data.updatedAt.toDate().toISOString() : null
            });
        });

        console.log(`Returning ${bookings.length} bookings for schedule`);
        res.json({ success: true, bookings });
    } catch (err) {
        console.error('Get all bookings error:', err);
        res.status(500).json({ success: false, error: err.message });
    }
});

// ดูรายการการจองของผู้ใช้ที่ล็อกอิน
router.get('/user-bookings', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        console.log('Fetching bookings for user:', req.user.userId); // Debug
        
        const ownedSnap = await db.collection('bookings')
            .where('userId', '==', req.user.userId)
            .get();
        const partSnap = await db.collection('bookings')
            .where('participantsUserIds', 'array-contains', req.user.userId)
            .get();

        console.log('Found owned bookings:', ownedSnap.size, 'participant bookings:', partSnap.size); // Debug

        const bookingsMap = new Map();

        const pushWithRole = (doc, role) => {
            const data = doc.data();
            const item = {
                id: doc.id,
                ...data,
                role: role, // 'owner' | 'participant'
                createdAt: data.createdAt ? data.createdAt.toDate().toISOString() : null,
                updatedAt: data.updatedAt ? data.updatedAt.toDate().toISOString() : null
            };
            bookingsMap.set(doc.id, item);
        };

        ownedSnap.forEach(doc => pushWithRole(doc, 'owner'));
        partSnap.forEach(doc => pushWithRole(doc, 'participant'));

        const bookings = Array.from(bookingsMap.values());
        bookings.sort((a, b) => {
            const dateA = new Date(a.createdAt || 0);
            const dateB = new Date(b.createdAt || 0);
            return dateB - dateA; // desc order
        });

        console.log('Returning bookings:', bookings.length); // Debug
        res.json({ success: true, bookings });
    } catch (err) {
        console.error('Get user bookings error:', err);
        res.status(500).json({ success: false, error: err.message });
    }
});

// ดูรายการการจองในวันที่เฉพาะ (Schedule)
router.get('/schedule/:date', authenticateToken, async (req, res) => {
    try {
        const { date } = req.params; // รูปแบบ YYYY-MM-DD
        const db = admin.firestore();
        
        console.log(`📅 Fetching schedule for date: ${date}`);
        
        // ดึงการจองทั้งหมดในวันนั้น โดยไม่กรองการจองที่ยกเลิกแล้ว
        const bookingsRef = db.collection('bookings');
        const snapshot = await bookingsRef.get();
        
        const relevantBookings = [];
        snapshot.forEach(doc => {
            const data = doc.data();
            let bookingDate = '';
            
            // จัดการ date field ที่อาจเป็น string หรือ timestamp
            if (typeof data.date === 'string') {
                if (data.date.includes('T')) {
                    // ISO string format
                    bookingDate = new Date(data.date).toISOString().split('T')[0];
                } else {
                    // Date string format
                    bookingDate = data.date;
                }
            } else if (data.date && data.date.toDate) {
                // Firestore timestamp
                bookingDate = data.date.toDate().toISOString().split('T')[0];
            }
            
            if (bookingDate === date) {
                relevantBookings.push({
                    id: doc.id,
                    ...data,
                    // แปลง timestamp เป็น ISO string
                    createdAt: data.createdAt ? data.createdAt.toDate().toISOString() : null,
                    updatedAt: data.updatedAt ? data.updatedAt.toDate().toISOString() : null
                });
            }
        });

        console.log(`📊 Found ${relevantBookings.length} bookings for ${date}`);
        res.json({ success: true, bookings: relevantBookings });
    } catch (err) {
        console.error('Get schedule error:', err);
        res.status(500).json({ success: false, error: err.message });
    }
});

// สร้างการจองใหม่
router.post('/bookings', authenticateToken, async (req, res) => {
    try {
        const { 
            courtId, 
            courtType, 
            courtName, 
            date, 
            timeSlots, 
            activityType, 
            note,
            bookingType, 
            responsiblePerson, 
            activity, 
            participantCodes 
        } = req.body;

        console.log('📋 Create booking request received:');
        console.log('   Court:', courtId, '(' + courtName + ')');
        console.log('   Date:', date);
        console.log('   Time slots:', timeSlots);
        console.log('   Booking type:', bookingType);
        console.log('   User:', req.user.userId, '(' + req.user.userName + ')');

    const db = admin.firestore();

                
        let isAdmin = false;
        try {
            const meDoc = await db.collection('users').doc(req.user.userId).get();
            if (meDoc.exists) {
                const me = meDoc.data();
                if ((me.role || '').toString() === 'admin') isAdmin = true;
                                // Enforce booking domain policy for non-admins
                                if (!isAdmin) {
                                    const allowNonUniBooking = await getBooleanSetting('allow_non_university_booking', true);
                                    if (!allowNonUniBooking && !isAllowedUniversityEmail(me.email || '')) {
                                        return res.status(403).json({ success: false, error: 'บัญชีอีเมลของคุณไม่ได้รับอนุญาตให้จอง กรุณาใช้ @silpakorn.edu หรือ @su.ac.th' });
                                    }
                                }
            }
            // เผื่อกรณี token แบบ system_admin (เข้ากันได้กับส่วนอื่นของระบบ)
            if (!isAdmin && req.user && req.user.id === 'admin' && req.user.isAdmin === true) {
                isAdmin = true;
            }
        } catch (_) {}

        // ตรวจสอบข้อมูลพื้นฐาน
        if (!courtId || !date || !timeSlots || timeSlots.length === 0) {
            return res.status(400).json({ 
                success: false, 
                error: 'ข้อมูลไม่ครบถ้วน' 
            });
        }

        // ตรวจสอบว่าผู้ใช้ถูกบล็อคการส่งคำขอหรือไม่ (ยกเว้นแอดมิน)
        if (!isAdmin) {
            try {
                const blockDoc = await db.collection('users').doc(req.user.userId).get();
                if (blockDoc.exists && blockDoc.data().isRequestBlocked) {
                    return res.status(403).json({ success: false, error: 'บัญชีของคุณถูกบล็อคการส่งคำขอ' });
                }
            } catch (_) {}
        }

        // ตรวจสอบว่าผู้ใช้ถูกแบนการจองในวันเดียวกันหรือไม่ (จากการลงโทษไม่เช็คอิน)
        const requesterUserDoc = await db.collection('users').doc(req.user.userId).get();
        if (!isAdmin && requesterUserDoc.exists) {
            const rUser = requesterUserDoc.data();
            const banDate = rUser.bookingBanDate || null;
            const targetDate = new Date(date).toISOString().split('T')[0];
            if (banDate && banDate === targetDate) {
                return res.status(403).json({
                    success: false,
                    error: 'คุณถูกจำกัดสิทธิ์การจองสำหรับวันนี้ เนื่องจากการผิดกติกาก่อนหน้านี้'
                });
            }
        }

        // ลิมิตการส่งคำขอการจอง: วันละ 5 ครั้ง ต่อผู้ใช้
        if (!isAdmin) {
            try {
                const todayKey = new Date().toISOString().split('T')[0];
                let todayCreates = 0;
                const snap = await db.collection('bookings')
                    .where('userId', '==', req.user.userId)
                    .get();
                snap.forEach(doc => {
                    const cd = doc.data().createdAt;
                    let key = '';
                    if (cd && typeof cd.toDate === 'function') key = cd.toDate().toISOString().split('T')[0];
                    else if (typeof cd === 'string') key = (cd.includes('T') ? new Date(cd).toISOString().split('T')[0] : cd);
                    if (key === todayKey) todayCreates++;
                });
                if (todayCreates >= 5) {
                    return res.status(429).json({ success: false, error: 'วันนี้คุณส่งคำขอจองครบ 5 ครั้งแล้ว' });
                }
            } catch (e) {
                console.warn('Daily booking request limit check fallback:', e?.message || e);
            }
        }

    // ตรวจสอบว่าผู้ใช้จองในวันนี้แล้วหรือยัง (จำกัดจำนวนครั้งต่อวันแบบกำหนดได้)
    const dailyRights = await getNumericSetting('daily_rights_per_user', 1);
        console.log(`🔍 Checking if user ${req.user.userId} already has booking on ${date}`);
        
        // แปลง date เป็น string format ที่ถูกต้อง และหา date ที่ตรงกัน
        const targetDate = new Date(date).toISOString().split('T')[0]; // เช่น 2025-08-06
        console.log(`📅 Normalized target date: ${targetDate}`);
        
        // ดึงการจองทั้งหมดของผู้ใช้และกรองตามวันที่
        const allUserBookingsQuery = await db.collection('bookings')
            .where('userId', '==', req.user.userId)
            .get();
            
        console.log(`📊 Found ${allUserBookingsQuery.size} total bookings for user`);
        
        let userBookingsToday = 0;
        const todayBookings = [];
        
        allUserBookingsQuery.forEach((doc) => {
            const data = doc.data();
            let bookingDate = '';
            
            // จัดการ date field ที่อาจเป็น string หรือ timestamp
            if (typeof data.date === 'string') {
                if (data.date.includes('T')) {
                    // ISO string format
                    bookingDate = new Date(data.date).toISOString().split('T')[0];
                } else {
                    // Date string format
                    bookingDate = data.date;
                }
            } else if (data.date && data.date.toDate) {
                // Firestore timestamp
                bookingDate = data.date.toDate().toISOString().split('T')[0];
            }
            
            console.log(`📊 Checking booking ${doc.id}: date=${data.date}, normalized=${bookingDate}, status=${data.status}`);
            
            // ตรวจสอบว่าเป็นวันเดียวกันและสถานะที่ยังใช้งานได้ (ไม่รวมการจองที่ยกเลิกแล้ว)
            if (bookingDate === targetDate && ['pending', 'confirmed', 'checked-in', 'completed'].includes(data.status)) {
                userBookingsToday++;
                todayBookings.push({id: doc.id, ...data});
                console.log(`✅ Match found: ${doc.id} - Court: ${data.courtName}, Status: ${data.status}, TimeSlots: ${JSON.stringify(data.timeSlots)}`);
            } else if (bookingDate === targetDate && data.status === 'cancelled') {
                console.log(`🚫 Cancelled booking found: ${doc.id} - Court: ${data.courtName}, Status: ${data.status} (ignored)`);
            }
        });
        
        // อ่านสิทธิพิเศษรายผู้ใช้ (ค่าเริ่มต้น 0) และคำนวณสิทธิรวม
        let extraDailyRights = 0;
        try {
            const uDoc = await db.collection('users').doc(req.user.userId).get();
            if (uDoc.exists) extraDailyRights = Number(uDoc.data().extraDailyRights || 0) || 0;
        } catch (_) {}
        const effectiveDailyRights = Math.max(0, Number(dailyRights)) + Math.max(0, Number(extraDailyRights));

        console.log(`📊 Found ${userBookingsToday} existing bookings for user today (limit ${effectiveDailyRights} = base ${dailyRights} + extra ${extraDailyRights})`);
        
        if (!isAdmin && userBookingsToday >= effectiveDailyRights) {
            console.log(`❌ User already has ${userBookingsToday} booking(s) today`);
            
            // ตรวจสอบว่ามีการจอง pending หรือไม่
            const pendingBookings = todayBookings.filter(booking => booking.status === 'pending');
            const nonPendingBookings = todayBookings.filter(booking => booking.status !== 'pending');
            
            if (nonPendingBookings.length > 0) {
                console.log(`❌ User has non-pending bookings, cannot auto-cancel`);
                return res.status(400).json({ 
                    success: false, 
                    error: 'คุณมียอดการจองถึงจำนวนสูงสุดของวันนี้แล้ว ไม่สามารถจองเพิ่มได้' 
                });
            }
            
            if (pendingBookings.length > 0) {
                // ส่งข้อมูลการจอง pending กลับไปให้ frontend ตัดสินใจ
                console.log(`🤔 User has pending bookings, requesting confirmation`);
                return res.status(409).json({ 
                    success: false,
                    requiresConfirmation: true,
                    error: 'คุณมีการจองที่รอยืนยันอยู่แล้ว ต้องการยกเลิกการจองเดิมเพื่อจองใหม่หรือไม่?',
                    existingBookings: pendingBookings.map(booking => ({
                        id: booking.id,
                        courtId: booking.courtId, // include courtId for precise matching on frontend
                        courtName: booking.courtName,
                        timeSlots: booking.timeSlots,
                        date: booking.date,
                        status: booking.status
                    })),
                    newBookingData: {
                        courtId,
                        courtType,
                        courtName,
                        date,
                        timeSlots,
                        activityType,
                        note,
                        bookingType
                    }
                });
            }
        }

        // โหลดข้อมูลสนามจาก Firestore เพื่ออ่านจำนวนผู้เล่นและช่วงเวลาเปิดปิด
        const courtDoc = await db.collection('courts').doc(courtId).get();
        if (!courtDoc.exists) {
            return res.status(404).json({ success: false, error: 'ไม่พบข้อมูลสนาม' });
        }
        const courtData = courtDoc.data();
        const defaultRequiredByCategory = {
            badminton: 2,
            tennis: 2,
            futsal: 10,
            football: 22,
            basketball: 10,
            volleyball: 10,
            multipurpose: 10
        };
    const requiredPlayers = courtData.requiredPlayers || defaultRequiredByCategory[courtData.category] || 2;

        // ตรวจสอบโค้ดผู้เข้าร่วมให้ครบ (ยกเว้นแอดมิน) — นับรวมผู้จองโดยอัตโนมัติ
        const codes = Array.isArray(participantCodes) ? participantCodes.map(c => String(c).trim().toUpperCase()).filter(Boolean) : [];
        const uniqueCodes = [...new Set(codes)];
        const requiredParticipantCount = Math.max(0, requiredPlayers - 1);
        if (!isAdmin) {
            if (uniqueCodes.length !== requiredParticipantCount) {
                return res.status(400).json({
                    success: false,
                    error: `ต้องกรอกรหัสผู้เข้าร่วมให้ครบ ${requiredParticipantCount} คน`
                });
            }
        }

        // ดึง userCode ของผู้จอง
        const userDoc = await db.collection('users').doc(req.user.userId).get();
        const bookingUserData = userDoc.exists ? userDoc.data() : null;
        const ownerCode = bookingUserData?.userCode;
        // ผู้ใช้ทั่วไปต้องมีรหัสประจำตัว แต่แอดมินไม่จำเป็นต้องมี
        if (!isAdmin) {
            if (!ownerCode) {
                return res.status(400).json({ success: false, error: 'บัญชีผู้ใช้ยังไม่มีรหัสประจำตัว กรุณาออกจากระบบและเข้าสู่ระบบใหม่' });
            }
            if (uniqueCodes.includes(ownerCode)) {
                return res.status(400).json({ success: false, error: 'ห้ามใส่รหัสของตนเอง' });
            }
            // บล็อกการจองหากคะแนนเจ้าของเป็น 0
            const ownerPoints = (bookingUserData?.points ?? 0);
            if (ownerPoints <= 0) {
                return res.status(400).json({ success: false, error: 'คะแนนของคุณเป็น 0 ไม่สามารถจองได้ กรุณาส่งคำขอเพิ่มคะแนน' });
            }
        }

        // แปลงโค้ดเป็นผู้ใช้ ตรวจสอบสถานะ
        const participantUsers = [];
        if (!isAdmin) {
            for (const code of uniqueCodes) {
                const snap = await db.collection('users').where('userCode', '==', code).limit(1).get();
                if (snap.empty) {
                    return res.status(400).json({ success: false, error: `ไม่พบรหัสผู้ใช้: ${code}` });
                }
                const uDoc = snap.docs[0];
                const u = uDoc.data();
                if (!u.isActive || !u.isEmailVerified) {
                    return res.status(400).json({ success: false, error: `รหัส ${code} ไม่พร้อมใช้งาน (บัญชีไม่ได้เปิดใช้งานหรือยังไม่ยืนยันอีเมล)` });
                }
                // ผู้เข้าร่วมต้องมีคะแนนมากกว่า 0 เช่นกัน
                const pPoints = (u.points || 0);
                if (pPoints <= 0) {
                    return res.status(400).json({ success: false, error: `รหัส ${code} มีคะแนนเป็น 0 ไม่สามารถใช้จองได้` });
                }
                participantUsers.push({ userId: uDoc.id, userName: `${u.firstName} ${u.lastName}`, userCode: code });
            }
        }

        // ตรวจสอบสิทธิ์รายบุคคลตามจำนวนสิทธิ์ต่อวัน (เจ้าของ + ผู้เข้าร่วม)
        // กติกาใหม่: อนุญาตให้ใช้สิทธิ์ได้ตามจำนวนที่เหลือ แม้จะเคยยกเลิกแล้วก่อนหน้านี้ (ถ้าไม่ใช่ late-cancel ที่นับสิทธิ์ไปแล้ว)
    const involved = [req.user.userId, ...participantUsers.map(p => p.userId)];
        const targetDateForQuota = new Date(date).toISOString().split('T')[0];

        async function normalizeDateField(dateField) {
            try {
                if (!dateField) return null;
                if (typeof dateField === 'string') {
                    if (dateField.includes('T')) return new Date(dateField).toISOString().split('T')[0];
                    return dateField;
                }
                if (dateField.toDate) return dateField.toDate().toISOString().split('T')[0];
                return null;
            } catch (_) { return null; }
        }

        async function countActiveInvolvements(uid, dateStr) {
            // นับการมีส่วนร่วมทั้ง owner และ participant เฉพาะสถานะที่ยังใช้งานได้
            const activeStatuses = ['pending', 'confirmed', 'checked-in', 'completed'];
            let count = 0;
            const [ownedSnap, partSnap] = await Promise.all([
                db.collection('bookings').where('userId', '==', uid).get(),
                db.collection('bookings').where('participantsUserIds', 'array-contains', uid).get()
            ]);
            for (const d of ownedSnap.docs) {
                const data = d.data();
                const ds = await normalizeDateField(data.date);
                if (ds === dateStr && activeStatuses.includes(data.status)) count++;
            }
            for (const d of partSnap.docs) {
                const data = d.data();
                const ds = await normalizeDateField(data.date);
                if (ds === dateStr && activeStatuses.includes(data.status)) count++;
            }
            return count;
        }

        async function getConsumedRights(uid, dateStr) {
            try {
                const uDoc = await db.collection('users').doc(uid).get();
                if (!uDoc.exists) return 0;
                const map = uDoc.data().consumedRightsByDate || {};
                const v = map && map[dateStr];
                const n = Number(v || 0);
                return Number.isFinite(n) ? Math.max(0, n) : 0;
            } catch (_) { return 0; }
        }

        async function getEffectiveRights(uid) {
            // base from settings + per-user extraDailyRights
            let extra = 0;
            try {
                const uDoc = await db.collection('users').doc(uid).get();
                if (uDoc.exists) extra = Number(uDoc.data().extraDailyRights || 0) || 0;
            } catch (_) {}
            const base = Math.max(0, Number(await getNumericSetting('daily_rights_per_user', 1)));
            return base + Math.max(0, extra);
        }

        if (!isAdmin) {
            for (const uid of involved) {
                const [activeCount, consumedCount, limit] = await Promise.all([
                    countActiveInvolvements(uid, targetDateForQuota),
                    getConsumedRights(uid, targetDateForQuota),
                    getEffectiveRights(uid)
                ]);
                const usedTotal = activeCount + consumedCount;
                if (usedTotal >= limit) {
                    // ระบุว่า user ใดเต็มสิทธิ์แล้ว
                    let codeOrName = 'ผู้ใช้ในกลุ่ม';
                    try {
                        const uDoc = await db.collection('users').doc(uid).get();
                        if (uDoc.exists) {
                            const u = uDoc.data();
                            codeOrName = u.userCode || `${u.firstName || ''} ${u.lastName || ''}`.trim() || codeOrName;
                        }
                    } catch (_) {}
                    return res.status(400).json({
                        success: false,
                        error: `รหัส ${codeOrName} ใช้สิทธิ์ครบ ${limit} ครั้งในวันนี้แล้ว ไม่สามารถจองเพิ่มได้`
                    });
                }
            }
        }

        // ตรวจสอบว่าช่วงเวลาที่เลือกถูกจองแล้วหรือไม่ (ทุกคน)
        console.log(`🔍 Checking time slot conflicts for court ${courtId} on ${date}`);
        console.log(`🕐 Time slots to check: ${JSON.stringify(timeSlots)}`);
        
        // แปลง date เป็น string format ที่ถูกต้อง
        const targetDateForSlots = new Date(date).toISOString().split('T')[0];
        console.log(`📅 Normalized target date for time slot check: ${targetDateForSlots}`);
        
        // ดึงการจองทั้งหมดในวันและสนามนั้นก่อน เพื่อ debug (ไม่ใช้ date query เพราะ format ไม่ตรงกัน)
        const allBookingsInCourt = await db.collection('bookings')
            .where('courtId', '==', courtId)
            .get();
            
        console.log(`📊 Total bookings in court ${courtId}: ${allBookingsInCourt.size}`);
        
        // กรองเฉพาะการจองในวันนั้นและสถานะที่ยังใช้งานได้ (ไม่รวมการจองที่ยกเลิกแล้ว)
        const relevantBookings = [];
        allBookingsInCourt.forEach((doc) => {
            const data = doc.data();
            let bookingDate = '';
            
            // จัดการ date field ที่อาจเป็น string หรือ timestamp
            if (typeof data.date === 'string') {
                if (data.date.includes('T')) {
                    // ISO string format
                    bookingDate = new Date(data.date).toISOString().split('T')[0];
                } else {
                    // Date string format
                    bookingDate = data.date;
                }
            } else if (data.date && data.date.toDate) {
                // Firestore timestamp
                bookingDate = data.date.toDate().toISOString().split('T')[0];
            }
            
            // ตรวจสอบว่าเป็นวันเดียวกันและสถานะที่ยังใช้งานได้ (ไม่รวมการจองที่ยกเลิกแล้ว)
            if (bookingDate === targetDateForSlots && ['pending', 'confirmed', 'checked-in'].includes(data.status)) {
                relevantBookings.push({id: doc.id, ...data});
                console.log(`📋 Relevant booking: ${doc.id} - User: ${data.userId} (${data.userName}), Status: ${data.status}, TimeSlots: ${JSON.stringify(data.timeSlots)}`);
            } else if (bookingDate === targetDateForSlots && data.status === 'cancelled') {
                console.log(`🚫 Cancelled booking found: ${doc.id} - User: ${data.userId}, Status: ${data.status} (ignored)`);
            }
        });
        
        console.log(`📊 Found ${relevantBookings.length} relevant bookings for today`);
        
        for (const timeSlot of timeSlots) {
            console.log(`🔍 Checking time slot: ${timeSlot}`);
            
            // ตรวจสอบว่ามีการจองในช่วงเวลานี้หรือไม่
            const conflictingBookings = relevantBookings.filter(booking => {
                return booking.timeSlots && booking.timeSlots.includes(timeSlot);
            });
            
            console.log(`🔍 Found ${conflictingBookings.length} conflicting bookings for slot ${timeSlot}`);
            
            if (conflictingBookings.length > 0) {
                // Log ข้อมูลการจองที่ซ้ำ
                conflictingBookings.forEach((booking) => {
                    console.log(`❌ Conflict found: ${booking.id} - User: ${booking.userId} (${booking.userName}), Status: ${booking.status}, TimeSlots: ${JSON.stringify(booking.timeSlots)}`);
                });
                
                return res.status(400).json({ 
                    success: false, 
                    error: `ช่วงเวลา ${timeSlot} มีการจองแล้วโดย ${conflictingBookings[0].userName || 'ผู้ใช้อื่น'}` 
                });
            }
        }

        // สร้างการจองใหม่ (หลีกเลี่ยง undefined ที่ Firestore ไม่รองรับ)
        // กำหนดค่าให้ปลอดภัยจาก undefined
        const safeStudentId = (req.user && typeof req.user.studentId !== 'undefined') ? req.user.studentId : null;
        const safeCourtType = (typeof courtType !== 'undefined' && courtType !== null)
            ? courtType
            : (courtData.type || courtData.category || null);
        const safeCourtName = (typeof courtName !== 'undefined' && courtName !== null)
            ? courtName
            : (courtData.name || null);

        const bookingData = {
            userId: req.user.userId,
            userName: req.user.userName,
            studentId: safeStudentId, // ใช้ null แทน undefined
            courtId: courtId,
            courtType: safeCourtType, // ใช้ข้อมูลจากสนามถ้า client ไม่ส่งมา
            courtName: safeCourtName,
            date: date,
            timeSlots: timeSlots,
            activityType: activityType || 'ไม่ระบุ',
            note: note || '',
            bookingType: bookingType || 'regular', // 'regular' หรือ 'activity'
            status: isAdmin ? 'checked-in' : 'pending', // แอดมินจองเสร็จและเช็คอินทันที
            isLocationVerified: isAdmin ? true : false, // แอดมินไม่ต้องยืนยันตำแหน่ง
            isQRVerified: isAdmin ? true : false, // แอดมินไม่ต้องยืนยัน QR Code
            verified: false, // ยังไม่ได้ตรวจสอบการใช้งานจริง
            requiredPlayers: requiredPlayers,
            participants: participantUsers,
            participantsUserIds: participantUsers.map(p => p.userId),
            participantCodes: uniqueCodes,
            adminCreated: isAdmin ? true : false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            ...(isAdmin ? { confirmedAt: admin.firestore.FieldValue.serverTimestamp() } : {}),
            ...(isAdmin ? { checkedInAt: admin.firestore.FieldValue.serverTimestamp() } : {}),
        };

        // เพิ่มข้อมูลสำหรับการจองกิจกรรม
        if (bookingType === 'activity' && responsiblePerson) {
            bookingData.responsiblePerson = responsiblePerson;
        }
        if (bookingType === 'activity' && activity) {
            bookingData.activity = activity;
        }

        const bookingRef = await db.collection('bookings').add(bookingData);
        console.log(`✅ Booking created successfully with ID: ${bookingRef.id}`);

        // แจ้งเตือนให้ผู้ที่ถูกใช้รหัสทราบ (ยกเว้นเจ้าของสิทธิ์เอง ซึ่งไม่ถูกอนุญาตให้ใส่รหัสตัวเองอยู่แล้ว)
        try {
            const whenStr = Array.isArray(timeSlots) && timeSlots.length > 0 ? timeSlots.join(', ') : '';
            for (const p of participantUsers) {
                try {
                    await db.collection('messages').add({
                        userId: p.userId,
                        type: 'code_usage_notice',
                        title: 'มีการใช้รหัสของคุณในการจองสนาม',
                        body: `ผู้ใช้ ${req.user.userName || ''}${(safeStudentId ? ` (${safeStudentId})` : '')} ได้นำรหัสของคุณ (${p.userCode}) ไปใช้ในการจองสนาม ${safeCourtName || ''} วันที่ ${new Date(date).toISOString().split('T')[0]}${whenStr ? ` เวลา ${whenStr}` : ''}`,
                        relatedId: bookingRef.id,
                        read: false,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                } catch (msgErr) {
                    console.warn('Failed to create code usage message for participant', p.userId, msgErr?.message || msgErr);
                }
            }
        } catch (e) {
            console.warn('Code usage notification failed:', e?.message || e);
        }

    // Load configurable auto-cancel penalty for warning text (regular only)
    const autoPenalty = await getNumericSetting('penalty_no_checkin_auto_cancel', 50);

        // Tailor success message based on QR requirement
        let successMsg;
        try {
            const requireQRMsg = await getBooleanSetting('require_qr_verification', true);
            successMsg = bookingType === 'activity'
                ? (requireQRMsg ? 'จองกิจกรรมสำเร็จ กรุณามาแสกน QR Code ในวันและเวลาที่จอง' : 'จองกิจกรรมสำเร็จ โปรดปฏิบัติตามขั้นตอนในวันและเวลาที่จอง')
                : (requireQRMsg ? 'จองสนามสำเร็จ กรุณามาแสกน QR Code ในวันและเวลาที่จอง' : 'จองสนามสำเร็จ โปรดปฏิบัติตามขั้นตอนในวันและเวลาที่จอง');
        } catch (_) {
            successMsg = bookingType === 'activity'
                ? 'จองกิจกรรมสำเร็จ กรุณามาแสกน QR Code ในวันและเวลาที่จอง'
                : 'จองสนามสำเร็จ กรุณามาแสกน QR Code ในวันและเวลาที่จอง';
        }

        res.status(201).json({
            success: true,
            message: successMsg,
            bookingId: bookingRef.id,
            warning: bookingType === 'activity'
                ? 'การจองกิจกรรม: ระบบไม่หักคะแนนอัตโนมัติกรณีไม่เช็คอิน'
                : 'หากไม่ได้เช็คอินตามเวลาที่กำหนด ระบบจะยกเลิกและหักคะแนน ' + String(autoPenalty) + ' คะแนน',
            bookingData: {
                ...bookingData,
                id: bookingRef.id
            }
        });
    } catch (err) {
        console.error('Create booking error:', err);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการจองสนาม'
        });
    }
});

// ยืนยันการยกเลิกการจองเดิมและสร้างการจองใหม่
router.post('/bookings/confirm-replace', authenticateToken, async (req, res) => {
    try {
        const {
            bookingIdsToCancel,
            newBookingData
        } = req.body;

        const db = admin.firestore();

        console.log('🔄 Confirm replace booking request:');
        console.log('   Bookings to cancel:', bookingIdsToCancel, `(type: ${typeof bookingIdsToCancel}, length: ${bookingIdsToCancel?.length})`);
        console.log('   New booking data:', newBookingData);

        // ตรวจสอบว่า bookingIdsToCancel เป็น array ของ string
        if (!Array.isArray(bookingIdsToCancel)) {
            return res.status(400).json({
                success: false,
                error: 'bookingIdsToCancel must be an array'
            });
        }

        for (let i = 0; i < bookingIdsToCancel.length; i++) {
            if (typeof bookingIdsToCancel[i] !== 'string') {
                console.log(`❌ Invalid booking ID at index ${i}: ${bookingIdsToCancel[i]} (type: ${typeof bookingIdsToCancel[i]})`);
                return res.status(400).json({
                    success: false,
                    error: `Invalid booking ID type at index ${i}: expected string, got ${typeof bookingIdsToCancel[i]}`
                });
            }
        }

        // ตรวจสอบว่าการจองที่จะยกเลิกเป็นของผู้ใช้จริงหรือไม่
        const batch = db.batch();
        
        for (const bookingId of bookingIdsToCancel) {
            const bookingDoc = await db.collection('bookings').doc(bookingId).get();
            if (!bookingDoc.exists) {
                return res.status(404).json({
                    success: false,
                    error: `ไม่พบการจอง ${bookingId}`
                });
            }

            const bookingData = bookingDoc.data();
            if (bookingData.userId !== req.user.userId) {
                return res.status(403).json({
                    success: false,
                    error: 'ไม่มีสิทธิ์ยกเลิกการจองนี้'
                });
            }

            if (bookingData.status !== 'pending') {
                return res.status(400).json({
                    success: false,
                    error: `การจอง ${bookingId} มีสถานะ ${bookingData.status} ไม่สามารถยกเลิกได้`
                });
            }

            // เพิ่มการยกเลิกในแบทช์
            const bookingRef = db.collection('bookings').doc(bookingId);
            batch.update(bookingRef, {
                status: 'cancelled',
                cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
                cancellationReason: 'ยกเลิกเพื่อจองใหม่ (ยืนยันโดยผู้ใช้)',
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }

        // บันทึกการยกเลิก
        await batch.commit();
        console.log(`✅ Cancelled ${bookingIdsToCancel.length} booking(s)`);

        // สร้างการจองใหม่ (ยืนยันแทนที่) พร้อมป้องกัน undefined
        const courtDocForNew = await db.collection('courts').doc(newBookingData.courtId).get();
        const courtDataForNew = courtDocForNew.exists ? courtDocForNew.data() : {};
        const safeStudentId2 = (req.user && typeof req.user.studentId !== 'undefined') ? req.user.studentId : null;
        const safeCourtType2 = (typeof newBookingData.courtType !== 'undefined' && newBookingData.courtType !== null)
            ? newBookingData.courtType
            : (courtDataForNew.type || courtDataForNew.category || null);
        const safeCourtName2 = (typeof newBookingData.courtName !== 'undefined' && newBookingData.courtName !== null)
            ? newBookingData.courtName
            : (courtDataForNew.name || null);
        const participantsCodes2 = Array.isArray(newBookingData.participantCodes)
            ? newBookingData.participantCodes.map(c => String(c).trim().toUpperCase()).filter(Boolean)
            : [];

        // resolve participants for new booking (best-effort; if codes missing, leave empty)
        const participantsResolved2 = [];
        for (const code of participantsCodes2) {
            const snap = await db.collection('users').where('userCode', '==', code).limit(1).get();
            if (!snap.empty) {
                const uDoc = snap.docs[0];
                const u = uDoc.data();
                participantsResolved2.push({ userId: uDoc.id, userName: `${u.firstName} ${u.lastName}`, userCode: code });
            }
        }

        const bookingData = {
            userId: req.user.userId,
            userName: req.user.userName,
            studentId: safeStudentId2,
            courtId: newBookingData.courtId,
            courtType: safeCourtType2,
            courtName: safeCourtName2,
            date: newBookingData.date,
            timeSlots: newBookingData.timeSlots,
            activityType: newBookingData.activityType || 'ไม่ระบุ',
            note: newBookingData.note || '',
            bookingType: newBookingData.bookingType || 'regular',
            status: 'pending',
            isLocationVerified: false,
            isQRVerified: false,
            verified: false,
            participants: participantsResolved2,
            participantsUserIds: participantsResolved2.map(p => p.userId),
            participantCodes: participantsCodes2,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };

        const newBookingRef = await db.collection('bookings').add(bookingData);
        console.log(`✅ New booking created successfully with ID: ${newBookingRef.id}`);

        // แจ้งเตือนผู้ที่ถูกรวมเป็นผู้เข้าร่วมว่าโค้ดของเขาถูกใช้ในการจองใหม่ (confirm-replace)
        try {
            const whenStr2 = Array.isArray(newBookingData.timeSlots) && newBookingData.timeSlots.length > 0 ? newBookingData.timeSlots.join(', ') : '';
            for (const p of participantsResolved2) {
                try {
                    await db.collection('messages').add({
                        userId: p.userId,
                        type: 'code_usage_notice',
                        title: 'มีการใช้รหัสของคุณในการจองสนาม',
                        body: `ผู้ใช้ ${req.user.userName || ''}${(safeStudentId2 ? ` (${safeStudentId2})` : '')} ได้นำรหัสของคุณ (${p.userCode}) ไปใช้ในการจองสนาม ${safeCourtName2 || ''} วันที่ ${new Date(newBookingData.date).toISOString().split('T')[0]}${whenStr2 ? ` เวลา ${whenStr2}` : ''}`,
                        relatedId: newBookingRef.id,
                        read: false,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                } catch (msgErr) {
                    console.warn('Failed to create code usage message (confirm-replace) for participant', p.userId, msgErr?.message || msgErr);
                }
            }
        } catch (e) {
            console.warn('Code usage notification (confirm-replace) failed:', e?.message || e);
        }

    // Load configurable auto-cancel penalty for warning string
    const autoPenalty2 = await getNumericSetting('penalty_no_checkin_auto_cancel', 50);

        res.status(201).json({
            success: true,
            message: 'ยกเลิกการจองเดิมและสร้างการจองใหม่สำเร็จ',
            bookingId: newBookingRef.id,
            cancelledBookings: bookingIdsToCancel,
            warning: newBookingData.bookingType === 'activity'
                ? 'การจองกิจกรรม: ระบบไม่หักคะแนนอัตโนมัติกรณีไม่เช็คอิน'
                : 'หากไม่ได้เช็คอินตามเวลาที่กำหนด ระบบจะยกเลิกและหักคะแนน ' + String(autoPenalty2) + ' คะแนน',
            bookingData: {
                ...bookingData,
                id: newBookingRef.id
            }
        });

    } catch (err) {
        console.error('Confirm replace booking error:', err);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการยกเลิกและสร้างการจองใหม่'
        });
    }
});

// ยกเลิกการจอง
router.delete('/bookings/:bookingId', authenticateToken, async (req, res) => {
    try {
        const { bookingId } = req.params;
        // Debug logging
        console.log('🗑️ Cancel booking request received:');
        console.log('   BookingId:', bookingId);
        console.log('   User:', req.user.userId);
        console.log('   Request body:', JSON.stringify(req.body));
        console.log('   Content-Type:', req.headers['content-type']);

        const reason = req.body?.reason || 'ไม่ระบุเหตุผล'; // แก้ไขให้ optional
        const db = admin.firestore();

        console.log(`🗑️ Cancelling booking ${bookingId}, reason: ${reason}`);

        const bookingDoc = await db.collection('bookings').doc(bookingId).get();
        if (!bookingDoc.exists) {
            return res.status(404).json({
                success: false,
                error: 'ไม่พบการจองนี้'
            });
        }

        const bookingData = bookingDoc.data();

        // ตรวจสอบว่าเป็นเจ้าของการจองหรือไม่
        if (bookingData.userId !== req.user.userId) {
            return res.status(403).json({
                success: false,
                error: 'ไม่มีสิทธิ์ยกเลิกการจองนี้'
            });
        }

        // ตรวจสอบสถานะการจอง - สามารถยกเลิกได้เฉพาะ pending และ confirmed
        if (!['pending', 'confirmed'].includes(bookingData.status)) {
            let message = '';
            switch (bookingData.status) {
                case 'cancelled':
                    message = 'การจองนี้ถูกยกเลิกแล้ว';
                    break;
                case 'checked-in':
                    message = 'ไม่สามารถยกเลิกได้ เนื่องจากได้เช็คอินแล้ว';
                    break;
                case 'completed':
                    message = 'ไม่สามารถยกเลิกได้ เนื่องจากการจองสำเร็จแล้ว';
                    break;
                case 'expired':
                    message = 'ไม่สามารถยกเลิกได้ เนื่องจากการจองหมดเวลาแล้ว';
                    break;
                default:
                    message = 'ไม่สามารถยกเลิกการจองที่มีสถานะ ' + bookingData.status;
            }
            return res.status(400).json({
                success: false,
                error: message
            });
        }

    // กฎการยกเลิกตามเวลา (ปรับแต่งได้):
    // - ยกเลิกล่วงหน้า >= N ชั่วโมงก่อนเวลาเริ่มแรก: อนุญาต, ไม่โดนแบน, ไม่หักคะแนน
    // - ยกเลิกภายใน < N ชั่วโมงก่อนเวลาเริ่ม (แต่ก่อนเริ่ม): อนุญาต, ไม่หักคะแนน, แบนสิทธิ์การจองเฉพาะวันนี้
        // - หลังถึงเวลาเริ่ม: ไม่อนุญาตให้ยกเลิก
        const normalizedDate = (typeof bookingData.date === 'string')
            ? (bookingData.date.includes('T') ? new Date(bookingData.date).toISOString().split('T')[0] : bookingData.date)
            : (bookingData.date?.toDate ? bookingData.date.toDate().toISOString().split('T')[0] : null);
        const timeSlots = Array.isArray(bookingData.timeSlots) ? bookingData.timeSlots : [];
        let earliestStartMins = null;
        for (const slot of timeSlots) {
            if (typeof slot !== 'string' || !slot.includes('-')) continue;
            const [startStr] = slot.split('-');
            const [h, m] = startStr.split(':').map(Number);
            if (!Number.isNaN(h) && !Number.isNaN(m)) {
                const mins = h * 60 + m;
                earliestStartMins = (earliestStartMins === null) ? mins : Math.min(earliestStartMins, mins);
            }
        }

        const now = new Date();
        const todayStr = now.toISOString().split('T')[0];
        const nowMins = now.getHours() * 60 + now.getMinutes();

        if (!normalizedDate || earliestStartMins === null) {
            return res.status(400).json({ success: false, error: 'ข้อมูลเวลาการจองไม่ถูกต้อง ไม่สามารถยกเลิกได้' });
        }

        if (normalizedDate < todayStr) {
            return res.status(400).json({ success: false, error: 'เลยวันที่จองแล้ว ไม่สามารถยกเลิกได้' });
        }

        // ห้ามยกเลิกเด็ดขาดเมื่อถึงเวลาเริ่มแล้ว (ต้องเช็คอินเท่านั้น)
        if (normalizedDate === todayStr && nowMins >= earliestStartMins) {
            return res.status(400).json({ 
                success: false, 
                error: 'ถึงเวลาเริ่มการจองแล้ว ไม่สามารถยกเลิกได้ กรุณาเช็คอินเท่านั้น' 
            });
        }

        // อ่านค่าจาก settings
        const cancelFreeHours = await getNumericSetting('cancel_free_hours', 1); // ต้องยกเลิกก่อนกี่ชั่วโมง
        const cancelFreeMinutes = Math.max(0, Number(cancelFreeHours) || 0) * 60;
        const lateCancelPenalty = await getNumericSetting('penalty_late_cancel', 0); // คะแนนปรับถ้ายกเลิกสาย

        let isLateCancellation = false;
        let shouldPenalize = false;
        
        if (normalizedDate === todayStr) {
            // วันนี้ แต่ยังไม่ถึงเวลาเริ่ม -> ตรวจสอบว่ายกเลิกสายหรือไม่
            const diff = earliestStartMins - nowMins; // minutes until start
            if (diff < cancelFreeMinutes) {
                isLateCancellation = true;
                // ถ้ามีการตั้งค่าเบี้ยปรับยกเลิกสาย ให้หักคะแนน
                if (lateCancelPenalty > 0) {
                    shouldPenalize = true;
                }
            }
        }

        const updateData = {
            status: 'cancelled',
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            cancellationReason: reason || (isLateCancellation ? `ยกเลิกภายใน ${cancelFreeHours} ชั่วโมงก่อนเริ่ม` : `ยกเลิกล่วงหน้า >= ${cancelFreeHours} ชั่วโมง`),
            isLateCancellation: isLateCancellation
        };

        await db.collection('bookings').doc(bookingId).update(updateData);

        // หักสิทธิ์การจองสำหรับวันนั้น (ทุกกรณี)
        try {
            const consumeKey = `consumedRightsByDate.${normalizedDate}`;
            const participants = Array.isArray(bookingData.participantsUserIds) ? bookingData.participantsUserIds : [];
            const allUserIds = [bookingData.userId, ...participants].filter(Boolean);
            const batch2 = db.batch();
            for (const uid of allUserIds) {
                const uRef = db.collection('users').doc(uid);
                batch2.set(uRef, { 
                    [consumeKey]: admin.firestore.FieldValue.increment(1), 
                    updatedAt: admin.firestore.FieldValue.serverTimestamp() 
                }, { merge: true });
            }
            await batch2.commit();
            console.log(`✅ Consumed rights incremented for ${allUserIds.length} user(s)`);
        } catch (e) {
            console.error('Failed to increment consumed rights on cancel for all participants:', e);
        }

        // ถ้ายกเลิกสายและมีการตั้งค่าเบี้ยปรับ -> สร้าง penalty และหักคะแนน
        if (shouldPenalize) {
            try {
                const participants = Array.isArray(bookingData.participantsUserIds) ? bookingData.participantsUserIds : [];
                const allUserIds = [bookingData.userId, ...participants].filter(Boolean);
                
                for (const uid of allUserIds) {
                    // สร้าง penalty record
                    await db.collection('penalties').add({
                        userId: uid,
                        bookingId: bookingId,
                        penaltyPoints: lateCancelPenalty,
                        reason: `ยกเลิกการจองสาย (ภายใน ${cancelFreeHours} ชั่วโมงก่อนเวลาเริ่ม)`,
                        courtName: bookingData.courtName || null,
                        bookingDate: bookingData.date || normalizedDate,
                        timeSlots: bookingData.timeSlots || [],
                        bookingType: bookingData.bookingType || 'regular',
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });

                    // หักคะแนน
                    const userRef = db.collection('users').doc(uid);
                    const userSnap = await userRef.get();
                    if (userSnap.exists) {
                        const userData = userSnap.data();
                        const currentPoints = Number(userData.points || 0);
                        const newPoints = Math.max(0, currentPoints - lateCancelPenalty);
                        await userRef.update({
                            points: newPoints,
                            updatedAt: admin.firestore.FieldValue.serverTimestamp()
                        });
                    }
                }
                console.log(`⚠️ Late cancellation penalty applied: ${lateCancelPenalty} points deducted from ${allUserIds.length} user(s)`);
            } catch (e) {
                console.error('Failed to apply late cancellation penalty:', e);
            }
        }

        console.log(`✅ Booking ${bookingId} cancelled successfully (late: ${isLateCancellation}, penalized: ${shouldPenalize})`);
        res.json({
            success: true,
            message: shouldPenalize 
                ? `ยกเลิกสำเร็จ แต่ยกเลิกสาย (ภายใน ${cancelFreeHours} ชั่วโมง) จึงถูกหัก ${lateCancelPenalty} คะแนน และหักสิทธิ์การจอง 1 สิทธิ์`
                : (isLateCancellation ? `ยกเลิกสำเร็จ และหักสิทธิ์การจอง 1 สิทธิ์` : 'ยกเลิกสำเร็จ และหักสิทธิ์การจอง 1 สิทธิ์'),
            booking: {
                id: bookingId,
                status: 'cancelled',
                cancelledAt: new Date().toISOString(),
                reason: updateData.cancellationReason,
                isLateCancellation: isLateCancellation,
                penaltyApplied: shouldPenalize,
                penaltyPoints: shouldPenalize ? lateCancelPenalty : 0
            }
        });
    } catch (err) {
        console.error('❌ Cancel booking error:', err);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการยกเลิกการจอง'
        });
    }
});

// Update booking status endpoint
// (removed duplicate unprotected status route and redundant module export)

// อัปเดตสถานะการจอง
router.patch('/bookings/:bookingId/status', authenticateToken, async (req, res) => {
    try {
        const { bookingId } = req.params;
        const { status, reason } = req.body;

        const db = admin.firestore();
        console.log(`🔄 Updating booking ${bookingId} status to ${status}`);

        const bookingDoc = await db.collection('bookings').doc(bookingId).get();
        if (!bookingDoc.exists) {
            return res.status(404).json({
                success: false,
                error: 'ไม่พบการจองนี้'
            });
        }

        const bookingData = bookingDoc.data();
        const oldStatus = bookingData.status;

        // ตรวจสอบว่าเป็นเจ้าของการจองหรือไม่
        if (bookingData.userId !== req.user.userId) {
            return res.status(403).json({
                success: false,
                error: 'ไม่มีสิทธิ์อัปเดตการจองนี้'
            });
        }

        // เตรียมข้อมูลอัปเดต
        const updateData = {
            status: status,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };

        // เพิ่มข้อมูลตามสถานะ
        switch (status) {
            case 'confirmed': {
                updateData.confirmedAt = admin.firestore.FieldValue.serverTimestamp();
                // If admin disabled QR requirement, mark as QR verified automatically
                try {
                    const requireQR = await getBooleanSetting('require_qr_verification', true); // boolean
                    if (!requireQR) updateData.isQRVerified = true;
                } catch (_) {}
                break;
            }
            case 'checked-in': {
                updateData.checkedInAt = admin.firestore.FieldValue.serverTimestamp();
                // If admin disabled location verification, mark as location verified automatically
                try {
                    const requireLoc = await getBooleanSetting('require_location_verification', true);
                    if (!requireLoc) updateData.isLocationVerified = true;
                } catch (_) {}
                // Always award bonus points to owner and participants every time checked-in
                try {
                    const bonus = await getNumericSetting('bonus_completed_booking', 5);
                    const bookingRef = db.collection('bookings').doc(bookingId);
                    await db.runTransaction(async (tx) => {
                        const snap = await tx.get(bookingRef);
                        if (!snap.exists) return;
                        const b = snap.data();
                        const ownerId = b.userId;
                        const participants = Array.isArray(b.participantsUserIds) ? b.participantsUserIds : [];
                        const allUserIds = [ownerId, ...participants].filter(Boolean);
                        const inc = Number(bonus);
                        for (const uid of allUserIds) {
                            const uRef = db.collection('users').doc(uid);
                            const uSnap = await tx.get(uRef);
                            if (!uSnap.exists) continue;
                            const cur = Number(uSnap.data().points || 0);
                            const next = Math.min(100, cur + inc);
                            if (next !== cur) {
                                tx.update(uRef, { points: next, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                            }
                        }
                    });
                    // Record a message (best-effort, outside transaction)
                    try {
                        for (const uid of [bookingData.userId, ...(Array.isArray(bookingData.participantsUserIds) ? bookingData.participantsUserIds : [])]) {
                            await db.collection('messages').add({
                                userId: uid,
                                title: 'ได้รับคะแนนจากการใช้งานสนาม',
                                body: `ระบบได้เพิ่มคะแนน ${bonus} คะแนนจากการเช็คอินใช้งานสนาม`,
                                type: 'points_bonus',
                                relatedId: bookingId,
                                read: false,
                                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                            });
                        }
                    } catch (_) {}
                } catch (awardErr) {
                    console.error('⚠️ Points award (checked-in) failed:', awardErr);
                }
                break;
            }
            case 'completed':
                updateData.completedAt = admin.firestore.FieldValue.serverTimestamp();
                updateData.verified = true;
                // Award bonus points to owner and participants every time completed
                try {
                    const bonus = await getNumericSetting('bonus_completed_booking', 5);
                    const bookingRef = db.collection('bookings').doc(bookingId);
                    await db.runTransaction(async (tx) => {
                        const snap = await tx.get(bookingRef);
                        if (!snap.exists) return;
                        const b = snap.data();
                        const ownerId = b.userId;
                        const participants = Array.isArray(b.participantsUserIds) ? b.participantsUserIds : [];
                        const allUserIds = [ownerId, ...participants].filter(Boolean);
                        const inc = Number(bonus);
                        for (const uid of allUserIds) {
                            const uRef = db.collection('users').doc(uid);
                            const uSnap = await tx.get(uRef);
                            if (!uSnap.exists) continue;
                            const cur = Number(uSnap.data().points || 0);
                            const next = Math.min(100, cur + inc);
                            if (next !== cur) {
                                tx.update(uRef, { points: next, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                            }
                        }
                    });
                    // Record a message (best-effort, outside transaction)
                    try {
                        for (const uid of [bookingData.userId, ...(Array.isArray(bookingData.participantsUserIds) ? bookingData.participantsUserIds : [])]) {
                            await db.collection('messages').add({
                                userId: uid,
                                title: 'ได้รับคะแนนจากการใช้งานสนาม',
                                body: `ระบบได้เพิ่มคะแนน ${bonus} คะแนนจากการใช้งานเสร็จสมบูรณ์`,
                                type: 'points_bonus',
                                relatedId: bookingId,
                                read: false,
                                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                            });
                        }
                    } catch (_) {}
                } catch (e) {
                    console.warn('Failed to award completion bonus:', e?.message || e);
                }
                break;
            case 'cancelled':
                updateData.cancelledAt = admin.firestore.FieldValue.serverTimestamp();
                if (reason) {
                    updateData.cancellationReason = reason;
                }
                break;
        }

        await db.collection('bookings').doc(bookingId).update(updateData);

        console.log(`✅ Booking ${bookingId} status updated: ${oldStatus} → ${status}`);

        res.json({
            success: true,
            message: `อัปเดตสถานะการจองเป็น ${status} เรียบร้อยแล้ว`,
            oldStatus: oldStatus,
            newStatus: status
        });
    } catch (err) {
        console.error('❌ Update status error:', err);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการอัปเดตสถานะ'
        });
    }
});

// ยืนยันการจองด้วย QR Code และตำแหน่ง (แก้ไขเพื่อไม่ให้สร้างการจองซ้ำ)
router.post('/bookings/confirm-qr', authenticateToken, async (req, res) => {
    try {
        const { bookingId, qrData, location } = req.body;
        const db = admin.firestore();

        console.log(`🔍 QR Confirmation request for booking: ${bookingId}`);

        const bookingDoc = await db.collection('bookings').doc(bookingId).get();
        if (!bookingDoc.exists) {
            return res.status(404).json({
                success: false,
                error: 'ไม่พบการจองนี้'
            });
        }

        const bookingData = bookingDoc.data();
        console.log(`📋 Current booking status: ${bookingData.status}`);

        
        const isOwner = bookingData.userId === req.user.userId;
        const isParticipant = Array.isArray(bookingData.participantsUserIds)
            ? bookingData.participantsUserIds.includes(req.user.userId)
            : false;
        if (!isOwner && !isParticipant) {
            return res.status(403).json({
                success: false,
                error: 'ไม่มีสิทธิ์ยืนยันการจองนี้ (ต้องเป็นผู้จองหรือผู้เข้าร่วมที่ถูกเพิ่มด้วยรหัส)'
            });
        }

        // ตรวจสอบว่าการจองยังสามารถยืนยันได้หรือไม่
        if (!['pending', 'confirmed'].includes(bookingData.status)) {
            return res.status(400).json({
                success: false,
                error: `ไม่สามารถยืนยันการจองที่มีสถานะ ${bookingData.status}`
            });
        }

        // อัปเดตสถานะการจอง (ไม่สร้างการจองใหม่)
        // Respect admin toggles for QR and location verification
        let requireQR = true, requireLoc = true;
        try {
            requireQR = await getBooleanSetting('require_qr_verification', true);
        } catch (_) {}
        try {
            requireLoc = await getBooleanSetting('require_location_verification', true);
        } catch (_) {}

        const updateData = {
            status: 'checked-in',
            // This endpoint is called when QR flow succeeds; if requirement disabled, we still mark verified
            isQRVerified: true,
            isLocationVerified: true,
            checkedInAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };

        if (qrData) {
            updateData.qrVerificationData = qrData;
        }

        if (location) {
            updateData.locationVerification = location;
        }

        const bookingRef = db.collection('bookings').doc(bookingId);
        await bookingRef.update(updateData);

        // Award configurable bonus points to owner and participants if not yet awarded, capped at 100
        // Use a flag pointsAwarded to ensure idempotency
        try {
            const bonus = await getNumericSetting('bonus_completed_booking', 5);
            await db.runTransaction(async (tx) => {
                const snap = await tx.get(bookingRef);
                if (!snap.exists) return; // shouldn't happen
                const b = snap.data();
                if (b.pointsAwarded) return; // already awarded

                const ownerId = b.userId;
                const participants = Array.isArray(b.participantsUserIds) ? b.participantsUserIds : [];
                const allUserIds = [ownerId, ...participants].filter(Boolean);

                for (const uid of allUserIds) {
                    const uRef = db.collection('users').doc(uid);
                    const uSnap = await tx.get(uRef);
                    if (!uSnap.exists) continue;
                    const cur = Number(uSnap.data().points || 0);
                    const inc = Number(bonus);
                    const next = Math.min(100, cur + inc);
                    // Only update if there is a change (avoid extra writes at cap)
                    if (next !== cur) {
                        tx.update(uRef, { points: next, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                    }
                }

                tx.update(bookingRef, { pointsAwarded: true });
            });
        } catch (awardErr) {
            console.error('⚠️ Points award transaction failed:', awardErr);
            // Continue without failing the confirmation
        }

        console.log(`✅ Booking ${bookingId} confirmed and checked in successfully`);

        // Optionally return current user points after award
        let updatedPoints = null;
        try {
            const meDoc = await db.collection('users').doc(req.user.userId).get();
            if (meDoc.exists) updatedPoints = (meDoc.data().points ?? 0);
        } catch {}

        res.json({
            success: true,
            message: 'ยืนยันการจองและเช็คอินสำเร็จ',
            booking: {
                id: bookingId,
                status: 'checked-in',
                ...updateData
            },
            points: updatedPoints
        });
    } catch (err) {
        console.error('❌ QR Confirmation error:', err);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการยืนยันการจอง'
        });
    }
});

// ตรวจสอบสถานะการใช้รหัสจองของผู้ใช้ในวันนี้
router.get('/bookings/code-status', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const userId = req.user.userId;

        // ดึงรหัสของผู้ใช้
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            return res.status(404).json({ success: false, error: 'ไม่พบข้อมูลผู้ใช้' });
        }
        const userData = userDoc.data();
        const userCode = userData.userCode || null;

    // Operational day boundary hour: from admin setting with env fallback
    const boundaryHour = await getNumericSetting('reset_boundary_hour', Number.parseInt(process.env.RESET_BOUNDARY_HOUR || '0', 10));
        const now = new Date();
        const todayBoundary = new Date(now);
        todayBoundary.setHours(boundaryHour, 0, 0, 0);

        // วันปฏิบัติการปัจจุบัน (Operational Day)
        // หากเวลาปัจจุบันยังไม่ถึงชั่วโมงตัดรอบ ให้ถือว่าอยู่ในวันปฏิบัติการของเมื่อวาน
        const operationalDate = new Date(now);
        if (now < todayBoundary) {
            operationalDate.setDate(operationalDate.getDate() - 1);
        }
        const operationalDateStr = operationalDate.toISOString().split('T')[0];

        const usedIds = new Set();
        const statuses = ['pending','confirmed','checked-in','completed'];

        // เช็คเป็นเจ้าของการจอง (อิงตาม operationalDateStr)
        const ownedSnap = await db.collection('bookings').where('userId', '==', userId).get();
        ownedSnap.forEach(doc => {
            const data = doc.data();
            let bookingDate = '';
            if (typeof data.date === 'string') {
                bookingDate = data.date.includes('T') ? new Date(data.date).toISOString().split('T')[0] : data.date;
            } else if (data.date && data.date.toDate) {
                bookingDate = data.date.toDate().toISOString().split('T')[0];
            }
            if (bookingDate === operationalDateStr && statuses.includes(data.status)) {
                usedIds.add(doc.id);
            }
        });

        // เช็คเป็นผู้เข้าร่วม (อิงตาม operationalDateStr)
        const partSnap = await db.collection('bookings').where('participantsUserIds', 'array-contains', userId).get();
        partSnap.forEach(doc => {
            const data = doc.data();
            let bookingDate = '';
            if (typeof data.date === 'string') {
                bookingDate = data.date.includes('T') ? new Date(data.date).toISOString().split('T')[0] : data.date;
            } else if (data.date && data.date.toDate) {
                bookingDate = data.date.toDate().toISOString().split('T')[0];
            }
            if (bookingDate === operationalDateStr && statuses.includes(data.status)) {
                usedIds.add(doc.id);
            }
        });

        const usedCount = usedIds.size;
        // Include consumed rights recorded on the user document for the operational date
        let consumedCount = 0;
        try {
            const consumedMap = userData.consumedRightsByDate || {};
            const val = consumedMap && consumedMap[operationalDateStr];
            const n = Number(val || 0);
            consumedCount = Number.isFinite(n) ? Math.max(0, n) : 0;
        } catch (_) { consumedCount = 0; }
        const usedTotal = usedCount + consumedCount;
        const usedToday = usedTotal > 0;

        // Daily rights per user (admin-configurable) + extra per-user rights
        const baseDailyRights = await getNumericSetting('daily_rights_per_user', 1);
        let extraDailyRights = 0;
        try {
            const uDoc = await db.collection('users').doc(userId).get();
            if (uDoc.exists) extraDailyRights = Number(uDoc.data().extraDailyRights || 0) || 0;
        } catch (_) {}
        const maxRights = Math.max(0, Number(baseDailyRights)) + Math.max(0, Number(extraDailyRights));
    const remainingRights = Math.max(0, Math.max(0, maxRights) - Math.max(0, usedTotal));

        // เวลาที่จะใช้ได้อีกครั้ง (ขอบเขตวันถัดไป ณ ชั่วโมงตัดรอบ)
        const nextBoundary = new Date(now);
        const todayBoundaryForNext = new Date(now);
        todayBoundaryForNext.setHours(boundaryHour, 0, 0, 0);
        if (now < todayBoundaryForNext) {
            // ยังไม่ถึงชั่วโมงตัดรอบของวันนี้ => ขอบเขตถัดไปคือวันนี้ที่ชั่วโมงตัดรอบ
            nextBoundary.setHours(boundaryHour, 0, 0, 0);
        } else {
            // ผ่านชั่วโมงตัดรอบแล้ว => ขอบเขตถัดไปเป็นพรุ่งนี้ที่ชั่วโมงตัดรอบ
            nextBoundary.setDate(nextBoundary.getDate() + 1);
            nextBoundary.setHours(boundaryHour, 0, 0, 0);
        }
        const secondsUntilReset = Math.max(0, Math.floor((nextBoundary - now) / 1000));

        res.json({
            success: true,
            userCode,
            usedToday,
            usedCount,
            consumedCount,
            usedTotal,
            // Backwards compatible: dailyRights returns effective rights
            dailyRights: maxRights,
            baseDailyRights: Math.max(0, Number(baseDailyRights)),
            extraDailyRights: Math.max(0, Number(extraDailyRights)),
            effectiveDailyRights: maxRights,
            remainingRights,
            nextAvailableAt: nextBoundary.toISOString(),
            secondsUntilReset
        });
    } catch (err) {
        console.error('❌ Get code status error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการตรวจสอบสถานะรหัส' });
    }
});

// เช็คและลดคะแนนสำหรับการจองที่หมดเวลา
router.post('/bookings/check-expired', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const userId = req.user.userId;

    // Trigger watcher to enforce configurable auto-cancel/penalties
        await checkAndExpireMissedCheckins();

        // Build today string for filtering
        const now = new Date();
        const todayStr = now.toISOString().split('T')[0];

        // Find today's auto-cancelled bookings that involve this user
        // 1) As owner
        const ownerSnap = await db.collection('bookings')
            .where('userId', '==', userId)
            .where('status', '==', 'cancelled')
            .get();

        // 2) As participant
        const partSnap = await db.collection('bookings')
            .where('participantsUserIds', 'array-contains', userId)
            .where('status', '==', 'cancelled')
            .get();

        const expiredBookings = [];
        function normalizeDateField(dateField) {
            if (!dateField) return null;
            if (typeof dateField === 'string') return dateField.includes('T') ? new Date(dateField).toISOString().split('T')[0] : dateField;
            if (dateField.toDate) return dateField.toDate().toISOString().split('T')[0];
            return null;
        }

        const autoPenalty = await getNumericSetting('penalty_no_checkin_auto_cancel', 50);

        const pushIfToday = (doc) => {
            const data = doc.data();
            const d = normalizeDateField(data.date);
            if (d === todayStr && data.autoCancelled) {
                expiredBookings.push({
                    bookingId: doc.id,
                    courtName: data.courtName,
                    date: d,
                    timeSlots: data.timeSlots || [],
                    penaltyPoints: autoPenalty
                });
            }
        };

        ownerSnap.forEach(pushIfToday);
        partSnap.forEach(pushIfToday);

    const totalPenaltyPoints = expiredBookings.length * Number(autoPenalty); // summary value based on configured penalty

        res.json({
            success: true,
            expiredBookings,
            totalPenaltyPoints,
            message: expiredBookings.length > 0 ? `ระบบได้ยกเลิกอัตโนมัติและหักคะแนนแล้ว` : 'ไม่พบการจองที่หมดเวลา'
        });
    } catch (err) {
        console.error('❌ Check expired bookings error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการตรวจสอบการจองที่หมดเวลา' });
    }
});

// ดูตารางการจองของสนามในวันที่เฉพาะ
router.get('/court-schedule/:courtId/:date', authenticateToken, async (req, res) => {
    try {
        const { courtId, date } = req.params;
        const db = admin.firestore();
        
        console.log(`🔍 Getting schedule for court ${courtId} on ${date}`);
        
        // แปลง date เป็น string format ที่ถูกต้อง
        const targetDateForSchedule = new Date(date).toISOString().split('T')[0];
        console.log(`📅 Normalized target date for schedule: ${targetDateForSchedule}`);
        
        // ดึงการจองทั้งหมดของ court นี้ (ไม่ใช้ date query เพราะ format ไม่ตรงกัน)
        const allBookingsInCourt = await db.collection('bookings')
            .where('courtId', '==', courtId)
            .get();
        
        console.log(`📊 Total bookings in court ${courtId}: ${allBookingsInCourt.size}`);
        
        const bookedSlots = [];
        allBookingsInCourt.forEach(doc => {
            const data = doc.data();
            let bookingDate = '';
            
            // จัดการ date field ที่อาจเป็น string หรือ timestamp
            if (typeof data.date === 'string') {
                if (data.date.includes('T')) {
                    // ISO string format
                    bookingDate = new Date(data.date).toISOString().split('T')[0];
                } else {
                    // Date string format
                    bookingDate = data.date;
                }
            } else if (data.date && data.date.toDate) {
                // Firestore timestamp
                bookingDate = data.date.toDate().toISOString().split('T')[0];
            }
            
            console.log(`📋 Checking booking: ${doc.id} - Date: ${data.date} -> ${bookingDate}, Status: ${data.status}`);
            
            // ตรวจสอบว่าเป็นวันเดียวกันและสถานะที่ยังใช้งานได้
            if (bookingDate === targetDateForSchedule && ['pending', 'confirmed', 'checked-in'].includes(data.status)) {
                console.log(`✅ Including booking: ${doc.id} - Status: ${data.status} - TimeSlots: ${JSON.stringify(data.timeSlots)}`);
                
                // รองรับทั้ง timeSlot เดี่ยวและ timeSlots array
                if (data.timeSlots && Array.isArray(data.timeSlots)) {
                    bookedSlots.push(...data.timeSlots);
                } else if (data.timeSlot) {
                    bookedSlots.push(data.timeSlot);
                }
            }
        });
        
        const uniqueBookedSlots = [...new Set(bookedSlots)]; // ลบ duplicate
        console.log(`📊 Total booked slots for court ${courtId} on ${date}: ${uniqueBookedSlots.length} - ${JSON.stringify(uniqueBookedSlots)}`);
        
        res.json({ success: true, bookedSlots: uniqueBookedSlots });
    } catch (err) {
        console.error('Get court schedule error:', err);
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;
