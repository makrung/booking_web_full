const crypto = require('crypto');
require('dotenv').config();
const { Resend } = require('resend');

// สร้าง client ของ Resend (ใช้ API key เดียว เรียบง่าย)
const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null;

// ฟังก์ชันส่งอีเมลแบบง่าย ใช้ Resend API
const sendEmailSimple = async (to, subject, html) => {
    if (!process.env.RESEND_API_KEY) {
        throw new Error('RESEND_API_KEY is missing');
    }
    if (!resend) {
        throw new Error('Resend client not initialized');
    }
    const fromAddress = process.env.EMAIL_FROM || process.env.EMAIL_USER || 'noreply@example.com';
    const { data, error } = await resend.emails.send({
        from: `ระบบจองสนามกีฬา <${fromAddress}>`,
        to: Array.isArray(to) ? to : [to],
        subject,
        html
    });
    if (error) {
        throw new Error(`Resend error: ${error.message || JSON.stringify(error)}`);
    }
    const msgId = (data && (data.id || data.messageId)) || 'unknown-id';
    console.log('✅ Email sent via Resend:', msgId);
    return { success: true, messageId: msgId };
};

// สร้างโทเค็นการยืนยันที่ปลอดภัย
const generateVerificationToken = () => {
    return crypto.randomBytes(32).toString('hex');
};

// ส่งอีเมลยืนยัน
const sendVerificationEmail = async (userEmail, userName, verificationToken) => {
    try {
        // ลิงก์ยืนยันชี้ไปที่ backend API ที่จะ redirect ไป frontend
    // Use Railway domain or localhost for development
    const backendBase = process.env.FRONTEND_URL || 'http://localhost:3000';
    const verificationUrl = `${backendBase}/api/auth/verify-email/${verificationToken}`;
        
        const emailTemplate = `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>ยืนยันอีเมลของคุณ</title>
                <style>
                    body { font-family: 'Sarabun', Arial, sans-serif; line-height: 1.6; color: #333; }
                    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
                    .content { background: #ffffff; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                    .btn { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; display: inline-block; margin: 20px 0; font-weight: bold; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3); }
                    .btn:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4); }
                    .info-box { background: #f8f9fa; padding: 20px; border-radius: 10px; margin: 20px 0; border-left: 4px solid #667eea; }
                    .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
                    .warning { background: #fff3cd; color: #856404; padding: 15px; border-radius: 5px; margin: 15px 0; border-left: 4px solid #ffc107; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>🏆 ยืนยันอีเมลของคุณ</h1>
                        <p>ระบบจองสนามกีฬา มหาวิทยาลัยศิลปกรรม</p>
                    </div>
                    <div class="content">
                        <h2>สวัสดี ${userName}! 👋</h2>
                        <p>ยินดีต้อนรับสู่ระบบจองสนามกีฬาของมหาวิทยาลัยศิลปกรรม!</p>
                        <p>กรุณาคลิกปุ่มด้านล่างเพื่อยืนยันอีเมลของคุณ:</p>
                        
                        <div style="text-align: center;">
                            <a href="${verificationUrl}" class="btn">✅ ยืนยันอีเมล</a>
                        </div>
                        
                        <div class="info-box">
                            <h3>📋 ข้อมูลการยืนยัน:</h3>
                            <ul>
                                <li><strong>อีเมล:</strong> ${userEmail}</li>
                                <li><strong>วันที่สมัคร:</strong> ${new Date().toLocaleString('th-TH')}</li>
                                <li><strong>ลิงก์หมดอายุ:</strong> ภายใน 24 ชั่วโมง</li>
                            </ul>
                        </div>
                        
                        <div class="warning">
                            <strong>🚨 สำคัญ:</strong> คุณจะไม่สามารถเข้าสู่ระบบได้จนกว่าจะยืนยันอีเมลแล้ว
                        </div>
                        
                        <h3>🎯 ขั้นตอนการใช้งาน:</h3>
                        <ol>
                            <li>คลิกปุ่ม "ยืนยันอีเมล" ด้านบน</li>
                            <li>เข้าสู่ระบบด้วยอีเมลและรหัสผ่าน</li>
                            <li>เริ่มจองสนามกีฬาได้ทันที!</li>
                        </ol>
                        
                        <p><small>หากปุ่มไม่ทำงาน คุณสามารถคัดลอกลิงก์นี้ไปวางในเบราว์เซอร์: <br><a href="${verificationUrl}">${verificationUrl}</a></small></p>
                    </div>
                    <div class="footer">
                        <p>หากต้องการความช่วยเหลือ ติดต่อ admin@su.ac.th</p>
                        <p>© 2025 มหาวิทยาลัยศิลปกรรม</p>
                    </div>
                </div>
            </body>
            </html>
        `;
        
        // ส่งด้วย Resend แบบง่าย
        console.log('📧 EMAIL SERVICE: Using Resend API');
        const result = await sendEmailSimple(
            userEmail,
            'ยืนยันอีเมลสำหรับระบบจองสนามกีฬา',
            emailTemplate
        );
        
        console.log('\n📧 EMAIL VERIFICATION');
        console.log('==========================================');
        console.log(`To: ${userEmail}`);
        console.log(`Verification URL: ${verificationUrl}`);
        console.log(`✅ Email sent successfully!`);
        console.log('==========================================\n');
        
        return result;
        
    } catch (error) {
        console.error('❌ Error sending verification email:', error);
        return { success: false, message: error.message };
    }
};

// ส่งอีเมลต้อนรับเมื่อยืนยันเสร็จแล้ว (ไม่มีปุ่มเข้าสู่ระบบ)
const sendWelcomeEmail = async (userEmail, userName) => {
    try {
        const welcomeTemplate = `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>ยินดีต้อนรับสู่ระบบจองสนามกีฬา</title>
                <style>
                    body { font-family: 'Sarabun', Arial, sans-serif; line-height: 1.6; color: #333; }
                    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                    .header { background: linear-gradient(135deg, #2ecc71 0%, #27ae60 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
                    .content { background: #ffffff; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                    .feature { background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #2ecc71; }
                    .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
                    .success-box { background: #e8f5e8; padding: 20px; border-radius: 10px; margin: 20px 0; border-left: 4px solid #27ae60; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>🎉 ยินดีต้อนรับ!</h1>
                        <p>บัญชีของคุณพร้อมใช้งานแล้ว</p>
                    </div>
                    <div class="content">
                        <h2>สวัสดี ${userName}! 🏆</h2>
                        <p><strong>🎉 ยินดีด้วย! อีเมลของคุณได้รับการยืนยันเรียบร้อยแล้ว</strong></p>
                        
                        <div class="success-box">
                            <h3 style="color: #27ae60; margin-top: 0;">✅ คุณสามารถเข้าสู่ระบบผ่านหน้าเว็บได้แล้ว</h3>
                            <p style="margin-bottom: 0;">กลับไปยังหน้าเว็บและใช้อีเมลพร้อมรหัสผ่านของคุณเพื่อเข้าสู่ระบบ</p>
                        </div>
                        
                        <h3>🚀 สิ่งที่คุณสามารถทำได้:</h3>
                        <div class="feature">
                            <strong>🏀 จองสนามบาสเกตบอล</strong><br>
                            จองสนามบาสเกตบอลเพื่อการซ้อมหรือแข่งขัน
                        </div>
                        <div class="feature">
                            <strong>⚽ จองสนามฟุตบอล</strong><br>
                            จองสนามฟุตบอลและฟุตซอลสำหรับทีมของคุณ
                        </div>
                        <div class="feature">
                            <strong>📅 ดูตารางการจอง</strong><br>
                            ตรวจสอบตารางการจองและจัดการการจองของคุณ
                        </div>
                        <div class="feature">
                            <strong>🎯 ระบบคะแนน</strong><br>
                            เริ่มต้นด้วยคะแนน 100 คะแนน ใช้จองสนามฟรี!
                        </div>
                        
                        <h3>💡 เคล็ดลับการใช้งาน:</h3>
                        <ul>
                            <li><strong>เข้าสู่ระบบ:</strong> ใช้อีเมลและรหัสผ่านที่สมัครไว้</li>
                            <li><strong>จองล่วงหน้า:</strong> เพื่อให้แน่ใจว่าได้สนามที่ต้องการ</li>
                            <li><strong>โค้ด QR:</strong> ใช้เพื่อยืนยันการเข้าใช้สนาม</li>
                            <li><strong>ตรวจสอบคะแนน:</strong> ดูคะแนนคงเหลือของคุณเป็นประจำ</li>
                            <li><strong>ยกเลิกการจอง:</strong> แจ้งล่วงหน้าหากไม่สามารถไปได้</li>
                        </ul>
                    </div>
                    <div class="footer">
                        <p>หากต้องการความช่วยเหลือ ติดต่อ admin@su.ac.th</p>
                        <p>© 2025 ระบบจองสนามกีฬา มหาวิทยาลัยศิลปกรรม</p>
                    </div>
                </div>
            </body>
            </html>
        `;
        
        // ส่งอีเมลผ่าน Resend
        const result = await sendEmailSimple(userEmail, 'ยินดีต้อนรับสู่ระบบจองสนามกีฬา', welcomeTemplate);
        console.log(`✅ Welcome email sent to ${userEmail}`);
        return result;
        
    } catch (error) {
        console.error('❌ Error sending welcome email:', error);
        return { success: false, message: error.message };
    }
};

// ส่งอีเมลเตือนก่อนหมดอายุ
const sendTokenExpiryReminder = async (userEmail, userName, verificationToken) => {
    try {
    // Use Railway domain or localhost for development
    const backendBase = process.env.FRONTEND_URL || 'http://localhost:3000';
    const verificationUrl = `${backendBase}/api/auth/verify-email/${verificationToken}`;
        
        const emailTemplate = `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>เตือน: ลิงก์ยืนยันอีเมลกำลังจะหมดอายุ</title>
                <style>
                    body { font-family: 'Sarabun', Arial, sans-serif; line-height: 1.6; color: #333; }
                    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                    .header { background: linear-gradient(135deg, #f39c12 0%, #e67e22 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
                    .content { background: #ffffff; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                    .btn { background: linear-gradient(135deg, #f39c12 0%, #e67e22 100%); color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; display: inline-block; margin: 20px 0; font-weight: bold; }
                    .warning { background: #fff3cd; color: #856404; padding: 15px; border-radius: 5px; margin: 15px 0; border-left: 4px solid #ffc107; }
                    .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>⏰ เตือนความจำ</h1>
                        <p>ลิงก์ยืนยันอีเมลกำลังจะหมดอายุ</p>
                    </div>
                    <div class="content">
                        <h2>สวัสดี ${userName}!</h2>
                        <p>เราสังเกตเห็นว่าคุณยังไม่ได้ยืนยันอีเมลของคุณ</p>
                        
                        <div class="warning">
                            <strong>🚨 คำเตือน:</strong> ลิงก์ยืนยันอีเมลของคุณจะหมดอายุในอีก 2 ชั่วโมง!
                        </div>
                        
                        <p>กรุณาคลิกปุ่มด้านล่างเพื่อยืนยันอีเมลของคุณก่อนที่จะหมดอายุ:</p>
                        
                        <div style="text-align: center;">
                            <a href="${verificationUrl}" class="btn">⚡ ยืนยันอีเมลตอนนี้</a>
                        </div>
                        
                        <p><strong>หากลิงก์หมดอายุ:</strong> คุณสามารถขอลิงก์ใหม่ได้จากหน้าเข้าสู่ระบบ</p>
                    </div>
                    <div class="footer">
                        <p>หากต้องการความช่วยเหลือ ติดต่อ admin@su.ac.th</p>
                        <p>© 2025 มหาวิทยาลัยศิลปกรรม</p>
                    </div>
                </div>
            </body>
            </html>
        `;
        
        // ส่งอีเมลผ่าน Resend
        const result = await sendEmailSimple(userEmail, 'เตือน: ลิงก์ยืนยันอีเมลกำลังจะหมดอายุ', emailTemplate);
        console.log(`✅ Expiry reminder sent to ${userEmail}`);
        return result;
        
    } catch (error) {
        console.error('❌ Error sending reminder email:', error);
        return { success: false, message: error.message };
    }
};

// ส่งอีเมลรีเซ็ตรหัสผ่าน
const sendPasswordResetEmail = async (userEmail, userName, resetToken) => {
    try {
        // Always point to backend reset page; that page will redirect to FRONTEND_URL when configured
        // Use Railway domain or localhost for development
        const backendBase = process.env.FRONTEND_URL || 'http://localhost:3000';
        const resetUrl = `${backendBase}/api/auth/reset-password-page/${resetToken}`;
                const html = `
                <!DOCTYPE html>
                <html><head><meta charset="UTF-8"><title>รีเซ็ตรหัสผ่าน</title></head>
                <body style="font-family: Arial, sans-serif;">
                    <div style="max-width:600px;margin:auto;padding:20px;">
                        <h2>รีเซ็ตรหัสผ่าน</h2>
                        <p>สวัสดี ${userName}</p>
                        <p>คลิกลิงก์ด้านล่างเพื่อรีเซ็ตรหัสผ่านของคุณ (ลิงก์มีอายุ 1 ชั่วโมง)</p>
                        <p><a href="${resetUrl}" style="background:#0ea5e9;color:#fff;padding:10px 16px;border-radius:6px;text-decoration:none;">รีเซ็ตรหัสผ่าน</a></p>
                        <p>หากปุ่มกดไม่ได้ ให้คัดลอกลิงก์นี้ไปวางในเบราว์เซอร์: <br>${resetUrl}</p>
                    </div>
                </body></html>`;
                
        // ส่งอีเมลผ่าน Resend
        const result = await sendEmailSimple(userEmail, 'ลิงก์รีเซ็ตรหัสผ่าน', html);
        return result;
        } catch (e) {
                console.error('sendPasswordResetEmail error:', e);
                return { success: false, message: e.message };
        }
};

module.exports = {
    generateVerificationToken,
    sendVerificationEmail,
    sendWelcomeEmail,
    sendTokenExpiryReminder,
    sendPasswordResetEmail
};
