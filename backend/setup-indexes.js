// สคริปต์สำหรับสร้าง collection และ index ใน Firestore
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

async function createIndexes() {
    try {
        console.log('NOTE: For messages inbox ordering, create a composite index on collection "messages" with fields: userId ASC, createdAt DESC.');
        console.log('Creating sample documents for index generation...');
        
        // สร้างเอกสารตัวอย่างใน penalties collection เพื่อให้ Firestore สร้าง index
        const samplePenalty = {
            userId: 'sample_user_id',
            penaltyPoints: 10,
            reason: 'ไม่ได้มายืนยันการจองตรงเวลา',
            courtName: 'สนามตัวอย่าง',
            bookingDate: '2025-01-01',
            timeSlots: ['08:00-09:00'],
            bookingType: 'regular',
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        };

        const penaltyRef = await db.collection('penalties').add(samplePenalty);
        console.log('Sample penalty document created:', penaltyRef.id);

        // รอสักครู่เพื่อให้ timestamp ถูกสร้าง
        await new Promise(resolve => setTimeout(resolve, 2000));

        // ลอง query เพื่อให้ Firestore เสนอการสร้าง index
        try {
            console.log('Testing query that requires index...');
            const penaltiesRef = db.collection('penalties')
                .where('userId', '==', 'sample_user_id')
                .orderBy('createdAt', 'desc')
                .limit(1);
            
            const snapshot = await penaltiesRef.get();
            console.log('Query successful! Index might already exist.');
        } catch (error) {
            if (error.code === 9) { // FAILED_PRECONDITION
                console.log('Index not found. Please create the index manually using this URL:');
                console.log(error.details);
                console.log('\nAlternatively, the app will work without the index by using client-side sorting.');
            } else {
                console.error('Unexpected error:', error);
            }
        }

        // ลบเอกสารตัวอย่าง
        await penaltyRef.delete();
        console.log('Sample document deleted.');

        console.log('\n=== INDEX SETUP COMPLETE ===');
        console.log('If you saw an index URL above, please:');
        console.log('1. Click the URL to open Firebase Console');
        console.log('2. Click "Create Index"');
        console.log('3. Wait for the index to be built');
        console.log('\nOr the app will continue to work with client-side sorting.');

    } catch (error) {
        console.error('Error setting up indexes:', error);
    } finally {
        process.exit(0);
    }
}

createIndexes();
