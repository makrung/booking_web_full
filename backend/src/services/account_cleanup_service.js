const admin = require('../../config/firebase');

function startAccountCleanupWatcher({ intervalMs = 5 * 60 * 1000, cutoffMinutes = 15 } = {}) {
  const interval = Math.max(60 * 1000, intervalMs);
  const cutoffMs = Math.max(1 * 60 * 1000, cutoffMinutes * 60 * 1000);

  async function runOnce() {
    try {
      const db = admin.firestore();
      const now = Date.now();
      const thresholdDate = new Date(now - cutoffMs);

      const snapshot = await db
        .collection('users')
        .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(thresholdDate))
        .limit(200)
        .get();

      if (snapshot.empty) {
        return;
      }

      let deleted = 0;
      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        const data = doc.data() || {};
        if (data && data.isEmailVerified !== true) {
          batch.delete(doc.ref);
          deleted += 1;
        }
      });

      if (deleted > 0) {
        await batch.commit();
        console.log(`🧹 Account cleanup: deleted ${deleted} unverified accounts older than ${Math.round(cutoffMs / 60000)}m`);
      }
    } catch (err) {
      console.error('Account cleanup error:', err);
    }
  }

  // initial delay a bit to avoid startup spikes
  setTimeout(runOnce, 30 * 1000);
  return setInterval(runOnce, interval);
}

module.exports = { startAccountCleanupWatcher };
