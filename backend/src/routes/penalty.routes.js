const express = require('express');
const router = express.Router();
const admin = require('../../config/firebase');
const { authenticateToken } = require('../middleware/auth');
const { isBookingActuallyExpired } = require('../../penalty-protection');
const { getNumericSetting } = require('../services/settings.service');

// ตรวจสอบและใช้คะแนนโทษสำหรับการจองที่หมดเวลา
router.post('/penalties/check-expired-bookings', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const userId = req.user.userId;
        
        // หาการจองที่ยังไม่ได้ยืนยันและหมดเวลาแล้ว
        const now = new Date();
        const currentDate = now.toISOString().split('T')[0]; // วันปัจจุบัน
        const currentTime = now.getHours() * 60 + now.getMinutes(); // เวลาปัจจุบันเป็นนาที
        
        console.log(`Checking expired bookings for user: ${userId}`);
        console.log(`Current time: ${now.toISOString()}`);
        
        const bookingsRef = db.collection('bookings')
            .where('userId', '==', userId)
            .where('isLocationVerified', '==', false)
            .where('status', '==', 'pending');
        
        const snapshot = await bookingsRef.get();
        const expiredBookings = [];
        let totalPenaltyPoints = 0;
        
        // Load configurable penalty amount from settings (same as auto-cancel penalty)
        const penaltyAmount = await getNumericSetting('penalty_no_checkin_auto_cancel', 50);

        for (const doc of snapshot.docs) {
            const booking = doc.data();
            const bookingDate = booking.date; // วันที่จอง (YYYY-MM-DD)
            const timeSlots = booking.timeSlots || []; // เวลาที่จอง
            
            console.log(`Checking booking ${doc.id}: Date=${bookingDate}, TimeSlots=${JSON.stringify(timeSlots)}`);
            
            // ใช้ระบบตรวจสอบที่แม่นยำมากขึ้น
            const isExpired = await isBookingActuallyExpired({ 
                ...booking, 
                id: doc.id 
            });
            
            if (isExpired) {
                // Do not penalize activity bookings
                if (String(booking.bookingType || 'regular').toLowerCase() === 'activity') {
                    console.log('  -> Skipping penalty for activity booking');
                    continue;
                }
                const penaltyPoints = penaltyAmount;
                
                // ตรวจสอบว่าได้หักคะแนนแล้วหรือยัง
                const existingPenalty = await db.collection('penalties')
                    .where('bookingId', '==', doc.id)
                    .where('userId', '==', userId)
                    .get();
                
                if (existingPenalty.empty) {
                    console.log(`  -> Applying penalty: ${penaltyPoints} points`);
                    
                    // บันทึกคะแนนโทษ
                    await db.collection('penalties').add({
                        userId: userId,
                        bookingId: doc.id,
                        penaltyPoints: penaltyPoints,
                        reason: 'ไม่ได้มายืนยันการจองตรงเวลา',
                        courtName: booking.courtName,
                        bookingDate: booking.date,
                        timeSlots: booking.timeSlots,
                        bookingType: booking.bookingType,
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                    
                    // อัปเดตสถานะการจอง
                    await db.collection('bookings').doc(doc.id).update({
                        status: 'expired',
                        penaltyApplied: true,
                        expiredAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                    
                    // หักคะแนนจากผู้ใช้
                    const userDoc = await db.collection('users').doc(userId).get();
                    if (userDoc.exists) {
                        const userData = userDoc.data();
                        const current = Number(userData.points || 0);
                        const newPoints = Math.max(0, current - Number(penaltyPoints));
                        
                        await db.collection('users').doc(userId).update({
                            points: Math.max(0, newPoints),
                            updatedAt: admin.firestore.FieldValue.serverTimestamp()
                        });
                    }
                    
                    expiredBookings.push({
                        bookingId: doc.id,
                        courtName: booking.courtName,
                        date: booking.date,
                        timeSlots: booking.timeSlots,
                        penaltyPoints: penaltyPoints
                    });
                    
                    totalPenaltyPoints += penaltyPoints;
                } else {
                    console.log(`  -> Already penalized`);
                }
            } else {
                console.log(`  -> Not expired yet or protected`);
            }
        }
        
        console.log(`Total penalty points applied: ${totalPenaltyPoints}`);
        
        res.json({ 
            success: true, 
            expiredBookings,
            totalPenaltyPoints,
            message: totalPenaltyPoints > 0 ? 
                `หักคะแนนรวม ${totalPenaltyPoints} คะแนน จากการไม่ยืนยันการจอง` : 
                'ไม่มีการจองที่หมดเวลา'
        });
    } catch (err) {
        console.error('Check expired bookings error:', err);
        res.status(500).json({ success: false, error: err.message });
    }
});

// ดึงประวัติคะแนนโทษ
router.get('/penalties/history', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const userId = req.user.userId;
        
        // ลบ orderBy ออกเพื่อไม่ให้ต้อง index
        const penaltiesRef = db.collection('penalties')
            .where('userId', '==', userId);
        
        const snapshot = await penaltiesRef.get();
        const penalties = [];
        let totalPoints = 0;
        
        snapshot.forEach(doc => {
            const data = doc.data();
            penalties.push({
                id: doc.id,
                ...data,
                createdAt: data.createdAt ? data.createdAt.toDate().toISOString() : null
            });
            totalPoints += data.penaltyPoints || 0;
        });
        
        // เรียงลำดับ client-side
        penalties.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
        
        res.json({ 
            success: true, 
            penalties,
            totalPenaltyPoints: totalPoints
        });
    } catch (err) {
        console.error('Get penalty history error:', err);
        res.status(500).json({ success: false, error: err.message });
    }
});

// ดึงคะแนนปัจจุบันของผู้ใช้
router.get('/user/points', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const userId = req.user.userId;
        
        const userDoc = await db.collection('users').doc(userId).get();
        
        if (!userDoc.exists) {
            return res.status(404).json({ success: false, error: 'ไม่พบข้อมูลผู้ใช้' });
        }
        
        const userData = userDoc.data();
        
        // Important: use nullish coalescing to preserve 0 points (don't fallback on falsy)
        res.json({ 
            success: true, 
            points: (userData.points ?? 0),
            user: {
                firstName: userData.firstName,
                lastName: userData.lastName,
                email: userData.email
            }
        });
    } catch (err) {
        console.error('Get user points error:', err);
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;
