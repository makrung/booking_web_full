# Railway Environment Variables Setup

## ⚠️ สำคัญมาก! ต้องตั้งค่าใน Railway Dashboard

ไปที่: https://railway.app → เลือก project → **Variables** tab

## Required Environment Variables:

```bash
# 1. Firebase Service Account (JSON format)
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"database-project-ca9fc",...}

# 2. Node Environment
NODE_ENV=production

# 3. JWT Secret (ใช้ตัวเดียวกับ local)
JWT_SECRET=booking_sport_silpakorn_2025_secret_key_very_secure
JWT_EXPIRES_IN=1h

# 4. Email Configuration
EMAIL_USER=noretify32@gmail.com
EMAIL_PASS=qqkp ztff lrwr dhhu

# 5. Frontend URL (⚠️ ต้องเป็น Railway domain)
FRONTEND_URL=https://bookingwebfull-production.up.railway.app

# 6. Allowed Origins (for CORS)
ALLOWED_ORIGINS=https://bookingwebfull-production.up.railway.app

# 7. Trust Proxy
TRUST_PROXY=1

# 8. Reset Boundary Hour
RESET_BOUNDARY_HOUR=6
```

## 🔥 วิธีดู FIREBASE_SERVICE_ACCOUNT:

1. เปิดไฟล์: `backend/serviceAccountKey.json`
2. คัดลอกทั้งหมด (ต้องเป็น 1 บรรทัด, ไม่มี line break)
3. หรือใช้คำสั่ง PowerShell:

```powershell
# แปลง JSON เป็น 1 บรรทัด
Get-Content backend/serviceAccountKey.json -Raw | ConvertFrom-Json | ConvertTo-Json -Compress
```

4. Copy ผลลัพธ์ไปใส่ใน Railway

## ✅ หลังจากตั้งค่าแล้ว:

Railway จะ redeploy อัตโนมัติ (ใช้เวลา 10-15 วินาที)
