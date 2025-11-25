// สคริปต์สำหรับอัปเดต email ของ admin ให้เป็นตัวพิมพ์เล็ก
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

async function updateAdminEmail() {
    try {
        console.log('Updating admin email to lowercase...');
        
        // Find admin user
        const adminSnapshot = await db.collection('users')
            .where('email', '==', 'admin@silpakorn.edu')
            .get();
        
        if (adminSnapshot.empty) {
            // Try uppercase version
            const adminSnapshotUpper = await db.collection('users')
                .where('email', '==', 'ADMIN@SILPAKORN.EDU')
                .get();
            
            if (adminSnapshotUpper.empty) {
                console.log('Admin user not found with either case');
                return;
            }
            
            // Update uppercase to lowercase
            const adminDoc = adminSnapshotUpper.docs[0];
            await adminDoc.ref.update({
                email: 'admin@silpakorn.edu'
            });
            
            console.log('Admin email updated to lowercase: admin@silpakorn.edu');
        } else {
            console.log('Admin email already in lowercase format');
        }
        
        // Also update all existing user emails to lowercase
        console.log('Updating all user emails to lowercase...');
        
        const usersSnapshot = await db.collection('users').get();
        const batch = db.batch();
        let updateCount = 0;
        
        usersSnapshot.forEach(doc => {
            const userData = doc.data();
            if (userData.email && userData.email !== userData.email.toLowerCase()) {
                batch.update(doc.ref, {
                    email: userData.email.toLowerCase()
                });
                updateCount++;
            }
        });
        
        if (updateCount > 0) {
            await batch.commit();
            console.log(`Updated ${updateCount} user emails to lowercase`);
        } else {
            console.log('All user emails are already in lowercase format');
        }
        
        console.log('Email normalization completed!');
        
    } catch (error) {
        console.error('Error updating emails:', error);
    } finally {
        process.exit(0);
    }
}

updateAdminEmail();
