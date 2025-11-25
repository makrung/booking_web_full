const app = require('./app');
const { preventServerStartupPenalties } = require('./penalty-protection');
const { startBookingExpiryWatcher } = require('./src/services/booking_expiry_service');
const PORT = process.env.PORT || 3000;

// เรียกใช้ระบบป้องกันการลดคะแนนผิดพลาดเมื่อเริ่มเซิร์ฟเวอร์
preventServerStartupPenalties();

app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`🛡️ Penalty protection system activated`);
    // Start periodic watcher for missed check-ins (runs every 60 seconds)
    startBookingExpiryWatcher({ intervalMs: 60 * 1000 });
});
