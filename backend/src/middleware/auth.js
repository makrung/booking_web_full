const jwt = require('jsonwebtoken');
require('dotenv').config();

// Middleware สำหรับตรวจสอบ JWT token
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
        return res.status(401).json({ 
            error: 'ไม่พบ token กรุณาเข้าสู่ระบบ',
            requireAuth: true 
        });
    }

    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) {
            console.error('JWT verification error:', err.message);
            if (err.name === 'TokenExpiredError') {
                return res.status(401).json({ 
                    error: 'Token หมดอายุ กรุณาเข้าสู่ระบบใหม่',
                    requireAuth: true 
                });
            }
            return res.status(403).json({ 
                error: 'Token ไม่ถูกต้อง',
                requireAuth: true 
            });
        }
        
        // ตรวจสอบว่า user object มี id หรือไม่
        if (!user || !user.id) {
            console.error('Invalid user data in JWT:', user);
            return res.status(401).json({ 
                error: 'ข้อมูลใน token ไม่ถูกต้อง',
                requireAuth: true 
            });
        }
        
        console.log('JWT verified successfully for user:', user.id);
        req.user = user; // เก็บข้อมูลผู้ใช้ใน request
        next();
    });
};

// Middleware สำหรับตรวจสอบ token แบบ optional
const optionalAuth = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        req.user = null;
        return next();
    }

    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) {
            req.user = null;
        } else {
            req.user = user;
        }
        next();
    });
};

module.exports = {
    authenticateToken,
    optionalAuth
};
