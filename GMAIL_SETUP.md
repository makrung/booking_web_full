# Gmail App Password Setup (ง่ายที่สุด - ไม่ต้องสมัครใหม่!)

## ⚠️ หมายเหตุ: Railway บล็อก SMTP
**Railway บล็อก SMTP ports ทั้งหมด** ดังนั้นวิธีนี้จะใช้ไม่ได้บน Railway

**แนะนำใช้ MailerSend แทน** (ดูที่ MAILERSEND_SETUP.md)

---

## สำหรับ Local Development เท่านั้น

### 1. เปิด 2-Step Verification ใน Google Account
- ไปที่ https://myaccount.google.com/security
- เปิด "2-Step Verification"

### 2. สร้าง App Password
- ไปที่ https://myaccount.google.com/apppasswords
- เลือก App: "Mail"
- เลือก Device: "Other" → ตั้งชื่อว่า "Booking System"
- คัดลอก password 16 ตัว (จะไม่มีเว้นวรรค)

### 3. ใส่ใน .env (Local)
```
EMAIL_USER=your_email@gmail.com
EMAIL_PASS=your_16_digit_app_password
```

### 4. ไม่ต้องเพิ่มใน Railway
เพราะ Railway บล็อก SMTP อยู่ดี ต้องใช้ MailerSend แทน
