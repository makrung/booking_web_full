const express = require('express');
const router = express.Router();
const admin = require('../../config/firebase');

// Get all courts (public endpoint - ไม่ต้อง login)
router.get('/courts', async (req, res) => {
    try {
        const db = admin.firestore();
        const courtsRef = db.collection('courts');
        const snapshot = await courtsRef.get();
        
        const courts = {};
        snapshot.forEach(doc => {
            const courtData = doc.data();
            courts[doc.id] = {
                ...courtData,
                id: doc.id
            };
        });
        
        res.json({ courts });
    } catch (err) {
        console.error('Error getting courts:', err);
        res.status(500).json({ error: err.message });
    }
});

// Get courts by type (public endpoint)
router.get('/courts/type/:type', async (req, res) => {
    try {
        const { type } = req.params;
        const db = admin.firestore();
        const courtsRef = db.collection('courts').where('type', '==', type);
        const snapshot = await courtsRef.get();
        
        const courts = {};
        snapshot.forEach(doc => {
            const courtData = doc.data();
            courts[doc.id] = {
                ...courtData,
                id: doc.id
            };
        });
        
        res.json({ courts });
    } catch (err) {
        console.error('Error getting courts by type:', err);
        res.status(500).json({ error: err.message });
    }
});

// Get courts by category (public endpoint)
router.get('/courts/category/:category', async (req, res) => {
    try {
        const { category } = req.params;
        const db = admin.firestore();
        const courtsRef = db.collection('courts').where('category', '==', category);
        const snapshot = await courtsRef.get();
        
        const courts = {};
        snapshot.forEach(doc => {
            const courtData = doc.data();
            courts[doc.id] = {
                ...courtData,
                id: doc.id
            };
        });
        
        res.json({ courts });
    } catch (err) {
        console.error('Error getting courts by category:', err);
        res.status(500).json({ error: err.message });
    }
});

// Get specific court (public endpoint)
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

// Get available courts for booking (public endpoint)
router.get('/courts/available/:date', async (req, res) => {
    try {
        const { date } = req.params;
        const db = admin.firestore();
        
        // ดึงสนามที่เปิดใช้งาน
        const courtsSnapshot = await db.collection('courts')
            .where('isAvailable', '==', true)
            .orderBy('type')
            .orderBy('category')
            .orderBy('number')
            .get();
        
        const courts = {};
        courtsSnapshot.forEach(doc => {
            const courtData = doc.data();
            courts[doc.id] = {
                ...courtData,
                id: doc.id
            };
        });
        
        // ดึงการจองในวันนั้น
        const bookingsSnapshot = await db.collection('bookings')
            .where('date', '==', date)
            .where('status', 'in', ['confirmed', 'checked_in'])
            .get();
        
        const bookings = {};
        bookingsSnapshot.forEach(doc => {
            const booking = doc.data();
            const courtId = booking.courtId;
            
            if (!bookings[courtId]) {
                bookings[courtId] = [];
            }
            
            if (booking.timeSlots && Array.isArray(booking.timeSlots)) {
                bookings[courtId].push(...booking.timeSlots);
            }
        });
        
        res.json({ 
            courts,
            bookings,
            date
        });
    } catch (err) {
        console.error('Error getting available courts:', err);
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;