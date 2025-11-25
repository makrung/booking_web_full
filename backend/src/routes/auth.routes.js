const express = require('express');
const router = express.Router();
const admin = require('../../config/firebase');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { authenticateToken } = require('../middleware/auth');
const { getBooleanSetting } = require('../services/settings.service');
const { 
    generateVerificationToken, 
    sendVerificationEmail, 
    sendWelcomeEmail,
    sendTokenExpiryReminder,
    sendPasswordResetEmail
} = require('../services/email.service');
require('dotenv').config();

// Helper: check if email is university domain
function isAllowedUniversityEmail(email) {
    if (!email || typeof email !== 'string') return false;
    const e = email.toLowerCase().trim();
    return e.endsWith('@silpakorn.edu') || e.endsWith('@su.ac.th');
}

// Helper: generate a short unique user code for booking group identification
function generateUserCode(length = 8) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // omit ambiguous chars
    let code = '';
    for (let i = 0; i < length; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}

// Helper: generate unique user code with collision check
async function generateUniqueUserCode(db, maxAttempts = 10) {
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
        const code = generateUserCode(8);
        
        // Check if code already exists
        const existing = await db.collection('users')
            .where('userCode', '==', code)
            .limit(1)
            .get();
        
        if (existing.empty) {
            return code; // Found unique code!
        }
        
        console.warn(`UserCode collision detected: ${code} (attempt ${attempt + 1}/${maxAttempts})`);
    }
    
    // Fallback: use timestamp + random if all attempts fail (very rare)
    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 6).toUpperCase();
    const fallbackCode = `${timestamp.slice(-4)}${random}`.substring(0, 8);
    console.error(`All userCode attempts exhausted, using fallback: ${fallbackCode}`);
    return fallbackCode;
}

// Register endpoint with email verification
router.post('/register', async (req, res) => {
    try {
        const { 
            firstName, 
            lastName, 
            studentId, 
            email, 
            phone, 
            password 
        } = req.body;

        // Validation
        if (!firstName || !lastName || !studentId || !email || !phone || !password) {
            return res.status(400).json({ 
                error: 'กรุณากรอกข้อมูลให้ครบถ้วน' 
            });
        }

        // Check email format (accept any valid email format)
        const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
        if (!emailRegex.test(email)) {
            return res.status(400).json({ 
                error: 'กรุณากรอกอีเมลที่ถูกต้อง' 
            });
        }

        // Enforce registration domain policy if disabled for non-university
        const allowNonUniRegistration = await getBooleanSetting('allow_non_university_registration', true);
        if (!allowNonUniRegistration && !isAllowedUniversityEmail(email)) {
            return res.status(403).json({
                error: 'สามารถสมัครได้ด้วยเมล @silpakorn.edu กับ @su.ac.th เท่านั้น'
            });
        }

        // Check phone number
        if (phone.length !== 10 || isNaN(phone)) {
            return res.status(400).json({ 
                error: 'กรุณากรอกเบอร์โทรศัพท์ที่ถูกต้อง (10 หลัก)' 
            });
        }

        // Password validation
        if (password.length < 6) {
            return res.status(400).json({ 
                error: 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร' 
            });
        }

        const db = admin.firestore();
        
        // Normalize email to lowercase for consistent storage
    const normalizedEmail = email.toLowerCase().trim();
        
        // Check if email already exists (case-insensitive)
        const existingUser = await db.collection('users')
            .where('email', '==', normalizedEmail)
            .get();
        
        if (!existingUser.empty) {
            return res.status(400).json({ 
                error: 'อีเมลนี้มีผู้ใช้งานแล้ว' 
            });
        }

        // Check student ID format (8-13 digits for student ID or national ID)
        if (!/^[0-9]{8,13}$/.test(studentId)) {
            return res.status(400).json({ 
                error: 'กรุณากรอกรหัสนักศึกษา (8-12 หลัก) หรือเลขบัตรประชาชน (13 หลัก)' 
            });
        }

        // Check if student ID already exists
        const existingStudentId = await db.collection('users')
            .where('studentId', '==', studentId)
            .get();
        
        if (!existingStudentId.empty) {
            return res.status(400).json({ 
                error: 'รหัสนักศึกษา/เลขบัตรประชาชนนี้มีผู้ใช้งานแล้ว' 
            });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);
        
        // Generate verification token
        const verificationToken = generateVerificationToken();
        const verificationExpiry = new Date();
        verificationExpiry.setHours(verificationExpiry.getHours() + 24); // 24 hours expiry

        // Determine user type based on student ID length
        const userType = studentId.length === 13 ? 'external' : 'student';

        // Create new user (inactive until email verification)
        // Assign a unique user code for group bookings (with collision check)
        const userCode = await generateUniqueUserCode(db);
        const userRef = await db.collection('users').add({
            firstName,
            lastName,
            studentId,
            email: normalizedEmail,
            phone,
            password: hashedPassword,
            role: 'user',
            userType: userType, // เพิ่ม userType
            points: 100, // คะแนนเริ่มต้น 100
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isActive: false, // Inactive until email verification
            isEmailVerified: false,
            emailVerificationToken: verificationToken,
            emailVerificationExpiry: verificationExpiry,
            userCode: userCode,
        });

        // Send verification email
        const emailResult = await sendVerificationEmail(
            normalizedEmail, 
            `${firstName} ${lastName}`, 
            verificationToken
        );

        if (!emailResult.success) {
            // If email sending fails, still create user but notify about the issue
            console.error('Failed to send verification email:', emailResult.message);
        }

        res.status(201).json({ 
            message: 'สมัครสมาชิกสำเร็จ! กรุณาตรวจสอบอีเมลเพื่อยืนยันบัญชีของคุณ',
            userId: userRef.id,
            userType: userType,
            emailSent: emailResult.success,
            userCode,
            note: 'คุณจะสามารถเข้าสู่ระบบได้หลังจากยืนยันอีเมลแล้ว'
        });

    } catch (error) {
        console.error('Register error:', error);
        res.status(500).json({ 
            error: 'เกิดข้อผิดพลาดในระบบ กรุณาลองใหม่อีกครั้ง' 
        });
    }
});

// Email verification endpoint
router.get('/verify-email/:token', async (req, res) => {
    try {
        const { token } = req.params;
        
        if (!token) {
            return res.status(400).json({ 
                error: 'ไม่พบโทเค็นการยืนยัน' 
            });
        }

        const db = admin.firestore();
        
        // Find user with verification token
        const userSnapshot = await db.collection('users')
            .where('emailVerificationToken', '==', token)
            .get();
        
        if (userSnapshot.empty) {
            return res.status(400).json({ 
                error: 'โทเค็นการยืนยันไม่ถูกต้องหรือหมดอายุแล้ว' 
            });
        }

        const userDoc = userSnapshot.docs[0];
        const userData = userDoc.data();

        // Check if token is expired
        const now = new Date();
        const expiryDate = userData.emailVerificationExpiry.toDate();
        
        if (now > expiryDate) {
            return res.status(400).json({ 
                error: 'โทเค็นการยืนยันหมดอายุแล้ว กรุณาขอโทเค็นใหม่',
                expired: true
            });
        }

        // Check if already verified
        if (userData.isEmailVerified) {
            return res.status(400).json({ 
                error: 'อีเมลนี้ได้รับการยืนยันแล้ว' 
            });
        }

        // Update user - verify email and activate account
        await userDoc.ref.update({
            isEmailVerified: true,
            isActive: true,
            emailVerificationToken: admin.firestore.FieldValue.delete(),
            emailVerificationExpiry: admin.firestore.FieldValue.delete(),
            emailVerifiedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Send welcome email
        await sendWelcomeEmail(userData.email, `${userData.firstName} ${userData.lastName}`);

        // Create HTML response that sets localStorage and redirects
        const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:8080';
        const htmlResponse = `
        <!DOCTYPE html>
        <html>
        <head>
            <title>อีเมลยืนยันสำเร็จ</title>
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: Arial, sans-serif;
                    background: linear-gradient(135deg, #1E3A8A, #3B82F6);
                    margin: 0;
                    padding: 20px;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: 100vh;
                }
                .container {
                    background: white;
                    padding: 40px;
                    border-radius: 20px;
                    box-shadow: 0 20px 40px rgba(0,0,0,0.1);
                    text-align: center;
                    max-width: 500px;
                }
                .success-icon {
                    width: 80px;
                    height: 80px;
                    background: #10B981;
                    border-radius: 50%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin: 0 auto 20px;
                    color: white;
                    font-size: 40px;
                }
                h1 {
                    color: #059669;
                    margin-bottom: 16px;
                }
                p {
                    color: #6B7280;
                    line-height: 1.6;
                    margin-bottom: 30px;
                }
                .redirect-info {
                    background: #F3F4F6;
                    padding: 20px;
                    border-radius: 10px;
                    margin-bottom: 20px;
                }
                .spinner {
                    border: 3px solid #f3f3f3;
                    border-top: 3px solid #059669;
                    border-radius: 50%;
                    width: 30px;
                    height: 30px;
                    animation: spin 1s linear infinite;
                    margin: 0 auto;
                }
                @keyframes spin {
                    0% { transform: rotate(0deg); }
                    100% { transform: rotate(360deg); }
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="success-icon">✓</div>
                <h1>ยืนยันอีเมลสำเร็จ!</h1>
                <p>คุณได้ยืนยันอีเมลเรียบร้อยแล้ว<br>ระบบกำลังนำคุณกลับไปยังหน้าเข้าสู่ระบบ</p>
                <div class="redirect-info">
                    <div class="spinner"></div>
                    <p style="margin-top: 10px; margin-bottom: 0;">กำลังโหลด...</p>
                </div>
            </div>
            
            <script>
                // Set flag ใน localStorage เพื่อให้หน้ารอการยืนยันตรวจสอบได้
                try {
                    localStorage.setItem('email_verified', 'true');
                    localStorage.setItem('verification_time', Date.now().toString());
                } catch (e) {
                    console.log('localStorage not available');
                }
                
                // Redirect หลังจาก 2 วินาที
                setTimeout(function() {
                    window.location.href = '${frontendUrl}/login?verified=true&timestamp=' + Date.now();
                }, 2000);
            </script>
        </body>
        </html>
        `;
        
        res.send(htmlResponse);

    } catch (error) {
        console.error('Email verification error:', error);
        res.status(500).json({ 
            error: 'เกิดข้อผิดพลาดในการยืนยันอีเมล' 
        });
    }
});

// Resend verification email
router.post('/resend-verification', async (req, res) => {
    try {
        const { email } = req.body;
        
        if (!email) {
            return res.status(400).json({ 
                error: 'กรุณาระบุอีเมล' 
            });
        }

        const db = admin.firestore();
        const normalizedEmail = email.toLowerCase().trim();
        
        // Find user
        const userSnapshot = await db.collection('users')
            .where('email', '==', normalizedEmail)
            .get();
        
        if (userSnapshot.empty) {
            return res.status(404).json({ 
                error: 'ไม่พบบัญชีผู้ใช้นี้' 
            });
        }

        const userDoc = userSnapshot.docs[0];
        const userData = userDoc.data();

        // Check if already verified
        if (userData.isEmailVerified) {
            return res.status(400).json({ 
                error: 'อีเมลนี้ได้รับการยืนยันแล้ว' 
            });
        }

        // Generate new verification token
        const verificationToken = generateVerificationToken();
        const verificationExpiry = new Date();
        verificationExpiry.setHours(verificationExpiry.getHours() + 24);

        // Update user with new token
        await userDoc.ref.update({
            emailVerificationToken: verificationToken,
            emailVerificationExpiry: verificationExpiry,
        });

        // Send new verification email
        const emailResult = await sendVerificationEmail(
            normalizedEmail,
            `${userData.firstName} ${userData.lastName}`,
            verificationToken
        );

        if (emailResult.success) {
            res.json({ 
                success: true,
                message: 'ส่งอีเมลยืนยันใหม่แล้ว กรุณาตรวจสอบอีเมลของคุณ' 
            });
        } else {
            res.status(500).json({ 
                error: 'ไม่สามารถส่งอีเมลยืนยันได้ กรุณาลองใหม่อีกครั้ง' 
            });
        }

    } catch (error) {
        console.error('Resend verification error:', error);
        res.status(500).json({ 
            error: 'เกิดข้อผิดพลาดในการส่งอีเมลยืนยัน' 
        });
    }
});

// Login endpoint with email verification check
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ 
                error: 'กรุณากรอกอีเมลและรหัสผ่าน' 
            });
        }

        const db = admin.firestore();
        const normalizedEmail = email.toLowerCase().trim();
        
        // Find user by email
        const userSnapshot = await db.collection('users')
            .where('email', '==', normalizedEmail)
            .get();
        
        if (userSnapshot.empty) {
            return res.status(401).json({ 
                error: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' 
            });
        }

    const userDoc = userSnapshot.docs[0];
    const userData = userDoc.data();

        // Check password
        const isPasswordValid = await bcrypt.compare(password, userData.password);
        
        if (!isPasswordValid) {
            return res.status(401).json({ 
                error: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' 
            });
        }

        // Check if email is verified
        if (!userData.isEmailVerified) {
            return res.status(401).json({ 
                error: 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ',
                emailNotVerified: true,
                email: normalizedEmail
            });
        }

        // Check if user is active
        if (!userData.isActive) {
            return res.status(401).json({ 
                error: 'บัญชีของคุณถูกระงับการใช้งาน กรุณาติดต่อผู้ดูแลระบบ' 
            });
        }

        // Ensure userCode exists for legacy users
        let ensuredUserCode = userData.userCode;
        if (!ensuredUserCode) {
            ensuredUserCode = generateUserCode();
            await userDoc.ref.update({ userCode: ensuredUserCode, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        }

        // Return user data (without sensitive information)
        const { password: _, emailVerificationToken: __, ...userInfo } = userData;
        userInfo.userCode = ensuredUserCode;
        
        // Create JWT token
        const token = jwt.sign(
            { 
                id: userDoc.id, // เปลี่ยนจาก userId เป็น id
                userId: userDoc.id, // เก็บไว้เพื่อ backward compatibility
                email: userData.email,
                userName: `${userData.firstName} ${userData.lastName}`,
                studentId: userData.studentId,
                role: userData.role 
            },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN || '1h' }
        );

        res.json({
            success: true,
            message: 'เข้าสู่ระบบสำเร็จ',
            token,
            user: {
                id: userDoc.id,
                ...userInfo
            }
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ 
            error: 'เกิดข้อผิดพลาดในระบบ กรุณาลองใหม่อีกครั้ง' 
        });
    }
});

// Logout endpoint
router.post('/logout', (req, res) => {
    res.json({ 
        success: true,
        message: 'ออกจากระบบสำเร็จ' 
    });
});

// Get current user profile
router.get('/me', authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const userDoc = await db.collection('users').doc(req.user.userId).get();

        if (!userDoc.exists) {
            return res.status(404).json({ error: 'ไม่พบข้อมูลผู้ใช้' });
        }

        const userData = userDoc.data();

        // Ensure userCode exists
        let ensuredUserCode = userData.userCode;
        if (!ensuredUserCode) {
            ensuredUserCode = generateUserCode();
            await userDoc.ref.update({ userCode: ensuredUserCode, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        }

        const { password: _pw, emailVerificationToken: _evt, ...userInfo } = userData;
        userInfo.userCode = ensuredUserCode;

        res.json({
            success: true,
            user: {
                id: userDoc.id,
                ...userInfo,
            }
        });
    } catch (error) {
        console.error('Get /auth/me error:', error);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในระบบ' });
    }
});

// Update current user profile (firstName, lastName, phone only)
router.put('/profile', authenticateToken, async (req, res) => {
    try {
        const { firstName, lastName, phone } = req.body;
        const db = admin.firestore();
        const userRef = db.collection('users').doc(req.user.userId);
        const userDoc = await userRef.get();

        if (!userDoc.exists) {
            return res.status(404).json({ error: 'ไม่พบข้อมูลผู้ใช้' });
        }

        const updates = {};
        if (typeof firstName === 'string' && firstName.trim()) updates.firstName = firstName.trim();
        if (typeof lastName === 'string' && lastName.trim()) updates.lastName = lastName.trim();
        if (typeof phone === 'string' && phone.trim()) updates.phone = phone.trim();

        if (Object.keys(updates).length === 0) {
            return res.status(400).json({ error: 'ไม่มีข้อมูลสำหรับอัปเดต' });
        }

        updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await userRef.update(updates);

        const updatedDoc = await userRef.get();
        const updatedData = updatedDoc.data();
        const { password: _pw2, emailVerificationToken: _evt2, ...userInfo } = updatedData;

        res.json({
            success: true,
            message: 'อัปเดตโปรไฟล์สำเร็จ',
            user: {
                id: updatedDoc.id,
                ...userInfo,
            }
        });
    } catch (error) {
        console.error('Update /auth/profile error:', error);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในระบบ' });
    }
});

// Verify token endpoint
router.get('/verify', require('../middleware/auth').authenticateToken, async (req, res) => {
    try {
        const db = admin.firestore();
        const userDoc = await db.collection('users').doc(req.user.userId).get();
        
        if (!userDoc.exists) {
            return res.status(404).json({ 
                error: 'ไม่พบข้อมูลผู้ใช้' 
            });
        }

        const userData = userDoc.data();
        const { password: _, emailVerificationToken: __, ...userInfo } = userData;

        res.json({
            success: true,
            user: {
                id: userDoc.id,
                ...userInfo
            }
        });

    } catch (error) {
        console.error('Verify token error:', error);
        res.status(500).json({ 
            error: 'เกิดข้อผิดพลาดในการตรวจสอบโทเค็น' 
        });
    }
});

// Check email verification status endpoint
router.get('/check-verification-status/:email', async (req, res) => {
    try {
        const { email } = req.params;
        const normalizedEmail = email.toLowerCase().trim();
        
        console.log(`🔍 Checking verification status for: ${normalizedEmail}`);
        
        const db = admin.firestore();
        
        // Find user by email
        const userSnapshot = await db.collection('users')
            .where('email', '==', normalizedEmail)
            .get();
        
        if (userSnapshot.empty) {
            return res.status(404).json({ 
                success: false,
                error: 'ไม่พบบัญชีผู้ใช้นี้',
                isVerified: false
            });
        }

        const userDoc = userSnapshot.docs[0];
        const userData = userDoc.data();
        
        console.log(`📧 User found: ${userData.firstName} ${userData.lastName}`);
        console.log(`✅ Email verified: ${userData.isEmailVerified}`);
        console.log(`🔐 Account active: ${userData.isActive}`);

        res.json({
            success: true,
            isVerified: userData.isEmailVerified || false,
            isActive: userData.isActive || false,
            userInfo: {
                id: userDoc.id,
                email: userData.email,
                firstName: userData.firstName,
                lastName: userData.lastName,
                emailVerifiedAt: userData.emailVerifiedAt,
                createdAt: userData.createdAt
            }
        });

    } catch (error) {
        console.error('Check verification status error:', error);
        res.status(500).json({ 
            success: false,
            error: 'เกิดข้อผิดพลาดในการตรวจสอบสถานะ',
            isVerified: false
        });
    }
});

// สร้าง admin token สำหรับการจัดการระบบ
router.post('/admin-token', async (req, res) => {
    try {
        const { adminSecret } = req.body;
        
        // ตรวจสอบ admin secret (ควรเก็บใน environment variable)
        const expectedSecret = process.env.ADMIN_SECRET || 'your-admin-secret-key';
        // In production, refuse default secret
        if (process.env.NODE_ENV === 'production' && expectedSecret === 'your-admin-secret-key') {
            return res.status(500).json({ error: 'ADMIN_SECRET is not configured' });
        }
        
        if (adminSecret !== expectedSecret) {
            return res.status(401).json({
                error: 'ไม่ได้รับอนุญาต: admin secret ไม่ถูกต้อง'
            });
        }
        
        const adminPayload = {
            id: 'admin',
            email: 'admin@system',
            role: 'admin',
            isAdmin: true,
            type: 'system_admin'
        };

        const token = jwt.sign(
            adminPayload,
            process.env.JWT_SECRET,
            { expiresIn: '24h' }
        );

        console.log('🔐 Admin token created successfully');
        
        res.json({
            message: 'Admin token สร้างสำเร็จ',
            token,
            user: {
                id: 'admin',
                email: 'admin@system',
                role: 'admin',
                isAdmin: true
            }
        });

    } catch (err) {
        console.error('Error creating admin token:', err);
        res.status(500).json({ 
            error: 'เกิดข้อผิดพลาดในการสร้าง admin token' 
        });
    }
});

module.exports = router;
 
// ==================== Password reset and change ====================
// Request password reset (send email with link)
router.post('/request-password-reset', async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) return res.status(400).json({ error: 'กรุณาระบุอีเมล' });

        const db = admin.firestore();
        const normalizedEmail = String(email).toLowerCase().trim();
        const userSnap = await db.collection('users').where('email', '==', normalizedEmail).limit(1).get();
        if (userSnap.empty) return res.status(200).json({ success: true, message: 'หากอีเมลถูกต้อง ระบบได้ส่งลิงก์รีเซ็ตรหัสผ่านแล้ว' });

        const userDoc = userSnap.docs[0];
        const token = generateVerificationToken();
        const expiry = new Date();
        expiry.setHours(expiry.getHours() + 1); // 1 hour
        await userDoc.ref.update({
            passwordResetToken: token,
            passwordResetExpiry: expiry,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const send = await sendPasswordResetEmail(normalizedEmail, `${userDoc.data().firstName} ${userDoc.data().lastName}`, token);
        if (!send.success) console.warn('Failed to send reset email:', send.message);
        res.json({ success: true, message: 'หากอีเมลถูกต้อง ระบบได้ส่งลิงก์รีเซ็ตรหัสผ่านแล้ว' });
    } catch (e) {
        console.error('request-password-reset error:', e);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในระบบ' });
    }
});

// Check reset token valid
router.get('/check-reset-token/:token', async (req, res) => {
    try {
        const { token } = req.params;
        const db = admin.firestore();
        const snap = await db.collection('users').where('passwordResetToken', '==', token).limit(1).get();
        if (snap.empty) return res.status(400).json({ success: false, error: 'โทเค็นไม่ถูกต้อง' });
        const doc = snap.docs[0];
        const data = doc.data();
        const expiry = data.passwordResetExpiry && data.passwordResetExpiry.toDate ? data.passwordResetExpiry.toDate() : new Date(0);
        if (new Date() > expiry) return res.status(400).json({ success: false, error: 'โทเค็นหมดอายุแล้ว' });
        res.json({ success: true });
    } catch (e) {
        console.error('check-reset-token error:', e);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในระบบ' });
    }
});

// Reset password using token
router.post('/reset-password', async (req, res) => {
    try {
        console.log('Reset password attempt:', { 
            hasToken: !!req.body.token, 
            hasPassword: !!req.body.newPassword,
            contentType: req.headers['content-type']
        });
        
        const { token, newPassword } = req.body;
        if (!token || !newPassword) {
            console.log('Missing required fields');
            return res.status(400).json({ error: 'ข้อมูลไม่ครบถ้วน' });
        }
        
        if (String(newPassword).length < 6) {
            console.log('Password too short');
            return res.status(400).json({ error: 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร' });
        }
        
        const db = admin.firestore();
        console.log('Looking for user with token...');
        const snap = await db.collection('users').where('passwordResetToken', '==', token).limit(1).get();
        
        if (snap.empty) {
            console.log('Token not found in database');
            return res.status(400).json({ error: 'โทเค็นไม่ถูกต้อง' });
        }
        
        const doc = snap.docs[0];
        const data = doc.data();
        console.log('Found user:', { userId: doc.id, email: data.email });
        
        const expiry = data.passwordResetExpiry && data.passwordResetExpiry.toDate ? data.passwordResetExpiry.toDate() : new Date(0);
        if (new Date() > expiry) {
            console.log('Token expired:', { expiry, now: new Date() });
            return res.status(400).json({ error: 'โทเค็นหมดอายุแล้ว' });
        }

        console.log('Hashing new password...');
        const hashed = await bcrypt.hash(newPassword, 10);
        
        console.log('Updating user password...');
        await doc.ref.update({
            password: hashed,
            passwordResetToken: admin.firestore.FieldValue.delete(),
            passwordResetExpiry: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        console.log('Password updated successfully');
        
        // If the request comes from a browser form or expects HTML, show a pretty success page
                const accept = String(req.headers['accept'] || '');
                const contentType = String(req.headers['content-type'] || '');
                const wantsHtml = accept.includes('text/html') || contentType.includes('application/x-www-form-urlencoded');
                if (wantsHtml) {
                        const frontendUrl = process.env.FRONTEND_URL || '';
                        const loginUrl = frontendUrl ? `${frontendUrl}/login` : '/';
                        const html = `<!DOCTYPE html>
                        <html lang="th"><head>
                        <meta charset="UTF-8">
                        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
                        <title>เปลี่ยนรหัสผ่านสำเร็จ</title>
                        <style>
                            body{margin:0;background:linear-gradient(135deg,#0ea5e9 0%, #10b981 100%);font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;min-height:100vh;display:flex;align-items:center;justify-content:center;color:#0f172a}
                            .card{background:#fff;border-radius:20px;box-shadow:0 20px 40px rgba(0,0,0,.15);max-width:520px;width:92%;padding:32px;text-align:center}
                            .check{width:88px;height:88px;border-radius:50%;background:#10b981;margin:0 auto 18px;display:flex;align-items:center;justify-content:center;color:#fff;font-size:48px;box-shadow:0 10px 20px rgba(16,185,129,.35)}
                            h1{margin:8px 0 6px;font-size:28px;color:#0f172a}
                            p{margin:0 0 18px;color:#475569;line-height:1.6}
                            .hint{font-size:13px;color:#64748b;margin-top:8px}
                            .btn{display:inline-block;padding:12px 18px;border-radius:12px;background:#0ea5e9;color:#fff;text-decoration:none;font-weight:600;box-shadow:0 10px 20px rgba(14,165,233,.35)}
                            .btn:hover{filter:brightness(1.05)}
                        </style>
                        </head><body>
                            <div class="card">
                                <div class="check">✓</div>
                                <h1>เปลี่ยนรหัสผ่านสำเร็จ</h1>
                                <p>ระบบได้อัปเดตรหัสผ่านของคุณเรียบร้อยแล้ว<br/>คุณสามารถเข้าสู่ระบบด้วยรหัสผ่านใหม่ได้ทันที</p>
                                <a class="btn" href="${loginUrl}">กลับไปหน้าเข้าสู่ระบบ</a>
                                <div class="hint">หากไม่ได้ถูกพาไปภายใน 3 วินาที ระบบจะพาไปอัตโนมัติ</div>
                            </div>
                            <script>setTimeout(function(){ window.location.href = '${loginUrl}'; }, 3000);</script>
                        </body></html>`;
                        return res.send(html);
                }
                // Otherwise, default to JSON for API clients (Flutter)
                res.json({ success: true, message: 'เปลี่ยนรหัสผ่านสำเร็จ' });
    } catch (e) {
        console.error('reset-password error:', e);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในระบบ' });
    }
});

// Change password (authenticated)
router.post('/change-password', authenticateToken, async (req, res) => {
    try {
        const { currentPassword, newPassword } = req.body;
        if (!currentPassword || !newPassword) return res.status(400).json({ error: 'ข้อมูลไม่ครบถ้วน' });
        if (String(newPassword).length < 6) return res.status(400).json({ error: 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร' });
        const db = admin.firestore();
        const userRef = db.collection('users').doc(req.user.userId);
        const snap = await userRef.get();
        if (!snap.exists) return res.status(404).json({ error: 'ไม่พบข้อมูลผู้ใช้' });
        const data = snap.data();
        const isValid = await bcrypt.compare(currentPassword, data.password);
        if (!isValid) return res.status(401).json({ error: 'รหัสผ่านเดิมไม่ถูกต้อง' });
        const hashed = await bcrypt.hash(newPassword, 10);
        await userRef.update({ password: hashed, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        res.json({ success: true, message: 'เปลี่ยนรหัสผ่านสำเร็จ' });
    } catch (e) {
        console.error('change-password error:', e);
        res.status(500).json({ error: 'เกิดข้อผิดพลาดในระบบ' });
    }
});

// Serve password reset page (simple HTML) for token
router.get('/reset-password-page/:token', async (req, res) => {
    try {
        const { token } = req.params;
        const frontendUrl = process.env.FRONTEND_URL || '';
        // Redirect only when FRONTEND_URL is explicitly configured to a non-localhost URL
        // to avoid broken links during local development (e.g., http://localhost:8080 not running).
        const shouldRedirect = frontendUrl && !/localhost(?::\d+)?/i.test(frontendUrl);
        if (shouldRedirect) {
            return res.redirect(`${frontendUrl}/reset-password?token=${encodeURIComponent(token)}`);
        }
        // Fallback: Simple HTML form
        const html = `<!DOCTYPE html><html><head><meta charset="UTF-8"><title>รีเซ็ตรหัสผ่าน</title>
        <style>body{font-family:Arial, sans-serif;background:#f3f4f6;padding:20px;} .card{max-width:420px;margin:40px auto;background:#fff;padding:24px;border-radius:12px;box-shadow:0 10px 20px rgba(0,0,0,0.08);} input{width:100%;padding:10px;margin:8px 0;border:1px solid #e5e7eb;border-radius:8px;} button{width:100%;padding:12px;background:#0ea5e9;color:#fff;border:none;border-radius:8px;font-weight:600;}</style>
        </head><body><div class="card"><h2>รีเซ็ตรหัสผ่าน</h2>
        <form method="post" action="/api/auth/reset-password">
          <input type="hidden" name="token" value="${token}"/>
          <input type="password" name="newPassword" placeholder="รหัสผ่านใหม่" required minlength="6"/>
          <input type="password" name="confirm" placeholder="ยืนยันรหัสผ่านใหม่" required minlength="6"/>
          <button type="submit">ยืนยันการเปลี่ยนรหัสผ่าน</button>
        </form>
        <script>document.querySelector('form').addEventListener('submit', function(e){var p=this.newPassword.value; var c=this.confirm.value; if(p!==c){e.preventDefault(); alert('รหัสผ่านใหม่และยืนยันไม่ตรงกัน');}});</script>
        </div></body></html>`;
        res.send(html);
    } catch (e) {
        console.error('reset-password-page error:', e);
        res.status(500).send('เกิดข้อผิดพลาด');
    }
});
