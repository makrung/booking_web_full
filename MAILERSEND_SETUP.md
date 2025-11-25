# MailerSend Setup for Railway

## 1. สมัคร MailerSend (Free Plan)
- ไปที่ https://www.mailersend.com/
- สมัครฟรี (ส่งได้ 12,000 อีเมล/เดือน)
- ไม่ต้อง verify domain ก็ส่งได้

## 2. สร้าง SMTP Credentials
- ไปที่ Settings > SMTP Users
- คลิก 'Add SMTP User'
- คัดลอก:
  - Username (จะเป็นรูปแบบ: MS_xxx)
  - Password

## 3. เพิ่ม Environment Variables ใน Railway
`
MAILERSEND_USERNAME=MS_xxx...
MAILERSEND_PASSWORD=your_password_here
MAILERSEND_FROM=noreply@trial-xxx.mlsender.net
`

## 4. Deploy!
- ส่งได้หาทุกอีเมลโดยไม่ต้อง verify domain
- Free plan: 12,000 emails/month
- SMTP port 587 (ใช้ได้กับ Railway)
