@echo off
echo ===========================================
echo    รีสตาร์ทแอป Flutter สำหรับทดสอบโหมดใหม่
echo ===========================================
echo.

echo กำลังหยุดแอป...
taskkill /f /im flutter.exe 2>nul
timeout /t 2 /nobreak >nul

echo กำลังเคลียร์ cache...
cd /d "%~dp0"
if exist "build" rmdir /s /q "build"
if exist ".dart_tool" rmdir /s /q ".dart_tool"

echo กำลังรีสตาร์ทแอป...
echo คำสั่ง: flutter run -d chrome --web-port=8080
echo.
echo ============================================
echo  เปิดเบราว์เซอร์ไปที่: http://localhost:8080
echo ============================================
echo.

start cmd /k "flutter run -d chrome --web-port=8080"

echo แอปกำลังเริ่มต้น กรุณารอสักครู่...
timeout /t 3 /nobreak >nul

pause
