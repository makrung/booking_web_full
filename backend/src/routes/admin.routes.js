const express = require('express');
const router = express.Router();
const admin = require('../../config/firebase');
const { authenticateToken } = require('../middleware/auth');
const { getNumericSetting, clearCache } = require('../services/settings.service');

// Middleware สำหรับตรวจสอบว่าผู้ใช้เป็น admin หรือไม่
const requireAdmin = async (req, res, next) => {
    try {
        // ตรวจสอบว่ามีข้อมูล user จาก auth middleware หรือไม่
        if (!req.user || !req.user.id) {
            console.error('Error checking admin: Missing user data in request');
            return res.status(401).json({ 
                error: 'ข้อมูลการยืนยันตัวตนไม่ถูกต้อง',
                requireAuth: true 
            });
        }

        console.log('Admin routes: Checking admin status for user:', req.user.id);
        
        // ตรวจสอบ system admin token ก่อน
        if (req.user.id === 'admin' && req.user.type === 'system_admin' && req.user.isAdmin === true) {
            console.log('Admin routes: System admin access granted');
            return next();
        }
        
        const db = admin.firestore();
        const userDoc = await db.collection('users').doc(req.user.id).get();
        
        if (!userDoc.exists) {
            console.error('Admin routes: User document not found:', req.user.id);
            return res.status(404).json({ error: 'ไม่พบข้อมูลผู้ใช้' });
        }

        const userData = userDoc.data();
        console.log('Admin routes: User data for admin check:', { email: userData.email, role: userData.role });
        
        if (userData.role !== 'admin') {
            console.log('Admin routes: Access denied for non-admin user:', userData.email);
            return res.status(403).json({ error: 'คุณไม่มีสิทธิ์เข้าถึงหน้านี้' });
        }

        console.log('Admin routes: Admin access granted for:', userData.email);
        next();
    } catch (error) {
        console.error('Admin check error:', error);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในการตรวจสอบสิทธิ์' });
    }
};

// Dashboard - ข้อมูลสรุป
router.get('/dashboard', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const db = admin.firestore();
        
        // นับจำนวนผู้ใช้ทั้งหมด
        const usersSnapshot = await db.collection('users').get();
        const totalUsers = usersSnapshot.size;
        
        // นับจำนวนผู้ใช้ที่ active
        const activeUsersSnapshot = await db.collection('users')
            .where('isActive', '==', true)
            .get();
        const activeUsers = activeUsersSnapshot.size;
        
        // นับจำนวนการจองทั้งหมด
        const bookingsSnapshot = await db.collection('bookings').get();
        const totalBookings = bookingsSnapshot.size;
        
        // นับจำนวนการจองตามสถานะ
        const confirmedBookingsSnapshot = await db.collection('bookings')
            .where('status', '==', 'confirmed')
            .get();
        const confirmedBookings = confirmedBookingsSnapshot.size;
        
        const pendingBookingsSnapshot = await db.collection('bookings')
            .where('status', '==', 'pending')
            .get();
        const pendingBookings = pendingBookingsSnapshot.size;
        
        // นับจำนวนสนาม
        const courtsSnapshot = await db.collection('courts').get();
        const totalCourts = courtsSnapshot.size;

        const dashboardData = {
            totalUsers,
            activeUsers,
            totalBookings,
            confirmedBookings,
            pendingBookings,
            totalCourts,
            timestamp: new Date().toISOString()
        };

        res.json({
            success: true,
            data: dashboardData
        });
    } catch (error) {
        console.error('Dashboard error:', error);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการดึงข้อมูล dashboard'
        });
    }
});

// Analytics - aggregated bookings by period and per-court with TTL cache
let redisClient = null;
try {
    if (process.env.REDIS_URL) {
        const { createClient } = require('redis');
        redisClient = createClient({ url: process.env.REDIS_URL });
        redisClient.on('error', (err) => console.warn('Redis error:', err.message));
        redisClient.connect().then(() => console.log('Connected to Redis for analytics cache')).catch(()=>{});
    }
} catch (e) { console.warn('Redis init failed:', e?.message || e); }

const analyticsCache = {
    data: new Map(), // key -> { ts, payload }
    ttlMs: 45000,
};
router.get('/analytics', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const period = (req.query.period || 'month').toString(); // 'day' | 'month' | 'year'
        const year = Number.parseInt(req.query.year || new Date().getFullYear(), 10);
        const month = Number.parseInt(req.query.month || (new Date().getMonth() + 1), 10); // 1-12
        const dateStr = (req.query.date || new Date().toISOString().split('T')[0]).toString(); // YYYY-MM-DD
        const key = JSON.stringify({ period, year, month, dateStr });
        const now = Date.now();
        // Try Redis first
        if (redisClient) {
            try {
                const hit = await redisClient.get(`analytics:${key}`);
                if (hit) {
                    return res.json({ success: true, data: JSON.parse(hit) });
                }
            } catch (_) {}
        }
        // In-memory fallback
        const cached = analyticsCache.data.get(key);
        if (cached && (now - cached.ts) < analyticsCache.ttlMs) {
            return res.json({ success: true, data: cached.payload });
        }

        const db = admin.firestore();
        const bookingsSnap = await db.collection('bookings').get();
        const bookings = bookingsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        // Helper: normalize date value to 'YYYY-MM-DD'
        const normDate = (v) => {
            try {
                if (!v) return null;
                if (typeof v === 'string') {
                    if (v.includes('T')) return new Date(v).toISOString().split('T')[0];
                    // assume already YYYY-MM-DD
                    return v;
                }
                if (v && typeof v.toDate === 'function') return v.toDate().toISOString().split('T')[0];
            } catch (_) {}
            return null;
        };

        // Filter by selected period
        const filtered = [];
        if (period === 'day') {
            const target = dateStr; // exact day
            for (const b of bookings) {
                const nd = normDate(b.date);
                if (nd === target) filtered.push(b);
            }
        } else if (period === 'month') {
            for (const b of bookings) {
                const nd = normDate(b.date);
                if (!nd) continue;
                const y = Number.parseInt(nd.substring(0,4),10);
                const m = Number.parseInt(nd.substring(5,7),10);
                if (y === year && m === month) filtered.push(b);
            }
        } else { // year
            for (const b of bookings) {
                const nd = normDate(b.date);
                if (!nd) continue;
                const y = Number.parseInt(nd.substring(0,4),10);
                if (y === year) filtered.push(b);
            }
        }

        // Build time buckets
        const buckets = {};
        const labels = [];
        if (period === 'year') {
            for (let i=1;i<=12;i++){ buckets[String(i)] = 0; labels.push(String(i)); }
            for (const b of filtered) {
                const nd = normDate(b.date); if (!nd) continue;
                const m = Number.parseInt(nd.substring(5,7),10);
                buckets[String(m)] = (buckets[String(m)] || 0) + 1;
            }
        } else if (period === 'month') {
            const daysInMonth = new Date(year, month, 0).getDate();
            for (let d=1; d<=daysInMonth; d++){ buckets[String(d)] = 0; labels.push(String(d)); }
            for (const b of filtered) {
                const nd = normDate(b.date); if (!nd) continue;
                const d = Number.parseInt(nd.substring(8,10),10);
                buckets[String(d)] = (buckets[String(d)] || 0) + 1;
            }
        } else {
            // day -> 24 hours labeled 0..23 based on timeSlots' hour
            for (let h=0; h<24; h++){ buckets[String(h)] = 0; labels.push(String(h)); }
            for (const b of filtered) {
                let slots = [];
                if (Array.isArray(b.timeSlots)) slots = b.timeSlots;
                else if (typeof b.timeSlot === 'string') slots = [b.timeSlot];
                if (!slots || slots.length === 0) { buckets['0'] = (buckets['0'] || 0) + 1; continue; }
                for (const s of slots) {
                    const hh = String(Number.parseInt(String(s).split(':')[0] || '0',10));
                    buckets[hh] = (buckets[hh] || 0) + 1;
                }
            }
        }

        // Per-court counts
        const courtCounts = {};
        for (const b of filtered) {
            const name = (b.courtName || 'ไม่ระบุ').toString();
            courtCounts[name] = (courtCounts[name] || 0) + 1;
        }

        // total courts
        let totalCourts = 0;
        try {
            const courtsSnap = await db.collection('courts').get();
            totalCourts = courtsSnap.size;
        } catch (_) {}

        const courtsWithBookings = Object.keys(courtCounts).length;
        const totalFilteredBookings = filtered.length;

        const payload = {
            success: true,
            data: {
                period,
                year,
                month,
                date: dateStr,
                labels,
                buckets,
                courtCounts,
                totalFilteredBookings,
                courtsWithBookings,
                totalCourts,
            }
        };
        // Store in caches
        analyticsCache.data.set(key, { ts: now, payload: payload.data });
        if (redisClient) {
            try {
                await redisClient.setEx(`analytics:${key}`, Math.ceil(analyticsCache.ttlMs/1000), JSON.stringify(payload.data));
            } catch (_) {}
        }
        return res.json(payload);
    } catch (e) {
        console.error('Admin analytics error:', e);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการดึงข้อมูลสรุป' });
    }
});

// ดูรายการผู้ใช้ทั้งหมด
router.get('/users', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const db = admin.firestore();
        const usersSnapshot = await db.collection('users')
            .orderBy('createdAt', 'desc')
            .get();
        
        const users = [];
        usersSnapshot.forEach(doc => {
            const userData = doc.data();
            // ไม่ส่งรหัสผ่านกลับไป
            const { password, ...userWithoutPassword } = userData;
            // ซ่อนผู้ใช้ที่ถูกลบแล้ว (isDeleted === true)
            if (userWithoutPassword.isDeleted === true) return;
            // ค่าดีฟอลต์สิทธิ์พิเศษต่อวัน = 0
            if (typeof userWithoutPassword.extraDailyRights === 'undefined') {
                userWithoutPassword.extraDailyRights = 0;
            }
            users.push({ id: doc.id, ...userWithoutPassword });
        });

        res.json({
            success: true,
            data: users
        });
    } catch (error) {
        console.error('Get users error:', error);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการดึงข้อมูลผู้ใช้'
        });
    }
});

// เปิด/ปิดการใช้งานผู้ใช้
router.patch('/users/:userId/toggle-status', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { userId } = req.params;
        const db = admin.firestore();
        
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            return res.status(404).json({
                success: false,
                error: 'ไม่พบผู้ใช้'
            });
        }

        const userData = userDoc.data();
        const newStatus = !userData.isActive;

        await db.collection('users').doc(userId).update({
            isActive: newStatus,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        res.json({
            success: true,
            message: newStatus ? 'เปิดการใช้งานผู้ใช้แล้ว' : 'ปิดการใช้งานผู้ใช้แล้ว',
            isActive: newStatus
        });
    } catch (error) {
        console.error('Toggle user status error:', error);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการเปลี่ยนสถานะผู้ใช้'
        });
    }
});

// ปรับสิทธิ์การจองต่อวันเฉพาะผู้ใช้ (บวก/ลบได้, ดีฟอลต์ 0)
router.patch('/users/:userId/extra-rights', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { userId } = req.params;
        const { extraDailyRights } = req.body || {};
        const db = admin.firestore();

        const val = Number(extraDailyRights);
        if (!Number.isFinite(val)) {
            return res.status(400).json({ success: false, error: 'ค่า extraDailyRights ต้องเป็นตัวเลข' });
        }
        const clamped = Math.max(-10, Math.min(50, val)); // guardrail

        const userRef = db.collection('users').doc(userId);
        const userDoc = await userRef.get();
        if (!userDoc.exists) return res.status(404).json({ success: false, error: 'ไม่พบผู้ใช้' });

        await userRef.update({
            extraDailyRights: clamped,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return res.json({ success: true, message: 'อัปเดตสิทธิ์พิเศษสำเร็จ', extraDailyRights: clamped });
    } catch (e) {
        console.error('Update extra rights error:', e);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการอัปเดตสิทธิ์พิเศษ' });
    }
});

// ดึงสรุปสิทธิ์การจอง/วัน ของผู้ใช้ (สำหรับแอดมิน)
router.get('/users/:userId/code-status', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { userId } = req.params;
        const db = admin.firestore();

        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) return res.status(404).json({ success: false, error: 'ไม่พบผู้ใช้' });
        const userData = userDoc.data();
        const userCode = userData.userCode || null;

        // Count today's usages per operational boundary
        const boundaryHour = await getNumericSetting('reset_boundary_hour', Number.parseInt(process.env.RESET_BOUNDARY_HOUR || '0', 10));
        const now = new Date();
        const todayBoundary = new Date(now); todayBoundary.setHours(boundaryHour, 0, 0, 0);
        const operationalDate = new Date(now); if (now < todayBoundary) operationalDate.setDate(operationalDate.getDate() - 1);
        const operationalDateStr = operationalDate.toISOString().split('T')[0];

        const usedIds = new Set();
        const statuses = ['pending','confirmed','checked-in','completed'];
        const ownedSnap = await db.collection('bookings').where('userId', '==', userId).get();
        ownedSnap.forEach(doc => {
            const d = doc.data();
            let bookingDate = '';
            if (typeof d.date === 'string') bookingDate = d.date.includes('T') ? new Date(d.date).toISOString().split('T')[0] : d.date;
            else if (d.date && d.date.toDate) bookingDate = d.date.toDate().toISOString().split('T')[0];
            if (bookingDate === operationalDateStr && statuses.includes(d.status)) usedIds.add(doc.id);
        });
        const partSnap = await db.collection('bookings').where('participantsUserIds', 'array-contains', userId).get();
        partSnap.forEach(doc => {
            const d = doc.data();
            let bookingDate = '';
            if (typeof d.date === 'string') bookingDate = d.date.includes('T') ? new Date(d.date).toISOString().split('T')[0] : d.date;
            else if (d.date && d.date.toDate) bookingDate = d.date.toDate().toISOString().split('T')[0];
            if (bookingDate === operationalDateStr && statuses.includes(d.status)) usedIds.add(doc.id);
        });
        const usedCount = usedIds.size;

        const baseDailyRights = await getNumericSetting('daily_rights_per_user', 1);
        const extraDailyRights = Number(userData.extraDailyRights || 0) || 0;
        const effectiveDailyRights = Math.max(0, Number(baseDailyRights)) + Math.max(0, Number(extraDailyRights));
        const remainingRights = Math.max(0, effectiveDailyRights - usedCount);

        res.json({
            success: true,
            userCode,
            usedCount,
            baseDailyRights: Math.max(0, Number(baseDailyRights)),
            extraDailyRights: Math.max(0, Number(extraDailyRights)),
            effectiveDailyRights,
            remainingRights,
        });
    } catch (e) {
        console.error('Admin code-status error:', e);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการดึงสรุปสิทธิ์' });
    }
});

// ดูรายการการจองทั้งหมด
router.get('/bookings', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const db = admin.firestore();
        const bookingsSnapshot = await db.collection('bookings')
            .orderBy('createdAt', 'desc')
            .get();
        
        const bookings = [];
        
        for (const doc of bookingsSnapshot.docs) {
            const bookingData = doc.data();
            
            // ดึงข้อมูลผู้ใช้
            let userName = 'Unknown User';
            if (bookingData.userId) {
                try {
                    const userDoc = await db.collection('users').doc(bookingData.userId).get();
                    if (userDoc.exists) {
                        const userData = userDoc.data();
                        userName = `${userData.firstName} ${userData.lastName}`;
                    }
                } catch (err) {
                    console.error('Error getting user data:', err);
                }
            }
            
            // ดึงข้อมูลสนาม
            let courtName = 'Unknown Court';
            if (bookingData.courtId) {
                try {
                    const courtDoc = await db.collection('courts').doc(bookingData.courtId).get();
                    if (courtDoc.exists) {
                        const courtData = courtDoc.data();
                        courtName = courtData.name;
                    }
                } catch (err) {
                    console.error('Error getting court data:', err);
                }
            }
            
            bookings.push({
                id: doc.id,
                ...bookingData,
                userName,
                courtName
            });
        }

        res.json({
            success: true,
            data: bookings
        });
    } catch (error) {
        console.error('Get bookings error:', error);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการดึงข้อมูลการจอง'
        });
    }
});

// อัปเดตสถานะการจอง
router.patch('/bookings/:bookingId/status', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { bookingId } = req.params;
        const { status } = req.body;
        const db = admin.firestore();
        
        const validStatuses = ['pending', 'confirmed', 'cancelled'];
        if (!validStatuses.includes(status)) {
            return res.status(400).json({
                success: false,
                error: 'สถานะไม่ถูกต้อง'
            });
        }

        const bookingDoc = await db.collection('bookings').doc(bookingId).get();
        if (!bookingDoc.exists) {
            return res.status(404).json({
                success: false,
                error: 'ไม่พบการจอง'
            });
        }

        await db.collection('bookings').doc(bookingId).update({
            status: status,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        res.json({
            success: true,
            message: 'อัปเดตสถานะการจองแล้ว',
            status: status
        });
    } catch (error) {
        console.error('Update booking status error:', error);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการอัปเดตสถานะการจอง'
        });
    }
});

// แก้ไขข้อมูลการจอง (เฉพาะแอดมิน)
router.put('/bookings/:bookingId', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { bookingId } = req.params;
        const allowed = ['courtId','courtName','date','timeSlots','status','note','activityType','responsiblePerson','activity'];
        const payload = req.body || {};
        const update = {};
        for (const k of allowed) {
            if (typeof payload[k] !== 'undefined') update[k] = payload[k];
        }
        if (Object.keys(update).length === 0) return res.status(400).json({ success: false, error: 'ไม่มีข้อมูลที่แก้ไขได้' });

        const db = admin.firestore();
        const ref = db.collection('bookings').doc(bookingId);
        const snap = await ref.get();
        if (!snap.exists) return res.status(404).json({ success: false, error: 'ไม่พบการจอง' });

        update.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await ref.update(update);

        const updated = await ref.get();
        res.json({ success: true, message: 'แก้ไขข้อมูลการจองสำเร็จ', booking: { id: bookingId, ...updated.data() } });
    } catch (e) {
        console.error('Admin edit booking error:', e);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการแก้ไขการจอง' });
    }
});

// ลบการจอง (เฉพาะแอดมิน)
router.delete('/bookings/:bookingId', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { bookingId } = req.params;
        const db = admin.firestore();
        const ref = db.collection('bookings').doc(bookingId);
        const snap = await ref.get();
        if (!snap.exists) return res.status(404).json({ success: false, error: 'ไม่พบการจอง' });

        await ref.delete();
        return res.json({ success: true, message: 'ลบการจองสำเร็จ' });
    } catch (e) {
        console.error('Admin delete booking error:', e);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการลบการจอง' });
    }
});

// จัดการสนาม - ดูรายการ
router.get('/courts', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const db = admin.firestore();
        const courtsSnapshot = await db.collection('courts').get();
        
        const courts = [];
        courtsSnapshot.forEach(doc => {
            courts.push({
                id: doc.id,
                ...doc.data()
            });
        });

        res.json({
            success: true,
            data: courts
        });
    } catch (error) {
        console.error('Get courts error:', error);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการดึงข้อมูลสนาม'
        });
    }
});

// เพิ่มสนามใหม่
router.post('/courts', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const {
            name,
            type,
            category,
            number,
            isActivityOnly = false,
            openBookingTime,
            playStartTime,
            playEndTime,
            isAvailable = true,
            requiredPlayers,
            location
        } = req.body;

        // ตรวจสอบข้อมูลที่จำเป็น
        if (!name || !type || !category || !number || !openBookingTime || !playStartTime || !playEndTime) {
            return res.status(400).json({
                success: false,
                error: 'กรุณากรอกข้อมูลให้ครบถ้วน'
            });
        }

        // ตรวจสอบรูปแบบเวลา
        const timeRegex = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
        if (!timeRegex.test(openBookingTime) || !timeRegex.test(playStartTime) || !timeRegex.test(playEndTime)) {
            return res.status(400).json({
                success: false,
                error: 'รูปแบบเวลาไม่ถูกต้อง (ใช้รูปแบบ HH:MM)'
            });
        }

        const db = admin.firestore();
        
        // สร้าง ID ของสนาม
        const courtId = db.collection('courts').doc().id;
        
        // ตรวจสอบและตั้งค่า requiredPlayers
        const getDefaultRequiredPlayers = (cat) => {
            switch (cat) {
                case 'futsal': return 4;
                case 'basketball': return 5;
                case 'football': return 11;
                case 'volleyball': return 6;
                case 'tennis': return 2;
                case 'badminton': return 2;
                case 'table_tennis': return 2;
                case 'takraw': return 3;
                case 'multipurpose': return 4;
                default: return 2;
            }
        };

        let parsedRequiredPlayers;
        if (requiredPlayers === undefined || requiredPlayers === null || requiredPlayers === '') {
            parsedRequiredPlayers = getDefaultRequiredPlayers(category);
        } else {
            const rp = parseInt(requiredPlayers);
            if (isNaN(rp) || rp < 1 || rp > 50) {
                return res.status(400).json({
                    success: false,
                    error: 'จำนวนคนต้องเป็นตัวเลข 1-50 คน'
                });
            }
            parsedRequiredPlayers = rp;
        }

        const courtData = {
            id: courtId,
            name,
            type,
            category,
            number: parseInt(number),
            isActivityOnly,
            openBookingTime,
            playStartTime,
            playEndTime,
            isAvailable,
            requiredPlayers: parsedRequiredPlayers,
            location: location || null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };

        await db.collection('courts').doc(courtId).set(courtData);

        res.status(201).json({
            success: true,
            message: 'เพิ่มสนามสำเร็จ',
            court: {
                ...courtData,
                id: courtId
            }
        });
    } catch (error) {
        console.error('Create court error:', error);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการเพิ่มสนาม'
        });
    }
});

// อัปเดตข้อมูลสนาม
router.put('/courts/:courtId', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { courtId } = req.params;
        const {
            name,
            type,
            category,
            number,
            isActivityOnly,
            openBookingTime,
            playStartTime,
            playEndTime,
            isAvailable,
            requiredPlayers,
            location
        } = req.body;
        
        const db = admin.firestore();
        const courtRef = db.collection('courts').doc(courtId);
        const courtDoc = await courtRef.get();

        if (!courtDoc.exists) {
            return res.status(404).json({
                success: false,
                error: 'ไม่พบข้อมูลสนาม'
            });
        }

        // ตรวจสอบรูปแบบเวลา (ถ้ามีการส่งมา)
        const timeRegex = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
        if (openBookingTime && !timeRegex.test(openBookingTime)) {
            return res.status(400).json({
                success: false,
                error: 'รูปแบบเวลาเปิดจองไม่ถูกต้อง'
            });
        }
        if (playStartTime && !timeRegex.test(playStartTime)) {
            return res.status(400).json({
                success: false,
                error: 'รูปแบบเวลาเริ่มเล่นไม่ถูกต้อง'
            });
        }
        if (playEndTime && !timeRegex.test(playEndTime)) {
            return res.status(400).json({
                success: false,
                error: 'รูปแบบเวลาปิดสนามไม่ถูกต้อง'
            });
        }

        const updateData = {
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };

        // อัปเดตเฉพาะฟิลด์ที่ส่งมา
        if (name !== undefined) updateData.name = name;
        if (type !== undefined) updateData.type = type;
        if (category !== undefined) updateData.category = category;
        if (number !== undefined) {
            const parsedNumber = parseInt(number);
            if (isNaN(parsedNumber) || parsedNumber < 0) {
                return res.status(400).json({
                    success: false,
                    error: 'หมายเลขสนามต้องเป็นตัวเลขที่ถูกต้อง'
                });
            }
            updateData.number = parsedNumber;
        }
        if (isActivityOnly !== undefined) updateData.isActivityOnly = isActivityOnly;
        if (openBookingTime !== undefined) updateData.openBookingTime = openBookingTime;
        if (playStartTime !== undefined) updateData.playStartTime = playStartTime;
        if (playEndTime !== undefined) updateData.playEndTime = playEndTime;
        if (isAvailable !== undefined) updateData.isAvailable = isAvailable;
        if (requiredPlayers !== undefined) {
            // ค่าว่างหมายถึงให้ใช้ค่าเริ่มต้นตามประเภท (ใหม่หรือเดิม)
            if (requiredPlayers === null || requiredPlayers === '') {
                const newCategory = category !== undefined ? category : (courtDoc.data().category);
                const defaultPlayers = (cat => {
                    switch (cat) {
                        case 'futsal': return 4;
                        case 'basketball': return 5;
                        case 'football': return 11;
                        case 'volleyball': return 6;
                        case 'tennis': return 2;
                        case 'badminton': return 2;
                        case 'table_tennis': return 2;
                        case 'takraw': return 3;
                        case 'multipurpose': return 4;
                        default: return 2;
                    }
                })(newCategory);
                updateData.requiredPlayers = defaultPlayers;
            } else {
                const rp = parseInt(requiredPlayers);
                if (isNaN(rp) || rp < 1 || rp > 50) {
                    return res.status(400).json({
                        success: false,
                        error: 'จำนวนคนต้องเป็นตัวเลข 1-50 คน'
                    });
                }
                updateData.requiredPlayers = rp;
            }
        }
        if (location !== undefined) updateData.location = location;

        await courtRef.update(updateData);

        // ดึงข้อมูลสนามที่อัปเดตแล้ว
        const updatedCourtDoc = await courtRef.get();
        const updatedCourt = {
            ...updatedCourtDoc.data(),
            id: updatedCourtDoc.id
        };

        res.json({
            success: true,
            message: 'แก้ไขข้อมูลสนามสำเร็จ',
            court: updatedCourt
        });
    } catch (error) {
        console.error('Update court error:', error);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการอัปเดตสนาม'
        });
    }
});

// จัดการคะแนนผู้ใช้
router.patch('/users/:userId/points', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { userId } = req.params;
        const { points, action, reason } = req.body; // action: 'add', 'subtract', 'set'
        const db = admin.firestore();
        
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            return res.status(404).json({
                success: false,
                error: 'ไม่พบผู้ใช้'
            });
        }

        const userData = userDoc.data();
        const currentPoints = userData.points || 100;
        let newPoints = currentPoints;

        switch (action) {
            case 'add':
                newPoints = currentPoints + points;
                break;
            case 'subtract':
                newPoints = Math.max(0, currentPoints - points); // ไม่ให้ติดลบ
                break;
            case 'set':
                newPoints = Math.max(0, points);
                break;
            default:
                return res.status(400).json({
                    success: false,
                    error: 'การกระทำไม่ถูกต้อง (add, subtract, set)'
                });
        }

        // อัปเดตคะแนนผู้ใช้
        await db.collection('users').doc(userId).update({
            points: newPoints,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // บันทึกประวัติการเปลี่ยนแปลงคะแนน
        await db.collection('pointHistory').add({
            userId: userId,
            pointsBefore: currentPoints,
            pointsAfter: newPoints,
            pointsChanged: newPoints - currentPoints,
            action: action,
            reason: reason || 'การปรับคะแนนโดย Admin',
            adminId: req.user.userId,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        res.json({
            success: true,
            message: `${action === 'add' ? 'เพิ่ม' : action === 'subtract' ? 'หัก' : 'กำหนด'}คะแนนสำเร็จ`,
            pointsBefore: currentPoints,
            pointsAfter: newPoints
        });
    } catch (error) {
        console.error('Update user points error:', error);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการอัปเดตคะแนน'
        });
    }
});

// ยืนยันการใช้งานการจอง
router.patch('/bookings/:bookingId/verify-usage', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { bookingId } = req.params;
        const { actuallyUsed, pointsToDeduct = 10 } = req.body;
        const db = admin.firestore();
        
        const bookingDoc = await db.collection('bookings').doc(bookingId).get();
        if (!bookingDoc.exists) {
            return res.status(404).json({
                success: false,
                error: 'ไม่พบการจอง'
            });
        }

        const bookingData = bookingDoc.data();
        const userId = bookingData.userId;

        // อัปเดตสถานะการจอง
        await db.collection('bookings').doc(bookingId).update({
            actuallyUsed: actuallyUsed,
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            verifiedBy: req.user.userId,
            status: 'verified'
        });

        let pointsDeducted = 0;
        let message = actuallyUsed ? 'ยืนยันการใช้งานสนามแล้ว' : 'ยืนยันว่าไม่ได้ใช้สนาม';

        // หากไม่ได้ใช้งานจริง ให้หักคะแนน
        if (!actuallyUsed && userId) {
            try {
                const userDoc = await db.collection('users').doc(userId).get();
                if (userDoc.exists) {
                    const userData = userDoc.data();
                    const currentPoints = userData.points || 100;
                    const newPoints = Math.max(0, currentPoints - pointsToDeduct);

                    await db.collection('users').doc(userId).update({
                        points: newPoints,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    });

                    // บันทึกประวัติการหักคะแนน
                    await db.collection('pointHistory').add({
                        userId: userId,
                        pointsBefore: currentPoints,
                        pointsAfter: newPoints,
                        pointsChanged: -pointsToDeduct,
                        action: 'subtract',
                        reason: `หักคะแนนเนื่องจากไม่ได้ใช้สนามตามการจอง ${bookingId}`,
                        adminId: req.user.userId,
                        bookingId: bookingId,
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });

                    pointsDeducted = pointsToDeduct;
                    message += ` และหักคะแนน ${pointsToDeduct} แต้ม`;
                }
            } catch (pointError) {
                console.error('Error deducting points:', pointError);
                // ไม่ให้ error ของคะแนนมาขัดจังหวะการยืนยัน
            }
        }

        res.json({
            success: true,
            message: message,
            actuallyUsed: actuallyUsed,
            pointsDeducted: pointsDeducted
        });
    } catch (error) {
        console.error('Verify booking usage error:', error);
        res.status(500).json({
            success: false,
            error: 'เกิดข้อผิดพลาดในการยืนยันการใช้งาน'
        });
    }
});

// Admin: update editable content or system settings
// PATCH /api/admin/content -> { key, value }
router.patch('/content', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { key, value } = req.body || {};
        if (!key) return res.status(400).json({ success: false, error: 'missing key' });
        const db = admin.firestore();
        // Allow numbers and strings; store as-is except undefined -> '' for backward compat
        let storedValue = value;
        if (typeof storedValue === 'undefined' || storedValue === null) storedValue = '';
        await db.collection('settings').doc(key).set({
            value: storedValue,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedBy: req.user.id || 'admin'
        }, { merge: true });
        
        // Clear cache for this setting to make it effective immediately
        clearCache(key);
        
        res.json({ success: true, key, value });
    } catch (e) {
        console.error('Update content error:', e);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการอัปเดตเนื้อหา' });
    }
});

// Clear settings cache (admin only)
router.post('/clear-cache', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { key } = req.body || {};
        const result = clearCache(key);
        res.json({ 
            success: true, 
            message: key ? `ล้าง cache สำหรับ ${key} แล้ว` : 'ล้าง cache ทั้งหมดแล้ว',
            ...result
        });
    } catch (e) {
        console.error('Clear cache error:', e);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการล้าง cache' });
    }
});

module.exports = router;
// === Extended admin user management ===

// Update user profile (admin can edit user info)
router.put('/users/:userId', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { userId } = req.params;
        const {
            firstName,
            lastName,
            studentId,
            email,
            phone,
            role,
            points,
            isActive
        } = req.body || {};

        const db = admin.firestore();
        const userRef = db.collection('users').doc(userId);
        const userDoc = await userRef.get();
        if (!userDoc.exists) {
            return res.status(404).json({ success: false, error: 'ไม่พบผู้ใช้' });
        }

        const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };

        // Validate and assign
        if (typeof firstName === 'string') updates.firstName = firstName.trim();
        if (typeof lastName === 'string') updates.lastName = lastName.trim();
        if (typeof phone === 'string') {
            const p = phone.trim();
            if (p && (p.length !== 10 || isNaN(p))) {
                return res.status(400).json({ success: false, error: 'กรุณากรอกเบอร์โทรศัพท์ที่ถูกต้อง (10 หลัก)' });
            }
            updates.phone = p;
        }
        if (typeof role === 'string') updates.role = role;
        if (typeof isActive === 'boolean') updates.isActive = isActive;

        if (typeof points !== 'undefined') {
            const n = Number(points);
            if (isNaN(n) || n < 0) return res.status(400).json({ success: false, error: 'คะแนนต้องเป็นตัวเลขไม่ติดลบ' });
            updates.points = n;
        }

        if (typeof email === 'string') {
            const normalizedEmail = email.toLowerCase().trim();
            // basic email format
            const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
            if (!emailRegex.test(normalizedEmail)) {
                return res.status(400).json({ success: false, error: 'กรุณากรอกอีเมลที่ถูกต้อง' });
            }
            // ensure uniqueness among other users
            const dup = await db.collection('users').where('email', '==', normalizedEmail).get();
            const dupExists = dup.docs.some(d => d.id !== userId);
            if (dupExists) return res.status(400).json({ success: false, error: 'อีเมลนี้มีผู้ใช้งานแล้ว' });
            updates.email = normalizedEmail;
        }

        if (typeof studentId !== 'undefined') {
            const sid = String(studentId).trim();
            if (!/^[0-9]{8,13}$/.test(sid)) {
                return res.status(400).json({ success: false, error: 'กรุณากรอกรหัสนักศึกษา/เลขบัตรประชาชนให้ถูกต้อง' });
            }
            // ensure uniqueness among other users
            const dup = await db.collection('users').where('studentId', '==', sid).get();
            const dupExists = dup.docs.some(d => d.id !== userId);
            if (dupExists) return res.status(400).json({ success: false, error: 'รหัสนี้มีผู้ใช้งานแล้ว' });
            updates.studentId = sid;
        }

        await userRef.update(updates);
        const updated = await userRef.get();
        const { password, ...data } = updated.data();

        res.json({ success: true, message: 'แก้ไขข้อมูลผู้ใช้สำเร็จ', user: { id: updated.id, ...data } });
    } catch (error) {
        console.error('Admin update user error:', error);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการแก้ไขผู้ใช้' });
    }
});

// Block/unblock user abilities (requests/messages)
router.patch('/users/:userId/block', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { userId } = req.params;
        const { requestBlocked, messagesBlocked, reason } = req.body || {};
        const db = admin.firestore();

        const userRef = db.collection('users').doc(userId);
        const userDoc = await userRef.get();
        if (!userDoc.exists) return res.status(404).json({ success: false, error: 'ไม่พบผู้ใช้' });

        const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
        if (typeof requestBlocked === 'boolean') {
            updates.isRequestBlocked = requestBlocked;
            if (requestBlocked && typeof reason === 'string') updates.requestBlockReason = reason.trim();
            if (!requestBlocked) updates.requestBlockReason = null;
        }
        if (typeof messagesBlocked === 'boolean') {
            updates.isMessagesBlocked = messagesBlocked;
        }

        await userRef.update(updates);
        res.json({ success: true, message: 'อัปเดตการบล็อคสำเร็จ', updates });
    } catch (error) {
        console.error('Admin set block error:', error);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการอัปเดตการบล็อค' });
    }
});

// Delete user (soft delete to preserve references)
router.delete('/users/:userId', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { userId } = req.params;
        const db = admin.firestore();

        // prevent self-delete
        if (req.user.userId === userId) {
            return res.status(400).json({ success: false, error: 'ไม่สามารถลบบัญชีของตนเองได้' });
        }

        const userRef = db.collection('users').doc(userId);
        const userDoc = await userRef.get();
        if (!userDoc.exists) return res.status(404).json({ success: false, error: 'ไม่พบผู้ใช้' });

        // archive then hard delete
        const data = userDoc.data() || {};
        const archiveRef = db.collection('deletedUsers').doc(userId);
        await archiveRef.set({
            ...data,
            deletedAt: admin.firestore.FieldValue.serverTimestamp(),
            deletedBy: req.user.userId,
        });

        await userRef.delete();

        res.json({ success: true, message: 'ลบผู้ใช้สำเร็จ' });
    } catch (error) {
        console.error('Admin delete user error:', error);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการลบผู้ใช้' });
    }
});

// ================= Deleted Users Management =================
// List deleted users
router.get('/deleted-users', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const db = admin.firestore();
        const snapshot = await db.collection('deletedUsers')
            .orderBy('deletedAt', 'desc')
            .get();
        const users = snapshot.docs.map(doc => {
            const data = doc.data();
            const { password, ...safe } = data || {};
            return { id: doc.id, ...safe };
        });
        res.json({ success: true, data: users });
    } catch (error) {
        console.error('List deleted users error:', error);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการดึงข้อมูลผู้ใช้ที่ถูกลบ' });
    }
});

// Restore a deleted user back to users collection
router.post('/deleted-users/:userId/restore', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { userId } = req.params;
        const db = admin.firestore();

        const deletedRef = db.collection('deletedUsers').doc(userId);
        const deletedDoc = await deletedRef.get();
        if (!deletedDoc.exists) return res.status(404).json({ success: false, error: 'ไม่พบผู้ใช้ในรายการที่ถูกลบ' });

        const data = deletedDoc.data() || {};

        // Validate duplicates by email and studentId among active users
        const email = (data.email || '').toLowerCase();
        if (email) {
            const dupEmailSnap = await db.collection('users').where('email', '==', email).get();
            if (!dupEmailSnap.empty) {
                return res.status(409).json({ success: false, error: 'อีเมลนี้ถูกใช้งานอยู่แล้วในระบบ ไม่สามารถกู้คืนได้' });
            }
        }
        const sid = (data.studentId || '').toString();
        if (sid) {
            const dupSidSnap = await db.collection('users').where('studentId', '==', sid).get();
            if (!dupSidSnap.empty) {
                return res.status(409).json({ success: false, error: 'รหัสนักศึกษานี้ถูกใช้งานอยู่แล้วในระบบ ไม่สามารถกู้คืนได้' });
            }
        }

        // Prepare payload for restore
        const restored = {
            ...data,
            isDeleted: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            restoredAt: admin.firestore.FieldValue.serverTimestamp(),
            restoredBy: req.user.userId,
        };
        // remove archive-only fields to reduce confusion
        delete restored.deletedAt;
        delete restored.deletedBy;

        // Write back to users with original id
        await db.collection('users').doc(userId).set(restored, { merge: true });
        // Remove from archive
        await deletedRef.delete();

        res.json({ success: true, message: 'กู้คืนผู้ใช้สำเร็จ' });
    } catch (error) {
        console.error('Restore deleted user error:', error);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการกู้คืนผู้ใช้' });
    }
});

// Permanently delete a single archived user
router.delete('/deleted-users/:userId', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { userId } = req.params;
        const db = admin.firestore();
        const ref = db.collection('deletedUsers').doc(userId);
        const doc = await ref.get();
        if (!doc.exists) return res.status(404).json({ success: false, error: 'ไม่พบผู้ใช้ในรายการที่ถูกลบ' });
        await ref.delete();
        res.json({ success: true, message: 'ลบถาวรผู้ใช้สำเร็จ' });
    } catch (error) {
        console.error('Purge deleted user error:', error);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการลบถาวรผู้ใช้' });
    }
});

// Permanently delete all archived users
router.delete('/deleted-users', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const db = admin.firestore();
        const snapshot = await db.collection('deletedUsers').get();
        const batch = db.batch();
        snapshot.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        res.json({ success: true, message: 'ลบผู้ใช้ที่ถูกลบทั้งหมดแล้ว' });
    } catch (error) {
        console.error('Purge all deleted users error:', error);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการลบผู้ใช้ที่ถูกลบทั้งหมด' });
    }
});
