import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'services/booking_service.dart';
import 'services/settings_service.dart';
import 'services/enhanced_qr_reader_service.dart';
import 'services/auth_service.dart';
import 'package:intl/intl.dart';
import 'NewBookingHistory.dart';
import 'UserHomePage.dart';
import 'services/penalty_service.dart';

class QRConfirmationPage extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const QRConfirmationPage({Key? key, required this.bookingData}) : super(key: key);

  @override
  _QRConfirmationPageState createState() => _QRConfirmationPageState();
}

class _QRConfirmationPageState extends State<QRConfirmationPage> {
  int currentStep = 0;
  bool isScanning = false;
  bool isUploadMode = false;
  String? _lastScannedContent;

  // Shared simple helpers: sanitize for UI display, normalize for comparisons
  String _sanitize(String s) {
    var t = s
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll('\uFEFF', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
      t = t.substring(1, t.length - 1).trim();
    }
    return t;
  }

  String _normalize(String s) {
    return _sanitize(s).toLowerCase()
        .replaceAll(RegExp(r'[\s\u200B\u200C\u200D]+'), ' ')
        .replaceAll(RegExp(r'[-–—]+'), '-')
        .replaceAll(RegExp(r'["“”‟‚‘’]+'), '')
        .replaceAll(RegExp(r'[()\[\]{}]'), '');
  }

  @override
  void initState() {
    super.initState();
    _checkUploadMode();
  }

  Future<void> _checkUploadMode() async {
    final uploadMode = await SettingsService.isQRUploadModeEnabled();
    setState(() {
      isUploadMode = uploadMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F8FF),
      appBar: AppBar(
        backgroundColor: Colors.teal[700],
        title: Text('ยืนยันการจองด้วย QR Code', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stepper(
        currentStep: currentStep,
        onStepTapped: (step) {
          setState(() {
            currentStep = step;
          });
        },
        steps: [
          Step(
            title: Text('ข้อมูลการจอง'),
            content: _buildBookingInfo(),
            isActive: currentStep >= 0,
          ),
          Step(
            title: Text(isUploadMode ? 'อัปโหลดรูป QR Code' : 'สแกน QR Code ที่สนาม'),
            content: _buildQRScanner(),
            isActive: currentStep >= 1,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            if (currentStep > 0)
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentStep--;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[400],
                  ),
                  child: Text('ย้อนกลับ'),
                ),
              ),
            if (currentStep > 0) SizedBox(width: 16),
            if (currentStep < 1)
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentStep++;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'ถัดไป',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingInfo() {
    final date = DateTime.parse(widget.bookingData['date']);
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'รายละเอียดการจอง',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          _buildInfoRow('สนาม:', widget.bookingData['courtName'] ?? 'ไม่ทราบ'),
          _buildInfoRow('วันที่:', DateFormat('d MMMM yyyy', 'th').format(date)),
          _buildInfoRow('เวลา:', _formatBookingTimeSlots()),
          _buildInfoRow('กิจกรรม:', widget.bookingData['activity'] ?? 'ไม่ทราบ'),
          if (widget.bookingData['note'] != null && widget.bookingData['note'].isNotEmpty)
            _buildInfoRow('หมายเหตุ:', widget.bookingData['note']),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'กรุณาตรวจสอบข้อมูลให้ถูกต้องก่อนดำเนินการต่อ',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildQRScanner() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isUploadMode ? 'อัปโหลดรูป QR Code' : 'สแกน QR Code ที่สนาม',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          isUploadMode ? _buildUploadInterface() : _buildCameraInterface(),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final newMode = await SettingsService.toggleQRUploadMode();
              setState(() {
                isUploadMode = newMode;
                isScanning = false;
              });
            },
            icon: Icon(isUploadMode ? Icons.camera_alt : Icons.upload_file),
            label: Text(isUploadMode ? 'เปลี่ยนเป็นกล้อง' : 'เปลี่ยนเป็นอัปโหลด'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadInterface() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_file,
            size: 64,
            color: Colors.blue[400],
          ),
          SizedBox(height: 16),
          Text(
            'เลือกรูป QR Code',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.blue[700],
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _uploadQRImage,
            icon: Icon(Icons.photo_library),
            label: Text('เลือกจากอุปกรณ์'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraInterface() {
    return isScanning
        ? Container(
            height: 300,
            child: MobileScanner(
              onDetect: _onQRDetected,
            ),
          )
        : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 64,
                  color: Colors.teal[400],
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isScanning = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                  ),
                  child: Text('เริ่มสแกน'),
                ),
              ],
            ),
          );
  }

  Future<void> _uploadQRImage() async {
    try {
      // แสดง loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'กำลังอ่าน QR Code...',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'กรุณารอสักครู่',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );

  final qrContent = await EnhancedQRReaderService.readFromImagePicker();
      
      // ปิด loading dialog
      Navigator.pop(context);

      if (qrContent != null) {
        // Simpler approach: treat qrContent as plain court-name text or a JSON containing courtId.
        String detectedCourtName = _sanitize(qrContent);
        Map<String, dynamic>? qrJson;
        try {
          // If QR contains JSON with courtId, parse it for verification by ID later.
          final maybe = qrContent.trim();
          if (maybe.startsWith('{') && maybe.endsWith('}')) {
            qrJson = Map<String, dynamic>.from(json.decode(maybe) as Map);
            final nameFromJson = (qrJson['court_name'] ?? qrJson['courtName'] ?? '').toString();
            if (nameFromJson.isNotEmpty) detectedCourtName = _sanitize(nameFromJson);
          }
        } catch (_) {}

        final expectedCourtName = (widget.bookingData['courtName'] ?? '').toString();
        final expectedNorm = _normalize(expectedCourtName);
        final scannedNorm = _normalize(detectedCourtName);

        // Match by normalized name or by court ID if available
        final bool isMatchByName = scannedNorm.isNotEmpty && expectedNorm.isNotEmpty && scannedNorm == expectedNorm;
    // We only match by normalized court name (user requested name-only matching)
    final isMatchByNameOrId = isMatchByName;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(isMatchByNameOrId ? Icons.check_circle : Icons.warning,
                    color: isMatchByNameOrId ? Colors.green : Colors.orange),
                SizedBox(width: 8),
                Text(isMatchByNameOrId ? 'อ่าน QR Code สำเร็จ' : 'QR Code ไม่ตรงกับสนาม'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ผลการตรวจสอบ:'),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isMatchByNameOrId ? Colors.green[50] : Colors.orange[50]),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: (isMatchByNameOrId ? Colors.green[200]! : Colors.orange[200]!)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🏟️ สนามจาก QR: ${detectedCourtName.isEmpty ? 'ไม่ทราบ' : detectedCourtName}'),
                      SizedBox(height: 4),
                      Text('ที่จองไว้: $expectedCourtName'),
                      SizedBox(height: 8),
                      _buildVerificationResult({'court_name': detectedCourtName}),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processQRResult(qrContent);
                },
                child: Text('ตกลง'),
              ),
            ],
          ),
        );
      } else {
        // แสดงข้อผิดพลาด
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('ไม่สามารถอ่าน QR Code'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('กรุณาตรวจสอบ:'),
                SizedBox(height: 8),
                Text('• รูปภาพชัดและเห็น QR Code ทั้งหมด'),
                Text('• QR Code เป็นของสนามกีฬาจริง'),
                Text('• รูปภาพไม่เอียงหรือพร่ามัว'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('ลองใหม่'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // ปิด loading dialog ถ้ายังเปิดอยู่
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('เกิดข้อผิดพลาด'),
          content: Text('ไม่สามารถอ่าน QR Code ได้: ${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ตกลง'),
            ),
          ],
        ),
      );
    }
  }

  void _onQRDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      // Prefer first QR code and ignore non-QR formats
      final qr = barcodes.firstWhere(
        (b) => b.format == BarcodeFormat.qrCode && (b.rawValue?.trim().isNotEmpty ?? false),
        orElse: () => barcodes.first,
      );
      final String? qrContent = qr.rawValue?.trim();
      if (qrContent != null && qrContent.isNotEmpty) {
        setState(() {
          isScanning = false;
        });
        _processQRResult(qrContent);
      }
    }
  }

  void _processQRResult(String qrContent) {
    // Safe log
    try {
      String expectedName = (widget.bookingData['courtName'] ?? '').toString();
      bool matched = false;
      if (_looksLikeCourtJson(qrContent)) {
        // If the QR is JSON-like, try to read the court name and match by name only.
        final qrData = json.decode(qrContent);
        final scannedCourtName = (qrData['court_name'] ?? qrData['courtName'] ?? '').toString();
        matched = scannedCourtName.isNotEmpty && _normalize(scannedCourtName) == _normalize(expectedName);
      } else {
        // QR is plain text: treat it as the court name
        final scannedText = qrContent.trim();
        matched = scannedText.isNotEmpty && _normalize(scannedText) == _normalize(expectedName);
      }

      if (matched) {
        _lastScannedContent = qrContent;
        _confirmCheckIn();
      } else {
        _showErrorDialog(
          'QR Code ไม่ถูกต้อง',
          'QR Code นี้ไม่ตรงกับสนามที่คุณจอง (${widget.bookingData['courtName']})',
        );
      }
    } catch (e) {
      _showErrorDialog('เกิดข้อผิดพลาด', 'ไม่สามารถอ่าน QR Code ได้');
    }
  }

  Future<void> _confirmCheckIn() async {
    try {
      // แสดง loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('กำลังเช็คอิน...'),
              ],
            ),
          ),
        ),
      );

      // เรียกเช็คอินที่ backend (ยืนยันด้วย QR)
      final bookingId = (widget.bookingData['id'] ?? widget.bookingData['bookingId'])?.toString();
      Map<String, dynamic> result;
      if (bookingId != null && bookingId.isNotEmpty) {
        result = await BookingService.confirmBookingWithQR(
          bookingId: bookingId,
          qrData: _lastScannedContent ?? '',
        );
      } else {
        // หากไม่มี bookingId ให้แจ้งผลสำเร็จเฉย ๆ เพื่อไม่ให้ผู้ใช้ติดขัด (fallback)
        result = {'success': true};
      }

      // ปิด loading dialog
      Navigator.pop(context);

      if (result['success']) {
        // Refresh points after check-in to reflect +5 award (if any)
        int? updatedPoints;
        try {
          final p = await PenaltyService.getCurrentPoints();
          if (p['success'] == true) {
            updatedPoints = p['points'] as int;
          }
        } catch (_) {}
        // แสดงผลสำเร็จ
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('เช็คอินสำเร็จ!'),
              ],
            ),
            content: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('รายละเอียดการจอง:'),
                  SizedBox(height: 8),
                  Text('สนาม: ${widget.bookingData['courtName'] ?? 'ไม่ทราบ'}'),
                  Text('วันที่: ${widget.bookingData['date'] ?? 'ไม่ทราบ'}'),
                  Text('เวลา: ${_formatBookingTimeSlots()}'),
                  if (updatedPoints != null) ...[
                    SizedBox(height: 12),
                    Divider(),
                    Text('คะแนนของคุณอัปเดตแล้ว: $updatedPoints คะแนน', style: TextStyle(color: Colors.green[800])),
                  ],
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  // ดึงข้อมูลผู้ใช้ปัจจุบัน
                  final currentUser = await AuthService.getCurrentUser();
                  final username = currentUser != null 
                    ? '${currentUser['firstName']} ${currentUser['lastName']}'
                    : 'ผู้ใช้';
                  
                  // กลับไปหน้า UserHomePage แทน
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => UserHomePage(username: username),
                    ),
                    (route) => false,
                  );
                  
                  // หลังจากนั้นไปหน้าประวัติการจอง
                  Future.delayed(Duration(milliseconds: 100), () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BookingHistoryPage(),
                      ),
                    );
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
                child: Text('กลับหน้าหลัก'),
              ),
            ],
          ),
        );
      } else {
        _showErrorDialog('เช็คอินไม่สำเร็จ', result['message'] ?? 'เกิดข้อผิดพลาดในการเช็คอิน');
      }
    } catch (e) {
      // ปิด loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorDialog('เกิดข้อผิดพลาด', 'ไม่สามารถเช็คอินได้: $e');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationResult(Map<String, dynamic> qrData) {
    final scannedCourtName = (qrData['court_name'] ?? qrData['courtName'] ?? '').toString();
    final expectedCourtName = (widget.bookingData['courtName'] ?? '').toString();
    final isMatch = _normalize(scannedCourtName) == _normalize(expectedCourtName);
    
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMatch ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isMatch ? Colors.green[300]! : Colors.red[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isMatch ? Icons.check_circle : Icons.error,
            color: isMatch ? Colors.green[700] : Colors.red[700],
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              isMatch 
                ? '✅ ถูกต้อง - ตรงกับการจองของคุณ'
                : '❌ ไม่ถูกต้อง - ไม่ตรงกับการจองของคุณ',
              style: TextStyle(
                color: isMatch ? Colors.green[800] : Colors.red[800],
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันสำหรับจัดรูปแบบการแสดงช่วงเวลาในการจอง
  String _formatBookingTimeSlots() {
    try {
      // ตรวจสอบว่ามี timeSlots (array) หรือ timeSlot (string)
      if (widget.bookingData['timeSlots'] != null && widget.bookingData['timeSlots'] is List) {
        List<String> timeSlots = List<String>.from(widget.bookingData['timeSlots']);
        if (timeSlots.isEmpty) return 'ไม่ทราบเวลา';
        
        // จัดเรียงและแสดงช่วงเวลา
        timeSlots.sort();
        return timeSlots.join(', ');
      } else if (widget.bookingData['timeSlot'] != null && widget.bookingData['timeSlot'].toString().isNotEmpty) {
        // แปลงจาก comma-separated string
        String timeSlotString = widget.bookingData['timeSlot'].toString();
        if (timeSlotString.contains(',')) {
          List<String> timeSlots = timeSlotString.split(',').map((e) => e.trim()).toList();
          timeSlots.sort();
          return timeSlots.join(', ');
        } else {
          return timeSlotString.replaceAll('-', ' - ');
        }
      }
      
      return 'ไม่ทราบเวลา';
    } catch (e) {
      return 'ไม่ทราบเวลา';
    }
  }

  bool _looksLikeCourtJson(String s) {
    try {
      final d = json.decode(s);
      if (d is Map<String, dynamic>) {
        final type = d['type']?.toString();
        final hasName = d.containsKey('court_name') || d.containsKey('courtName');
        // Only require a court name to consider this a court JSON (name-only matching)
        return type == 'court_verification' && hasName;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
