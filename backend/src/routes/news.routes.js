const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const admin = require('../../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Ensure uploads directory exists
const uploadDir = path.join(__dirname, '../../public/uploads/news');
fs.mkdirSync(uploadDir, { recursive: true });

// Multer storage for images/videos
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const ext = path.extname(file.originalname);
    const base = path.basename(file.originalname, ext).replace(/[^a-zA-Z0-9-_]/g, '_');
    const unique = Date.now() + '_' + Math.random().toString(36).substring(2, 8);
    cb(null, base + '_' + unique + ext);
  },
});

const fileFilter = (req, file, cb) => {
  const allowed = ['image/', 'video/'];
  if (allowed.some((p) => file.mimetype.startsWith(p))) {
    cb(null, true);
  } else {
    cb(new Error('Invalid file type'));
  }
};

const upload = multer({ storage, fileFilter, limits: { fileSize: 20 * 1024 * 1024 } }); // 20MB

// Admin check (reuse similar pattern from other admin routes)
const requireAdmin = async (req, res, next) => {
  try {
    if (!req.user || !req.user.id) {
      return res.status(401).json({ error: 'ข้อมูลการยืนยันตัวตนไม่ถูกต้อง', requireAuth: true });
    }
    // system admin bypass
    if (req.user.id === 'admin' && req.user.type === 'system_admin' && req.user.isAdmin === true) {
      return next();
    }
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(req.user.id).get();
    if (!userDoc.exists) return res.status(404).json({ error: 'ไม่พบผู้ใช้' });
    const userData = userDoc.data();
    if (userData.role !== 'admin') return res.status(403).json({ error: 'คุณไม่มีสิทธิ์เข้าถึงหน้านี้' });
    next();
  } catch (err) {
    console.error('Admin check error (news):', err);
    res.status(500).json({ error: 'เกิดข้อผิดพลาดในการตรวจสอบสิทธิ์' });
  }
};

// Helper: serialize Firestore doc data (convert Timestamp -> ISO string)
function serializeNewsDoc(doc) {
  const data = doc.data() || {};
  const convertTs = (v) => {
    if (!v) return null;
    if (typeof v.toDate === 'function') return v.toDate().toISOString();
    if (typeof v === 'string') return v; // in case already string
    return null;
  };
  // Fallback to document metadata times if fields missing
  const createdAt = convertTs(data.createdAt) || convertTs(doc.createTime);
  const updatedAt = convertTs(data.updatedAt) || convertTs(doc.updateTime) || createdAt;
  return {
    id: doc.id,
    title: data.title || '',
    contentHtml: data.contentHtml || '',
    contentText: data.contentText || '',
    media: Array.isArray(data.media) ? data.media : [],
    contentDelta: Array.isArray(data.contentDelta) ? data.contentDelta : undefined,
    createdAt,
    updatedAt,
    authorId: data.authorId || null,
  };
}

// Upload media (images/videos)
router.post('/admin/news/upload', authenticateToken, requireAdmin, upload.array('media', 5), async (req, res) => {
  try {
    const files = req.files || [];
    const urls = files.map((f) => ({
      url: `/uploads/news/${f.filename}`,
      type: f.mimetype.startsWith('image/') ? 'image' : 'video',
      name: f.originalname,
      size: f.size,
    }));
    res.json({ success: true, files: urls });
  } catch (err) {
    console.error('Upload error:', err);
    res.status(500).json({ success: false, error: 'อัปโหลดไฟล์ไม่สำเร็จ' });
  }
});

// Create news post
router.post('/admin/news', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { title, contentHtml, contentText, media = [], contentDelta } = req.body;
    if (!title || !(contentHtml || contentText)) {
      return res.status(400).json({ success: false, error: 'กรุณาระบุหัวข้อและเนื้อหา' });
    }
    const db = admin.firestore();
    const docRef = db.collection('news').doc();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const data = {
      id: docRef.id,
      title: String(title),
      contentHtml: contentHtml || '',
      contentText: contentText || '',
      media: Array.isArray(media) ? media : [],
      // Persist Quill Delta JSON for rich formatting (colors, sizes, highlights)
      contentDelta: Array.isArray(contentDelta) ? contentDelta : undefined,
      createdAt: now,
      updatedAt: now,
      authorId: req.user.id || null,
    };
    await docRef.set(data);
    const saved = await docRef.get();
    res.status(201).json({ success: true, data: serializeNewsDoc(saved) });
  } catch (err) {
    console.error('Create news error:', err);
    res.status(500).json({ success: false, error: 'ไม่สามารถสร้างข่าวสารได้' });
  }
});

// Update news post
router.put('/admin/news/:id', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, contentHtml, contentText, media, contentDelta } = req.body;
    const db = admin.firestore();
    const ref = db.collection('news').doc(id);
    const snap = await ref.get();
    if (!snap.exists) return res.status(404).json({ success: false, error: 'ไม่พบข่าวสาร' });

    const update = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    if (title !== undefined) update.title = String(title);
    if (contentHtml !== undefined) update.contentHtml = String(contentHtml);
    if (contentText !== undefined) update.contentText = String(contentText);
  if (media !== undefined) update.media = Array.isArray(media) ? media : [];
  if (contentDelta !== undefined) update.contentDelta = Array.isArray(contentDelta) ? contentDelta : undefined;

    await ref.update(update);
    const updated = await ref.get();
    res.json({ success: true, data: serializeNewsDoc(updated) });
  } catch (err) {
    console.error('Update news error:', err);
    res.status(500).json({ success: false, error: 'ไม่สามารถแก้ไขข่าวสารได้' });
  }
});

// Delete news post
router.delete('/admin/news/:id', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const db = admin.firestore();
    const ref = db.collection('news').doc(id);
    const snap = await ref.get();
    if (!snap.exists) return res.status(404).json({ success: false, error: 'ไม่พบข่าวสาร' });
    const data = snap.data();
    await ref.delete();
    res.json({ success: true, deleted: { id, ...data } });
  } catch (err) {
    console.error('Delete news error:', err);
    res.status(500).json({ success: false, error: 'ไม่สามารถลบข่าวสารได้' });
  }
});

// Public: list news
router.get('/news', async (req, res) => {
  try {
    const db = admin.firestore();
    let limit = parseInt(req.query.limit || '20', 10);
    if (isNaN(limit) || limit <= 0 || limit > 100) limit = 20;
    const snap = await db.collection('news').orderBy('createdAt', 'desc').limit(limit).get();
    const items = snap.docs.map((d) => serializeNewsDoc(d));
    res.json({ success: true, data: items });
  } catch (err) {
    console.error('List news error:', err);
    res.status(500).json({ success: false, error: 'ไม่สามารถดึงข่าวสารได้' });
  }
});

// Public: latest news
router.get('/news/latest', async (req, res) => {
  try {
    const db = admin.firestore();
    const snap = await db.collection('news').orderBy('createdAt', 'desc').limit(1).get();
    if (snap.empty) return res.json({ success: true, data: null });
    const d = snap.docs[0];
    res.json({ success: true, data: serializeNewsDoc(d) });
  } catch (err) {
    console.error('Latest news error:', err);
    res.status(500).json({ success: false, error: 'ไม่สามารถดึงข่าวสารล่าสุดได้' });
  }
});

// Public: get by id
router.get('/news/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const db = admin.firestore();
    const snap = await db.collection('news').doc(id).get();
    if (!snap.exists) return res.status(404).json({ success: false, error: 'ไม่พบข่าวสาร' });
    res.json({ success: true, data: serializeNewsDoc(snap) });
  } catch (err) {
    console.error('Get news error:', err);
    res.status(500).json({ success: false, error: 'ไม่สามารถดึงข่าวสารได้' });
  }
});

module.exports = router;
