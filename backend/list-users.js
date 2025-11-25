// สคริปต์สำหรับดูข้อมูลผู้ใช้ทั้งหมด
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

async function listAllUsers() {
    try {
        console.log('Listing all users...');
        
        const usersSnapshot = await db.collection('users').get();
        
        if (usersSnapshot.empty) {
            console.log('No users found');
            return;
        }
        
        console.log(`Found ${usersSnapshot.size} users:`);
        
        usersSnapshot.forEach((doc, index) => {
            const userData = doc.data();
            console.log(`${index + 1}. ID: ${doc.id}`);
            console.log(`   Email: ${userData.email}`);
            console.log(`   Name: ${userData.firstName} ${userData.lastName}`);
            console.log(`   Role: ${userData.role || 'user'}`);
            console.log(`   Active: ${userData.isActive}`);
            console.log(`   Points: ${userData.points || 0}`);
            console.log('   ---');
        });
        
    } catch (error) {
        console.error('Error listing users:', error);
    } finally {
        process.exit(0);
    }
}

listAllUsers();
