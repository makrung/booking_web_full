const admin = require('./config/firebase');
const db = admin.firestore();

async function checkDuplicateUserCodes() {
    try {
        console.log('🔍 กำลังตรวจสอบรหัสผู้ใช้ซ้ำ...\n');

        const usersSnapshot = await db.collection('users').get();
        const codes = {};
        const duplicates = [];

        usersSnapshot.forEach(doc => {
            const data = doc.data();
            const code = data.userCode;
            
            if (!code) {
                console.log(`⚠️  ผู้ใช้ ${doc.id} ไม่มี userCode`);
                return;
            }

            if (codes[code]) {
                duplicates.push({
                    code: code,
                    users: [codes[code], { id: doc.id, email: data.email, name: `${data.firstName} ${data.lastName}` }]
                });
            } else {
                codes[code] = { id: doc.id, email: data.email, name: `${data.firstName} ${data.lastName}` };
            }
        });

        console.log(`📊 จำนวนผู้ใช้ทั้งหมด: ${usersSnapshot.size}`);
        console.log(`📊 จำนวนรหัสที่ไม่ซ้ำ: ${Object.keys(codes).length}\n`);

        if (duplicates.length > 0) {
            console.log(`❌ พบรหัสซ้ำ ${duplicates.length} รายการ:\n`);
            duplicates.forEach((dup, index) => {
                console.log(`${index + 1}. รหัส "${dup.code}" ซ้ำกัน:`);
                dup.users.forEach(user => {
                    console.log(`   - ${user.name} (${user.email})`);
                });
                console.log('');
            });
        } else {
            console.log('✅ ไม่พบรหัสซ้ำในระบบ');
        }

    } catch (error) {
        console.error('❌ เกิดข้อผิดพลาด:', error);
    } finally {
        process.exit(0);
    }
}

checkDuplicateUserCodes();
