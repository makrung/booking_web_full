const express = require('express');
const router = express.Router();
const admin = require('../../config/firebase');
const { authenticateToken } = require('../middleware/auth');

// Helpers
const incrementsAllowed = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

// Create a point request (user)
router.post('/points/requests', authenticateToken, async (req, res) => {
    try {
        const { requestedPoints, reason } = req.body || {};
        if (!incrementsAllowed.includes(Number(requestedPoints))) {
            return res.status(400).json({ success: false, error: 'จำนวนคะแนนที่ขอไม่ถูกต้อง' });
        }

        const db = admin.firestore();
        // Check user block and daily limit
        const userRef = db.collection('users').doc(req.user.userId);
        const userDoc = await userRef.get();
        if (userDoc.exists) {
            const u = userDoc.data();
            if (u.isRequestBlocked) {
                return res.status(403).json({ success: false, error: 'บัญชีของคุณถูกบล็อคการส่งคำขอ' });
            }
        }

        // Daily limit: max 5 requests/day
        const today = new Date();
        const y = today.getFullYear();
        const m = String(today.getMonth() + 1).padStart(2, '0');
        const d = String(today.getDate()).padStart(2, '0');
        const dayKey = `${y}-${m}-${d}`;
        let todayCount = 0;
        try {
            const snap = await db.collection('pointRequests')
                .where('userId', '==', req.user.userId)
                .get();
            snap.forEach(doc => {
                const rd = doc.data().createdAt;
                let key = '';
                if (rd && typeof rd.toDate === 'function') key = rd.toDate().toISOString().split('T')[0];
                else if (typeof rd === 'string') key = (rd.includes('T') ? new Date(rd).toISOString().split('T')[0] : rd);
                if (key === dayKey) todayCount++;
            });
        } catch (e) {
            console.warn('Daily limit check fallback for points requests', e?.message || e);
        }
        if (todayCount >= 5) {
            return res.status(429).json({ success: false, error: 'วันนี้คุณส่งคำขอครบ 5 ครั้งแล้ว' });
        }
        const data = {
            userId: req.user.userId,
            requestedPoints: Number(requestedPoints),
            reason: (reason || '').toString(),
            status: 'pending', // pending | approved | denied
            adminRead: false, // unread for admin until viewed
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        const docRef = await db.collection('pointRequests').add(data);

        // Notify admin inbox (global admin channel) unless messagesBlocked
        try {
            let allowAdminMsg = true;
            try {
                const uDoc = await db.collection('users').doc(req.user.userId).get();
                if (uDoc.exists && uDoc.data().isMessagesBlocked) allowAdminMsg = false;
            } catch {}
            // Try to enrich with user display name
            let requesterName = '';
            const uDoc = await db.collection('users').doc(req.user.userId).get();
            if (uDoc.exists) {
                const u = uDoc.data();
                requesterName = `${u.firstName || ''} ${u.lastName || ''}`.trim();
            }
            if (allowAdminMsg) {
                await db.collection('messages').add({
                    userId: 'admin', // special channel for all admins
                    type: 'admin_notice',
                    title: 'มีคำขอเพิ่มคะแนนใหม่',
                    body: `${requesterName || req.user.userId} ขอเพิ่มคะแนน ${Number(requestedPoints)} คะแนน`,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    read: false,
                });
            }
        } catch (e) {
            console.warn('Failed to create admin notice message:', e);
        }

        // Acknowledge to requester in their inbox
        try {
            await db.collection('messages').add({
                userId: req.user.userId,
                type: 'points_request',
                title: 'รับคำขอเพิ่มคะแนนแล้ว',
                body: `ระบบได้รับคำขอเพิ่มคะแนนของคุณ (${Number(requestedPoints)} คะแนน) แล้ว กำลังรอดำเนินการ`,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                read: false,
            });
        } catch (e) {
            console.warn('Failed to create user acknowledgment message:', e);
        }

        res.status(201).json({ success: true, requestId: docRef.id, message: 'ส่งคำขอเพิ่มคะแนนแล้ว' });
    } catch (err) {
        console.error('Create point request error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการส่งคำขอ' });
    }
});

// List my point requests (user)
router.get('/points/requests', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const snap = await db.collection('pointRequests')
            .where('userId', '==', req.user.userId)
            .get();
        const items = [];
        snap.forEach(doc => {
            const d = doc.data();
            items.push({ id: doc.id, ...d, createdAt: d.createdAt?.toDate?.().toISOString?.() || null });
        });
        // sort client-side desc
        items.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
        res.json({ success: true, requests: items });
    } catch (err) {
        console.error('List my point requests error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการดึงคำขอ' });
    }
});

// Admin: list all point requests
router.get('/admin/points/requests', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        // verify admin
        const uDoc = await db.collection('users').doc(req.user.userId).get();
        if (!uDoc.exists || (uDoc.data().role !== 'admin' && !(req.user.id === 'admin' && req.user.isAdmin))) {
            return res.status(403).json({ success: false, error: 'forbidden' });
        }

        const snap = await db.collection('pointRequests').orderBy('createdAt', 'desc').get();
        const items = [];
        for (const doc of snap.docs) {
            const d = doc.data();
            let userName = '';
            let currentPoints = 0;
            let penaltiesCount = 0;
            let adminGivenCount = 0;
            try {
                const ud = await db.collection('users').doc(d.userId).get();
                if (ud.exists) {
                    const u = ud.data();
                    userName = `${u.firstName} ${u.lastName}`;
                    currentPoints = Number(u.points || 0);
                }
                // count penalties for this user
                const penSnap = await db.collection('penalties').where('userId', '==', d.userId).get();
                penaltiesCount = penSnap.size;
                // count admin-approved requests for this user
                const apprSnap = await db.collection('pointRequests')
                    .where('userId', '==', d.userId)
                    .where('status', '==', 'approved').get();
                adminGivenCount = apprSnap.size;
            } catch {}
            items.push({ id: doc.id, ...d, userName, currentPoints, penaltiesCount, adminGivenCount, createdAt: d.createdAt?.toDate?.().toISOString?.() || null });
        }
        res.json({ success: true, requests: items });
    } catch (err) {
        console.error('Admin list point requests error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการดึงคำขอ' });
    }
});

// Admin: approve or deny request
router.post('/admin/points/requests/:id/decision', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const { decision, points, message } = req.body || {};
        const db = admin.firestore();

        // verify admin
        const uDoc = await db.collection('users').doc(req.user.userId).get();
        if (!uDoc.exists || (uDoc.data().role !== 'admin' && !(req.user.id === 'admin' && req.user.isAdmin))) {
            return res.status(403).json({ success: false, error: 'forbidden' });
        }

        const reqDoc = await db.collection('pointRequests').doc(id).get();
        if (!reqDoc.exists) return res.status(404).json({ success: false, error: 'ไม่พบคำขอ' });
        const reqData = reqDoc.data();
        if (reqData.status !== 'pending') {
            return res.status(400).json({ success: false, error: 'คำขอถูกดำเนินการแล้ว' });
        }

        if (decision === 'deny') {
            await reqDoc.ref.update({ status: 'denied', adminMessage: (message || '').toString(), decidedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
            // send inbox message
            await db.collection('messages').add({
                userId: reqData.userId,
                type: 'points_request',
                title: 'คำขอเพิ่มคะแนนถูกปฏิเสธ',
                body: (message || 'คำขอของคุณถูกปฏิเสธ').toString(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                read: false,
            });
            return res.json({ success: true, message: 'ปฏิเสธคำขอแล้ว' });
        }

        // approve
        const inc = Number(points);
        if (!incrementsAllowed.includes(inc)) {
            return res.status(400).json({ success: false, error: 'จำนวนคะแนนไม่ถูกต้อง' });
        }

        // increment user points
        const userRef = db.collection('users').doc(reqData.userId);
        await db.runTransaction(async (tx) => {
            const snap = await tx.get(userRef);
            if (!snap.exists) throw new Error('user not found');
            const current = snap.data().points || 0;
            tx.update(userRef, { points: current + inc, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        });

        await reqDoc.ref.update({ status: 'approved', approvedPoints: inc, adminMessage: (message || '').toString(), decidedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });

        // send inbox message
        await db.collection('messages').add({
            userId: reqData.userId,
            type: 'points_request',
            title: 'คำขอเพิ่มคะแนนได้รับการอนุมัติ',
            body: (message || `ระบบได้เพิ่มคะแนนให้คุณ ${inc} คะแนน`).toString(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
        });

        res.json({ success: true, message: 'อนุมัติและเพิ่มคะแนนแล้ว' });
    } catch (err) {
        console.error('Admin decision error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการดำเนินการ' });
    }
});

// Admin: change status of a point request (support revoke approval, set pending, re-approve)
// PATCH /api/admin/points/requests/:id/status { status: 'pending'|'approved'|'denied', points?, message? }
router.patch('/admin/points/requests/:id/status', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const { status, points, message } = req.body || {};
        const target = String(status || '').toLowerCase();
        if (!['pending', 'approved', 'denied'].includes(target)) {
            return res.status(400).json({ success: false, error: 'สถานะไม่ถูกต้อง' });
        }
        const db = admin.firestore();
        // verify admin
        const uDoc = await db.collection('users').doc(req.user.userId).get();
        if (!uDoc.exists || (uDoc.data().role !== 'admin' && !(req.user.id === 'admin' && req.user.isAdmin))) {
            return res.status(403).json({ success: false, error: 'forbidden' });
        }

        const ref = db.collection('pointRequests').doc(id);
        const snap = await ref.get();
        if (!snap.exists) return res.status(404).json({ success: false, error: 'ไม่พบคำขอ' });
        const data = snap.data();
        const currentStatus = String(data.status || 'pending').toLowerCase();
        const userId = data.userId;

        // Helper to send inbox message
        async function sendMessage(title, body) {
            try {
                await db.collection('messages').add({
                    userId,
                    type: 'points_request',
                    title,
                    body: String(body || ''),
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    read: false,
                });
            } catch (e) { /* ignore */ }
        }

        // Transition handling
        if (currentStatus === 'approved') {
            // If already approved, moving to pending or denied must revoke points first
            if (target === 'pending' || target === 'denied') {
                const dec = Number(data.approvedPoints || 0);
                // adjust user points atomically
                const userRef = db.collection('users').doc(userId);
                await db.runTransaction(async (tx) => {
                    const us = await tx.get(userRef);
                    if (!us.exists) throw new Error('user not found');
                    const cur = Number(us.data().points || 0);
                    const next = Math.max(0, cur - Math.max(0, dec));
                    tx.update(userRef, { points: next, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                });
                const updates = {
                    status: target,
                    approvedPoints: null,
                    adminMessage: (message || data.adminMessage || '').toString(),
                    revokedAt: admin.firestore.FieldValue.serverTimestamp(),
                    revokedBy: req.user.userId,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                };
                if (target === 'pending') {
                    updates.decidedAt = null;
                } else {
                    updates.decidedAt = admin.firestore.FieldValue.serverTimestamp();
                }
                await ref.update(updates);
                await sendMessage(
                    target === 'pending' ? 'ยกเลิกการอนุมัติคำขอคะแนน' : 'ยกเลิกการอนุมัติและปฏิเสธคำขอ',
                    target === 'pending'
                        ? 'ระบบได้ยกเลิกการอนุมัติคำขอคะแนนของคุณ และดำเนินการใหม่'
                        : 'คำขอคะแนนเดิมถูกยกเลิกการอนุมัติและเปลี่ยนเป็นปฏิเสธ'
                );
                return res.json({ success: true, message: target === 'pending' ? 'ยกเลิกการอนุมัติและตั้งเป็นรอดำเนินการแล้ว' : 'ยกเลิกการอนุมัติและปฏิเสธแล้ว' });
            }

            if (target === 'approved') {
                // allow adjusting approved points difference
                const newInc = Number(points);
                if (!incrementsAllowed.includes(newInc)) return res.status(400).json({ success: false, error: 'จำนวนคะแนนไม่ถูกต้อง' });
                const oldInc = Number(data.approvedPoints || 0);
                const delta = newInc - oldInc;
                if (delta !== 0) {
                    const userRef = db.collection('users').doc(userId);
                    await db.runTransaction(async (tx) => {
                        const us = await tx.get(userRef);
                        if (!us.exists) throw new Error('user not found');
                        const cur = Number(us.data().points || 0);
                        const next = Math.max(0, cur + delta);
                        tx.update(userRef, { points: next, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                    });
                }
                await ref.update({ approvedPoints: newInc, adminMessage: (message || data.adminMessage || '').toString(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                return res.json({ success: true, message: 'ปรับจำนวนคะแนนที่อนุมัติแล้ว' });
            }
        }

        if (currentStatus === 'denied') {
            if (target === 'pending') {
                await ref.update({ status: 'pending', decidedAt: null, adminMessage: (message || data.adminMessage || '').toString(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                await sendMessage('เปลี่ยนสถานะคำขอคะแนน', 'ระบบได้เปลี่ยนคำขอคะแนนของคุณให้รอดำเนินการใหม่');
                return res.json({ success: true, message: 'ตั้งเป็นรอดำเนินการแล้ว' });
            }
            if (target === 'approved') {
                const inc = Number(points || data.requestedPoints || 0);
                if (!incrementsAllowed.includes(inc)) return res.status(400).json({ success: false, error: 'จำนวนคะแนนไม่ถูกต้อง' });
                const userRef = db.collection('users').doc(userId);
                await db.runTransaction(async (tx) => {
                    const us = await tx.get(userRef);
                    if (!us.exists) throw new Error('user not found');
                    const cur = Number(us.data().points || 0);
                    tx.update(userRef, { points: cur + inc, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                });
                await ref.update({ status: 'approved', approvedPoints: inc, adminMessage: (message || '').toString(), decidedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                await sendMessage('คำขอเพิ่มคะแนนได้รับการอนุมัติ', `ระบบได้เพิ่มคะแนนให้คุณ ${inc} คะแนน`);
                return res.json({ success: true, message: 'อนุมัติและเพิ่มคะแนนแล้ว' });
            }
        }

        // currentStatus: pending
        if (currentStatus === 'pending') {
            if (target === 'approved') {
                const inc = Number(points || data.requestedPoints || 0);
                if (!incrementsAllowed.includes(inc)) return res.status(400).json({ success: false, error: 'จำนวนคะแนนไม่ถูกต้อง' });
                const userRef = db.collection('users').doc(userId);
                await db.runTransaction(async (tx) => {
                    const us = await tx.get(userRef);
                    if (!us.exists) throw new Error('user not found');
                    const cur = Number(us.data().points || 0);
                    tx.update(userRef, { points: cur + inc, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                });
                await ref.update({ status: 'approved', approvedPoints: inc, adminMessage: (message || '').toString(), decidedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                await sendMessage('คำขอเพิ่มคะแนนได้รับการอนุมัติ', `ระบบได้เพิ่มคะแนนให้คุณ ${inc} คะแนน`);
                return res.json({ success: true, message: 'อนุมัติและเพิ่มคะแนนแล้ว' });
            }
            if (target === 'denied') {
                await ref.update({ status: 'denied', adminMessage: (message || '').toString(), decidedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                await sendMessage('คำขอเพิ่มคะแนนถูกปฏิเสธ', (message || 'คำขอของคุณถูกปฏิเสธ').toString());
                return res.json({ success: true, message: 'ปฏิเสธคำขอแล้ว' });
            }
            // pending->pending no-op
            return res.json({ success: true, message: 'ไม่มีการเปลี่ยนแปลง' });
        }

        // Fallback (no matching transition)
        return res.status(400).json({ success: false, error: 'ไม่รองรับการเปลี่ยนแปลงสถานะนี้' });
    } catch (err) {
        console.error('Admin change status error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการเปลี่ยนสถานะ' });
    }
});

// Admin: requests stats (pending/unread counts)
router.get('/admin/points/requests/stats', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        // verify admin
        const uDoc = await db.collection('users').doc(req.user.userId).get();
        if (!uDoc.exists || (uDoc.data().role !== 'admin' && !(req.user.id === 'admin' && req.user.isAdmin))) {
            return res.status(403).json({ success: false, error: 'forbidden' });
        }
        const pendingSnap = await db.collection('pointRequests').where('status', '==', 'pending').get();
        let unread = 0;
        pendingSnap.forEach(doc => { if (!doc.data().adminRead) unread++; });
        res.json({ success: true, pending: pendingSnap.size, unreadPending: unread });
    } catch (err) {
        console.error('Admin requests stats error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการดึงสถิติ' });
    }
});

// Admin: mark all pending point requests as read
router.post('/admin/points/requests/mark-read', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        // verify admin
        const uDoc = await db.collection('users').doc(req.user.userId).get();
        if (!uDoc.exists || (uDoc.data().role !== 'admin' && !(req.user.id === 'admin' && req.user.isAdmin))) {
            return res.status(403).json({ success: false, error: 'forbidden' });
        }
        const snap = await db.collection('pointRequests').where('status', '==', 'pending').where('adminRead', '==', false).get();
        const batch = db.batch();
        snap.forEach(doc => batch.update(doc.ref, { adminRead: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() }));
        await batch.commit();
        res.json({ success: true, marked: snap.size });
    } catch (err) {
        console.error('Admin mark-read error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการอัปเดตสถานะอ่าน' });
    }
});

// User inbox messages
router.get('/messages', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        // Determine admin role
        let isAdmin = false;
        try {
            const uDoc = await db.collection('users').doc(req.user.userId).get();
            if (uDoc.exists && uDoc.data().role === 'admin') isAdmin = true;
            if (!isAdmin && req.user && req.user.id === 'admin' && req.user.isAdmin) isAdmin = true;
        } catch {}

        const items = [];

        // Helper to load messages for one userId with index-aware fallback
        const loadForUser = async (userId) => {
            try {
                const snap = await db.collection('messages')
                    .where('userId', '==', userId)
                    .orderBy('createdAt', 'desc')
                    .get();
                snap.forEach(doc => {
                    const d = doc.data();
                    items.push({ id: doc.id, ...d, createdAt: d.createdAt?.toDate?.().toISOString?.() || null });
                });
            } catch (e) {
                console.warn('Messages query missing index for userId=%s, fallback without orderBy', userId);
                const snap = await db.collection('messages')
                    .where('userId', '==', userId)
                    .get();
                snap.forEach(doc => {
                    const d = doc.data();
                    items.push({ id: doc.id, ...d, createdAt: d.createdAt?.toDate?.().toISOString?.() || null });
                });
            }
        };

        // Always load personal inbox
        await loadForUser(req.user.userId);
        // For admins, also load global admin channel
        if (isAdmin) {
            await loadForUser('admin');
        }

        // Sort combined list
        items.sort((a, b) => {
            const ta = a.createdAt ? Date.parse(a.createdAt) : 0;
            const tb = b.createdAt ? Date.parse(b.createdAt) : 0;
            return tb - ta;
        });

        res.json({ success: true, messages: items });
    } catch (err) {
        console.error('Get messages error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการดึงข้อความ' });
    }
});

// Mark message as read
router.post('/messages/:id/read', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const db = admin.firestore();
        const msgRef = db.collection('messages').doc(id);
        const msgDoc = await msgRef.get();
        if (!msgDoc.exists) return res.status(404).json({ success: false, error: 'ไม่พบข้อความ' });
        const msgUserId = msgDoc.data().userId;
        let isAdmin = false;
        try {
            const uDoc = await db.collection('users').doc(req.user.userId).get();
            if (uDoc.exists && uDoc.data().role === 'admin') isAdmin = true;
            if (!isAdmin && req.user && req.user.id === 'admin' && req.user.isAdmin) isAdmin = true;
        } catch {}
        if (msgUserId !== req.user.userId && !(msgUserId === 'admin' && isAdmin)) {
            return res.status(403).json({ success: false, error: 'forbidden' });
        }
        await msgRef.update({ read: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        res.json({ success: true });
    } catch (err) {
        console.error('Mark message read error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการอัปเดตข้อความ' });
    }
});

// Unread messages count for badges
router.get('/messages/unread-count', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        let isAdmin = false;
        try {
            const uDoc = await db.collection('users').doc(req.user.userId).get();
            if (uDoc.exists && uDoc.data().role === 'admin') isAdmin = true;
            if (!isAdmin && req.user && req.user.id === 'admin' && req.user.isAdmin) isAdmin = true;
        } catch {}

        let count = 0;
        // Personal unread with fallback
        try {
            const personalSnap = await db.collection('messages')
                .where('userId', '==', req.user.userId)
                .where('read', '==', false)
                .get();
            count += personalSnap.size;
        } catch (e) {
            console.warn('Unread count query missing index for personal messages, fallback to in-memory count');
            const snap = await db.collection('messages')
                .where('userId', '==', req.user.userId)
                .get();
            snap.forEach(doc => { if (doc.data().read !== true) count++; });
        }
        if (isAdmin) {
            try {
                const adminSnap = await db.collection('messages')
                    .where('userId', '==', 'admin')
                    .where('read', '==', false)
                    .get();
                count += adminSnap.size;
            } catch (e) {
                console.warn('Unread count query missing index for admin messages, fallback to in-memory count');
                const snap = await db.collection('messages')
                    .where('userId', '==', 'admin')
                    .get();
                snap.forEach(doc => { if (doc.data().read !== true) count++; });
            }
        }
        res.json({ success: true, unread: count });
    } catch (err) {
        console.error('Unread messages count error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการดึงจำนวนข้อความที่ยังไม่อ่าน' });
    }
});

// Mark all messages as read for current user (and admin channel if admin)
router.post('/messages/mark-all-read', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        let isAdmin = false;
        try {
            const uDoc = await db.collection('users').doc(req.user.userId).get();
            if (uDoc.exists && uDoc.data().role === 'admin') isAdmin = true;
            if (!isAdmin && req.user && req.user.id === 'admin' && req.user.isAdmin) isAdmin = true;
        } catch {}

        const batch = db.batch();
        let marked = 0;

        // Helper to mark all unread for given userId
        const markFor = async (userId) => {
            try {
                // Prefer index path
                const snap = await db.collection('messages')
                    .where('userId', '==', userId)
                    .where('read', '==', false)
                    .get();
                snap.forEach(doc => {
                    batch.update(doc.ref, { read: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                    marked++;
                });
            } catch (e) {
                // Fallback without composite index
                console.warn('Mark-all-read missing index for userId=%s, fallback in-memory filter', userId);
                const snap = await db.collection('messages')
                    .where('userId', '==', userId)
                    .get();
                snap.forEach(doc => {
                    const d = doc.data();
                    if (d.read !== true) {
                        batch.update(doc.ref, { read: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                        marked++;
                    }
                });
            }
        };

        await markFor(req.user.userId);
        if (isAdmin) {
            await markFor('admin');
        }

        if (marked > 0) await batch.commit();
        res.json({ success: true, marked });
    } catch (err) {
        console.error('Mark all messages read error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการอัปเดตข้อความทั้งหมด' });
    }
});

// Admin: edit a point request (only when pending)
router.patch('/admin/points/requests/:id', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const { id } = req.params;
        const { requestedPoints, reason } = req.body || {};
        // verify admin
        const uDoc = await db.collection('users').doc(req.user.userId).get();
        if (!uDoc.exists || (uDoc.data().role !== 'admin' && !(req.user.id === 'admin' && req.user.isAdmin))) {
            return res.status(403).json({ success: false, error: 'forbidden' });
        }
        const ref = db.collection('pointRequests').doc(id);
        const snap = await ref.get();
        if (!snap.exists) return res.status(404).json({ success: false, error: 'ไม่พบคำขอ' });
        const data = snap.data();
        if (data.status !== 'pending') return res.status(400).json({ success: false, error: 'แก้ไขได้เฉพาะคำขอที่รอดำเนินการ' });
        const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
        if (typeof requestedPoints !== 'undefined') {
            const n = Number(requestedPoints);
            if (!incrementsAllowed.includes(n)) return res.status(400).json({ success: false, error: 'จำนวนคะแนนไม่ถูกต้อง' });
            updates.requestedPoints = n;
        }
        if (typeof reason !== 'undefined') updates.reason = String(reason);
        await ref.update(updates);
        return res.json({ success: true, message: 'แก้ไขคำขอสำเร็จ' });
    } catch (err) {
        console.error('Admin edit point request error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการแก้ไขคำขอ' });
    }
});

// Admin: delete a point request (any status)
router.delete('/admin/points/requests/:id', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const { id } = req.params;
        // verify admin
        const uDoc = await db.collection('users').doc(req.user.userId).get();
        if (!uDoc.exists || (uDoc.data().role !== 'admin' && !(req.user.id === 'admin' && req.user.isAdmin))) {
            return res.status(403).json({ success: false, error: 'forbidden' });
        }
        const ref = db.collection('pointRequests').doc(id);
        const snap = await ref.get();
        if (!snap.exists) return res.status(404).json({ success: false, error: 'ไม่พบคำขอ' });
        await ref.delete();
        return res.json({ success: true, message: 'ลบคำขอสำเร็จ' });
    } catch (err) {
        console.error('Admin delete point request error:', err);
        res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการลบคำขอ' });
    }
});

module.exports = router;
