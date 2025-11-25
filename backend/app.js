require('dotenv').config();
const express = require('express');
const morgan = require('morgan');
const cors = require('cors');
const path = require('path');
const admin = require('./config/firebase'); 
const compression = require('compression');
const helmet = require('helmet');

const app = express();

// Middleware
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
// Security headers
app.use(helmet({
    contentSecurityPolicy: false, // this API mostly serves JSON and a couple of static HTML files
    crossOriginResourcePolicy: { policy: 'cross-origin' },
}));

// Hide X-Powered-By
app.disable('x-powered-by');

// CORS - restrict to known frontends (env + local dev)
const allowedOrigins = (() => {
    const list = [];
    if (process.env.FRONTEND_URL) list.push(process.env.FRONTEND_URL);
    if (process.env.ALLOWED_ORIGINS) {
        list.push(...process.env.ALLOWED_ORIGINS.split(',').map(s => s.trim()).filter(Boolean));
    }
    // Local dev defaults
    list.push('http://localhost:8080', 'http://127.0.0.1:8080');
    return Array.from(new Set(list));
})();

app.use(cors({
    origin: (origin, callback) => {
        try {
            // allow non-browser requests or same-origin calls
            if (!origin) return callback(null, true);
            
            // Dev mode: allow any localhost/127.0.0.1 origin (Flutter web uses random ports)
            const isProd = process.env.NODE_ENV === 'production';
            if (!isProd) {
                try {
                    const url = new URL(origin);
                    if (url.hostname === 'localhost' || url.hostname === '127.0.0.1') {
                        return callback(null, true);
                    }
                } catch (urlError) {
                    console.warn('Invalid origin URL:', origin);
                }
            }
            
            if (allowedOrigins.includes(origin)) return callback(null, true);
            
            // In development, be more permissive
            if (!isProd) {
                console.log('CORS: Allowing origin in dev mode:', origin);
                return callback(null, true);
            }
            
            return callback(new Error('Not allowed by CORS'));
        } catch (e) {
            console.error('CORS error:', e.message, 'Origin:', origin);
            return callback(new Error('CORS origin parse error'));
        }
    },
    credentials: true,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    optionsSuccessStatus: 204,
}));
app.use(compression());
app.use(express.json());
// Parse HTML form posts (application/x-www-form-urlencoded)
app.use(express.urlencoded({ extended: true }));
// Reduce JSON spacing in production
if (process.env.NODE_ENV === 'production') {
    app.set('json spaces', 0);
}

// Trust reverse proxy (needed for correct IPs and HTTPS in deployments behind a proxy)
if (process.env.TRUST_PROXY === '1' || process.env.NODE_ENV === 'production') {
    app.set('trust proxy', 1);
}

// Minimal env validation and warnings
const requiredEnv = ['JWT_SECRET'];
for (const k of requiredEnv) {
    if (!process.env[k]) {
        console.warn(`⚠️ Missing required env ${k}. Please configure it before production.`);
    }
}

// Simple in-memory rate limiter (per IP)
function createMemoryRateLimiter({ windowMs = 60 * 1000, max = 300, keyGenerator = (req) => req.ip } = {}) {
    const buckets = new Map();
    return function rateLimiter(req, res, next) {
        const key = keyGenerator(req) || 'global';
        const now = Date.now();
        let b = buckets.get(key);
        if (!b || now > b.reset) {
            b = { count: 0, reset: now + windowMs };
        }
        b.count += 1;
        buckets.set(key, b);

        // Set standard-ish headers
        res.setHeader('X-RateLimit-Limit', String(max));
        res.setHeader('X-RateLimit-Remaining', String(Math.max(0, max - b.count)));
        res.setHeader('X-RateLimit-Reset', String(Math.ceil(b.reset / 1000)));

        if (b.count > max) {
            return res.status(429).json({ error: 'Too Many Requests' });
        }
        next();
    };
}

// Serve static files with caching
const staticOptions = {
    maxAge: process.env.NODE_ENV === 'production' ? '7d' : 0,
    etag: true,
    lastModified: true,
    setHeaders: (res, filePath) => {
        // cache-busting for uploads can be shorter
        if (filePath.includes(path.join('public', 'uploads'))) {
            res.setHeader('Cache-Control', 'public, max-age=604800, immutable'); // 7d
        } else {
            res.setHeader('Cache-Control', 'public, max-age=604800');
        }
    }
};
app.use(express.static(path.join(__dirname, 'public'), staticOptions));

// Serve Flutter Web static files (Frontend)
const frontendBuildPath = path.join(__dirname, '../frontend/build/web');
app.use(express.static(frontendBuildPath, staticOptions));

// SPA fallback: For Flutter Web routing, redirect 404 to index.html
app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api/')) {
        return next(); // Let API routes handle
    }
    const indexPath = path.join(frontendBuildPath, 'index.html');
    res.sendFile(indexPath, (err) => {
        if (err) {
            res.status(404).json({ error: 'Not Found' });
        }
    });
});

// Quiet 404 spam from browsers requesting /favicon.ico during dev
app.get('/favicon.ico', (req, res) => res.status(204).end());

// Basic route
app.get('/', (req, res) => {
    res.json({ 
        message: 'Welcome to BookedSport API!',
        availableRoutes: {
            register: '/api/auth/register',
            login: '/api/auth/login',
            verifyEmail: '/api/auth/verify-email/:token',
            resendVerification: '/api/auth/resend-verification',
            courts: '/api/courts',       
            bookings: '/api/bookings'
        }
    });
});

// Email verification page route
app.get('/verify-email', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'email-verification.html'));
});

// Import routes
const bookingRoutes = require('./src/routes/booking.routes');
const courtRoutes = require('./src/routes/court.routes');
const authRoutes = require('./src/routes/auth.routes');
const adminRoutes = require('./src/routes/admin.routes');
const penaltyRoutes = require('./src/routes/penalty.routes');
const activityRoutes = require('./src/routes/activity.routes');
const courtManagementRoutes = require('./src/routes/court-management.routes');
const newsRoutes = require('./src/routes/news.routes');
const pointsRoutes = require('./src/routes/points.routes');
const contentRoutes = require('./src/routes/content.routes');

// Rate limiting: tighter for auth; moderate for general API
const authLimiter = createMemoryRateLimiter({ windowMs: 60 * 1000, max: 50 }); // 50 req/min per IP
const apiLimiter = createMemoryRateLimiter({ windowMs: 60 * 1000, max: 600 }); // 600 req/min per IP

// Use routes
app.use('/api/auth', authLimiter, authRoutes);
app.use('/api/admin', apiLimiter, adminRoutes);
app.use('/api/admin', apiLimiter, courtManagementRoutes);  
app.use('/api', apiLimiter, bookingRoutes);
app.use('/api', apiLimiter, courtRoutes);
app.use('/api', apiLimiter, penaltyRoutes);
app.use('/api', apiLimiter, activityRoutes);  
app.use('/api', apiLimiter, newsRoutes);
app.use('/api', apiLimiter, pointsRoutes);
app.use('/api', apiLimiter, contentRoutes);

// 404 handler
app.use((req, res, next) => {
    res.status(404).json({ error: 'Not Found' });
});

// Error handler
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Internal Server Error' });
});

module.exports = app;