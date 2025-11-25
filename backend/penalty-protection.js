const admin = require('./config/firebase');

// ป้องกันการลดคะแนนผิดพลาดเมื่อเริ่มเซิร์ฟเวอร์
async function preventServerStartupPenalties() {
    try {
        console.log('🔒 Activating penalty protection on server startup...');
        
        const db = admin.firestore();
        
        // หาการจองทั้งหมดที่อาจจะโดนลดคะแนนผิดพลาด
        const now = new Date();
        const currentDate = now.toISOString().split('T')[0];
        const currentTime = now.getHours() * 60 + now.getMinutes();
        
        console.log(`Current time: ${now.toISOString()}`);
        
        // หาการจองที่ยังไม่หมดเวลาจริงๆ แต่อาจโดนลดคะแนน
        const bookingsRef = db.collection('bookings')
            .where('status', '==', 'pending')
            .where('isLocationVerified', '==', false);
        
        const snapshot = await bookingsRef.get();
        let protectedCount = 0;
        
        for (const doc of snapshot.docs) {
            const booking = doc.data();
            const bookingDate = booking.date;
            const timeSlots = booking.timeSlots || [];
            
            let isStillValid = false;
            
            // ตรวจสอบว่าการจองยังไม่หมดเวลาจริงๆ
            if (bookingDate > currentDate) {
                // การจองในอนาคต
                isStillValid = true;
            } else if (bookingDate === currentDate && timeSlots.length > 0) {
                // การจองวันนี้ - เช็คเวลา
                try {
                    const latestEndTime = Math.max(...timeSlots.map(slot => {
                        const [startStr, endStr] = slot.split('-');
                        const [endHour, endMin] = endStr.split(':').map(Number);
                        return endHour * 60 + endMin;
                    }));
                    
                    // ให้ grace period ตามการตั้งค่า (นาที) หลังจบเวลาจอง
                        const { getNumericSetting } = require('./src/services/settings.service');
                        const grace = await getNumericSetting('checkin_grace_minutes', 15);
                        if (currentTime <= latestEndTime + Number(grace)) {
                        isStillValid = true;
                    }
                } catch (error) {
                    // ถ้าไม่สามารถ parse เวลาได้ ให้ถือว่ายังไม่หมดเวลา
                    isStillValid = true;
                }
            }
            
            if (isStillValid) {
                // อัปเดตเวลาแก้ไขล่าสุดเพื่อป้องกันการลดคะแนน
                await doc.ref.update({
                    serverStartupProtection: true,
                    lastProtectionUpdate: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                
                protectedCount++;
                console.log(`✅ Protected booking ${doc.id} - ${booking.courtName} on ${booking.date}`);
            }
        }
        
        console.log(`🛡️ Protected ${protectedCount} bookings from incorrect penalties`);
        console.log('✅ Penalty protection activated successfully');
        
    } catch (error) {
        console.error('❌ Error activating penalty protection:', error);
    }
}

// เพิ่มระบบตรวจสอบก่อนลดคะแนน
async function isBookingActuallyExpired(booking) {
    const now = new Date();
    const currentDate = now.toISOString().split('T')[0];
    const currentTime = now.getHours() * 60 + now.getMinutes();
    
    const bookingDate = booking.date;
    const timeSlots = booking.timeSlots || [];
    
    // ตรวจสอบการป้องกันเมื่อเริ่มเซิร์ฟเวอร์
    if (booking.serverStartupProtection) {
        const protectionTime = booking.lastProtectionUpdate;
        if (protectionTime) {
            const protectionDate = protectionTime.toDate();
            const timeSinceProtection = now.getTime() - protectionDate.getTime();
            
            // ถ้าป้องกันไว้ไม่เกิน 30 นาที ให้พิจารณาอีกครั้ง
            if (timeSinceProtection < 30 * 60 * 1000) {
                console.log(`⚠️ Booking ${booking.id} is under startup protection`);
                return false;
            }
        }
    }
    
    // ตรวจสอบตามเวลาจริง
    if (bookingDate < currentDate) {
        return true; // หมดเวลาแล้ว
    }
    
    if (bookingDate === currentDate && timeSlots.length > 0) {
        try {
            const latestEndTime = Math.max(...timeSlots.map(slot => {
                const [startStr, endStr] = slot.split('-');
                const [endHour, endMin] = endStr.split(':').map(Number);
                return endHour * 60 + endMin;
            }));
            
            // ให้ grace period 10 นาที
            return currentTime > (latestEndTime + 10);
        } catch (error) {
            console.log(`Error parsing time slots: ${error.message}`);
            return false; // ถ้าไม่สามารถ parse ได้ ให้ถือว่ายังไม่หมดเวลา
        }
    }
    
    return false;
}

module.exports = {
    preventServerStartupPenalties,
    isBookingActuallyExpired
};
