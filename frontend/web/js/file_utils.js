// ฟังก์ชันสำหรับการบันทึกไฟล์ใน Flutter Web
function saveFile(dataUrl, filename) {
    const link = document.createElement('a');
    link.href = dataUrl;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

// ฟังก์ชันสำหรับแสดงข้อความแจ้งเตือน
function showNotification(message, type = 'info') {
    console.log(`[${type.toUpperCase()}] ${message}`);
}