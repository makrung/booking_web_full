const app = require('./app');
const { preventServerStartupPenalties } = require('./penalty-protection');
const { startBookingExpiryWatcher } = require('./src/services/booking_expiry_service');
const { startAccountCleanupWatcher } = require('./src/services/account_cleanup_service');
const PORT = process.env.PORT || 3000;

// เรียกใช้ระบบป้องกันการลดคะแนนผิดพลาดเมื่อเริ่มเซิร์ฟเวอร์
preventServerStartupPenalties();

app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`🛡️ Penalty protection system activated`);
    // Start periodic watcher for missed check-ins (runs every 60 seconds)
    startBookingExpiryWatcher({ intervalMs: 60 * 1000 });
    // Start cleanup for unverified accounts older than 15 minutes (runs every 5 minutes)
    startAccountCleanupWatcher({ intervalMs: 5 * 60 * 1000, cutoffMinutes: 15 });
});
