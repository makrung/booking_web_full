const express = require('express');
const router = express.Router();
const admin = require('../../config/firebase');

// Public: get content by key
// GET /api/content/:key -> { success, key, value, updatedAt }
router.get('/content/:key', async (req, res) => {
  try {
    const { key } = req.params;
    if (!key) return res.status(400).json({ success: false, error: 'missing key' });
    const db = admin.firestore();
    const doc = await db.collection('settings').doc(key).get();
    if (!doc.exists) {
      return res.json({ success: true, key, value: null, updatedAt: null });
    }
    const data = doc.data();
    res.json({ success: true, key, value: data.value ?? null, updatedAt: data.updatedAt ?? null });
  } catch (e) {
    console.error('Content get error:', e);
    res.status(500).json({ success: false, error: 'internal error' });
  }
});

module.exports = router;