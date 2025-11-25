const express = require('express');
const router = express.Router();
const admin = require('../../config/firebase');
const { authenticateToken } = require('../middleware/auth');

// ฟังก์ชันกำหนดจำนวนคนเริ่มต้นตามประเภทสนาม
function getDefaultRequiredPlayers(category) {
    switch (category) {
        case 'futsal':
            return 4; // ฟุตซอล 4 คน
        case 'basketball':
            return 5; // บาสเกตบอล 5 คน
        case 'football':
            return 11; // ฟุตบอล 11 คน
        case 'volleyball':
            return 6; // วอลเลย์บอล 6 คน
        case 'tennis':
            return 2; // เทนนิส 2 คน
        case 'badminton':
            return 2; // แบดมินตัน 2 คน
        case 'table_tennis':
            return 2; // เทเบิลเทนนิส 2 คน
        case 'takraw':
            return 3; // ตะกร้อ 3 คน
        case 'multipurpose':
            return 4; // อเนกประสงค์ 4 คน
        default:
            return 2; // ค่าเริ่มต้น 2 คน
    }
}

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

        console.log('Checking admin status for user:', req.user.id);
        
        // ตรวจสอบ system admin token ก่อน
        if (req.user.id === 'admin' && req.user.type === 'system_admin' && req.user.isAdmin === true) {
            console.log('System admin access granted');
            return next();
        }
        
        const db = admin.firestore();
        const userDoc = await db.collection('users').doc(req.user.id).get();
        
        if (!userDoc.exists) {
            console.error('User document not found:', req.user.id);
            return res.status(404).json({ error: 'ไม่พบข้อมูลผู้ใช้' });
        }
        
        const userData = userDoc.data();
        console.log('User data for admin check:', { email: userData.email, id: req.user.id });
        
        // ตรวจสอบอีเมล admin (เพิ่ม admin@silpakorn.edu ด้วย)
        const adminEmails = [
            'admin@gmail.com', 
            'admin@su.ac.th', 
            'admin@silpakorn.edu'
        ];
        
        if (!adminEmails.includes(userData.email)) {
            console.log('Access denied for non-admin user:', userData.email);
            return res.status(403).json({ error: 'ไม่มีสิทธิ์เข้าถึง - ต้องเป็น admin เท่านั้น' });
        }
        
        console.log('Admin access granted for:', userData.email);
        next();
    } catch (err) {
        console.error('Error checking admin:', err);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในการตรวจสอบสิทธิ์' });
    }
};

// ดึงข้อมูลสนามทั้งหมด (สำหรับการแสดงผล)
router.get('/courts', async (req, res) => {
    try {
        const db = admin.firestore();
        const courtsRef = db.collection('courts');
        const snapshot = await courtsRef.get();
        
        const courts = {};
        snapshot.forEach(doc => {
            courts[doc.id] = {
                ...doc.data(),
                id: doc.id
            };
        });
        
        res.json({ courts });
    } catch (err) {
        console.error('Error getting courts:', err);
        res.status(500).json({ error: err.message });
    }
});

// ดึงข้อมูลสนามแยกตามประเภท
router.get('/courts/by-type/:type', async (req, res) => {
    try {
        const { type } = req.params;
        const db = admin.firestore();
        const courtsRef = db.collection('courts').where('type', '==', type);
        const snapshot = await courtsRef.get();
        
        const courts = {};
        snapshot.forEach(doc => {
            courts[doc.id] = {
                ...doc.data(),
                id: doc.id
            };
        });
        
        res.json({ courts });
    } catch (err) {
        console.error('Error getting courts by type:', err);
        res.status(500).json({ error: err.message });
    }
});

// ดึงข้อมูลสนามแยกตามหมวดหมู่
router.get('/courts/by-category/:category', async (req, res) => {
    try {
        const { category } = req.params;
        const db = admin.firestore();
        const courtsRef = db.collection('courts').where('category', '==', category);
        const snapshot = await courtsRef.get();
        
        const courts = {};
        snapshot.forEach(doc => {
            courts[doc.id] = {
                ...doc.data(),
                id: doc.id
            };
        });
        
        res.json({ courts });
    } catch (err) {
        console.error('Error getting courts by category:', err);
        res.status(500).json({ error: err.message });
    }
});

// ดึงข้อมูลสนามเฉพาะ
router.get('/courts/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const db = admin.firestore();
        const courtDoc = await db.collection('courts').doc(id).get();
        
        if (!courtDoc.exists) {
            return res.status(404).json({ error: 'ไม่พบข้อมูลสนาม' });
        }
        
        const court = {
            ...courtDoc.data(),
            id: courtDoc.id
        };
        
        res.json({ court });
    } catch (err) {
        console.error('Error getting court:', err);
        res.status(500).json({ error: err.message });
    }
});

// เพิ่มสนามใหม่ (เฉพาะ admin)
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
                error: 'กรุณาระบุข้อมูลที่จำเป็น: name, type, category, number, openBookingTime, playStartTime, playEndTime' 
            });
        }

        // ตรวจสอบรูปแบบเวลา
        const timeRegex = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
        if (!timeRegex.test(openBookingTime) || !timeRegex.test(playStartTime) || !timeRegex.test(playEndTime)) {
            return res.status(400).json({ 
                error: 'รูปแบบเวลาไม่ถูกต้อง (ใช้รูปแบบ HH:MM)' 
            });
        }

        // สร้าง ID สำหรับสนาม
        const courtId = `${type}_${category}_${number}`;

        const db = admin.firestore();
        
        // ตรวจสอบว่ามีสนามนี้อยู่แล้วหรือไม่
        const existingCourt = await db.collection('courts').doc(courtId).get();
        if (existingCourt.exists) {
            return res.status(400).json({ error: 'มีสนามนี้อยู่แล้ว' });
        }

        // จัดการและตรวจสอบจำนวนคนที่ต้องการ
        let parsedRequiredPlayers;
        if (requiredPlayers === undefined || requiredPlayers === null || requiredPlayers === '') {
            parsedRequiredPlayers = getDefaultRequiredPlayers(category);
        } else {
            const rp = parseInt(requiredPlayers);
            if (isNaN(rp) || rp < 1 || rp > 50) {
                return res.status(400).json({ error: 'จำนวนคนต้องเป็นตัวเลข 1-50 คน' });
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
            message: 'เพิ่มสนามสำเร็จ',
            court: {
                ...courtData,
                id: courtId
            }
        });

    } catch (err) {
        console.error('Error adding court:', err);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในการเพิ่มสนาม' });
    }
});

// แก้ไขข้อมูลสนาม (เฉพาะ admin)
router.put('/courts/:id', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
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
        const courtRef = db.collection('courts').doc(id);
        const courtDoc = await courtRef.get();

        if (!courtDoc.exists) {
            return res.status(404).json({ error: 'ไม่พบข้อมูลสนาม' });
        }

        // ตรวจสอบรูปแบบเวลา (ถ้ามีการส่งมา)
        const timeRegex = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
        if (openBookingTime && !timeRegex.test(openBookingTime)) {
            return res.status(400).json({ error: 'รูปแบบเวลาเปิดจองไม่ถูกต้อง' });
        }
        if (playStartTime && !timeRegex.test(playStartTime)) {
            return res.status(400).json({ error: 'รูปแบบเวลาเริ่มเล่นไม่ถูกต้อง' });
        }
        if (playEndTime && !timeRegex.test(playEndTime)) {
            return res.status(400).json({ error: 'รูปแบบเวลาปิดสนามไม่ถูกต้อง' });
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
                return res.status(400).json({ error: 'หมายเลขสนามต้องเป็นตัวเลขที่ถูกต้อง' });
            }
            updateData.number = parsedNumber;
        }
        if (isActivityOnly !== undefined) updateData.isActivityOnly = isActivityOnly;
        if (openBookingTime !== undefined) updateData.openBookingTime = openBookingTime;
        if (playStartTime !== undefined) updateData.playStartTime = playStartTime;
        if (playEndTime !== undefined) updateData.playEndTime = playEndTime;
        if (isAvailable !== undefined) updateData.isAvailable = isAvailable;
        if (requiredPlayers !== undefined) {
            // รองรับค่าว่าง = ใช้ค่าเริ่มต้นตามประเภท (ใหม่หรือเดิม)
            if (requiredPlayers === null || requiredPlayers === '') {
                const newCategory = category !== undefined ? category : (courtDoc.data().category);
                updateData.requiredPlayers = getDefaultRequiredPlayers(newCategory);
            } else {
                const rp = parseInt(requiredPlayers);
                if (isNaN(rp) || rp < 1 || rp > 50) {
                    return res.status(400).json({ error: 'จำนวนคนต้องเป็นตัวเลข 1-50 คน' });
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
            message: 'แก้ไขข้อมูลสนามสำเร็จ',
            court: updatedCourt
        });

    } catch (err) {
        console.error('Error updating court:', err);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในการแก้ไขข้อมูลสนาม' });
    }
});

// ลบสนาม (เฉพาะ admin)
router.delete('/courts/:id', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const db = admin.firestore();
        
        const courtRef = db.collection('courts').doc(id);
        const courtDoc = await courtRef.get();

        if (!courtDoc.exists) {
            return res.status(404).json({ error: 'ไม่พบข้อมูลสนาม' });
        }

        // ตรวจสอบว่ามีการจองที่ยังไม่เสร็จสิ้นหรือไม่
        const bookingsSnapshot = await db.collection('bookings')
            .where('courtId', '==', id)
            .where('status', 'in', ['confirmed', 'checked_in'])
            .get();

        if (!bookingsSnapshot.empty) {
            return res.status(400).json({ 
                error: `ไม่สามารถลบสนามได้ เนื่องจากมีการจองที่ยังไม่เสร็จสิ้น ${bookingsSnapshot.size} รายการ` 
            });
        }

        const courtData = courtDoc.data();
        await courtRef.delete();

        res.json({
            message: 'ลบสนามสำเร็จ',
            deletedCourt: {
                ...courtData,
                id
            }
        });

    } catch (err) {
        console.error('Error deleting court:', err);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในการลบสนาม' });
    }
});

// เปิด/ปิดการใช้งานสนาม (เฉพาะ admin)
router.patch('/courts/:id/toggle-availability', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const db = admin.firestore();
        
        const courtRef = db.collection('courts').doc(id);
        const courtDoc = await courtRef.get();

        if (!courtDoc.exists) {
            return res.status(404).json({ error: 'ไม่พบข้อมูลสนาม' });
        }

        const currentData = courtDoc.data();
        const newAvailability = !currentData.isAvailable;

        await courtRef.update({
            isAvailable: newAvailability,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        res.json({
            message: `${newAvailability ? 'เปิด' : 'ปิด'}การใช้งานสนามสำเร็จ`,
            court: {
                ...currentData,
                id,
                isAvailable: newAvailability
            }
        });

    } catch (err) {
        console.error('Error toggling court availability:', err);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในการเปลี่ยนสถานะสนาม' });
    }
});

// ดึงสถิติการใช้งานสนาม (เฉพาะ admin)
router.get('/courts/:id/statistics', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const { startDate, endDate } = req.query;
        
        const db = admin.firestore();
        
        // ตรวจสอบว่ามีสนามนี้อยู่หรือไม่
        const courtDoc = await db.collection('courts').doc(id).get();
        if (!courtDoc.exists) {
            return res.status(404).json({ error: 'ไม่พบข้อมูลสนาม' });
        }

        let query = db.collection('bookings').where('courtId', '==', id);
        
        if (startDate) {
            query = query.where('date', '>=', startDate);
        }
        if (endDate) {
            query = query.where('date', '<=', endDate);
        }

        const bookingsSnapshot = await query.get();
        const bookings = bookingsSnapshot.docs.map(doc => doc.data());

        const statistics = {
            totalBookings: bookings.length,
            completedBookings: bookings.filter(b => b.status === 'completed').length,
            cancelledBookings: bookings.filter(b => b.status === 'cancelled').length,
            noShowBookings: bookings.filter(b => b.status === 'no_show').length,
            confirmedBookings: bookings.filter(b => b.status === 'confirmed').length,
            checkedInBookings: bookings.filter(b => b.status === 'checked_in').length,
            usageByMonth: {},
            usageByTimeSlot: {}
        };

        // สถิติการใช้งานรายเดือน
        bookings.forEach(booking => {
            const month = booking.date.substring(0, 7); // YYYY-MM
            statistics.usageByMonth[month] = (statistics.usageByMonth[month] || 0) + 1;
        });

        // สถิติการใช้งานตามช่วงเวลา
        bookings.forEach(booking => {
            if (booking.timeSlots && Array.isArray(booking.timeSlots)) {
                booking.timeSlots.forEach(timeSlot => {
                    statistics.usageByTimeSlot[timeSlot] = (statistics.usageByTimeSlot[timeSlot] || 0) + 1;
                });
            }
        });

        res.json({
            court: {
                ...courtDoc.data(),
                id: courtDoc.id
            },
            statistics,
            dateRange: {
                startDate: startDate || 'ทั้งหมด',
                endDate: endDate || 'ทั้งหมด'
            }
        });

    } catch (err) {
        console.error('Error getting court statistics:', err);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในการดึงสถิติการใช้งานสนาม' });
    }
});

module.exports = router;