import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'services/booking_service.dart';
import 'services/enhanced_location_service.dart';
import 'services/settings_service.dart';
import 'services/enhanced_qr_reader_service.dart';
import 'services/content_service.dart';
import 'models/location_model.dart';
import 'models/app_constants.dart';
import 'NewBookingHistory.dart';
import 'UserHomePage.dart';
import 'widgets/map_location_picker.dart';
import 'package:latlong2/latlong.dart';

class QRLocationVerificationPage extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final bool isRegularBooking; // true = การจองปกติ, false = การจองกิจกรรม

  const QRLocationVerificationPage({
    Key? key, 
    required this.bookingData,
    required this.isRegularBooking,
  }) : super(key: key);

  @override
  _QRLocationVerificationPageState createState() => _QRLocationVerificationPageState();
}

class _QRLocationVerificationPageState extends State<QRLocationVerificationPage>
    with TickerProviderStateMixin {
  int currentStep = 0;
  String? qrData;
  bool isScanning = false;
  // ตั้งค่าเริ่มต้นเป็นโหมดอัปโหลด เพื่อบังคับให้ใช้เฉพาะการอัปโหลดรูป QR Code
  bool isUploadMode = true;
  bool isVerifyingLocation = false;
  bool isSubmittingBooking = false;
  
  // Settings from backend
  bool requireQR = true;
  bool requireLocation = true;
  bool isLoadingSettings = true;
  
  UserLocation? userLocation;
  CourtLocation? courtLocation;
  Map<String, dynamic>? locationVerificationResult;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    
    _loadSettings();
    _loadBackendSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Normalize text for comparisons (trim, collapse whitespace, lowercase)
  String _normalize(String? s) {
    final t = (s ?? '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll('\uFEFF', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    return t
        .replaceAll(RegExp(r'[\s\u200B\u200C\u200D]+'), ' ')
        .replaceAll(RegExp(r'[-–—]+'), '-')
        .replaceAll('สนามที่', 'สนามที่');
  }

  // Lightweight sanitize used for UI display/one-off comparison
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

  // ตรวจสอบว่าสามารถยกเลิกการจองได้หรือไม่ (ตามเวลา)
  bool _canCancelByTime() {
    try {
      final bookingDate = widget.bookingData['date'];
      final timeSlots = widget.bookingData['timeSlots'] as List<dynamic>?;
      
      if (bookingDate == null || timeSlots == null || timeSlots.isEmpty) {
        return false;
      }

      // แปลงวันที่
      final String dateStr = bookingDate is String 
          ? bookingDate 
          : bookingDate.toString();
      
      final DateTime bookingDateTime = DateTime.parse(dateStr.split('T')[0]);
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);

      // ถ้าเลยวันแล้ว -> ยกเลิกไม่ได้
      if (bookingDateTime.isBefore(today)) {
        return false;
      }

      // ถ้าเป็นวันนี้ -> ตรวจสอบเวลา
      if (bookingDateTime.isAtSameMomentAs(today)) {
        // หาช่วงเวลาเริ่มเร็วสุด
        int? earliestStartMinutes;
        for (final slot in timeSlots) {
          if (slot is! String || !slot.contains('-')) continue;
          
          final parts = slot.split('-');
          final startTimeParts = parts[0].split(':');
          if (startTimeParts.length >= 2) {
            final hours = int.tryParse(startTimeParts[0]) ?? 0;
            final minutes = int.tryParse(startTimeParts[1]) ?? 0;
            final totalMinutes = hours * 60 + minutes;
            
            if (earliestStartMinutes == null || totalMinutes < earliestStartMinutes) {
              earliestStartMinutes = totalMinutes;
            }
          }
        }

        if (earliestStartMinutes != null) {
          final nowMinutes = now.hour * 60 + now.minute;
          // ถ้าถึงเวลาเริ่มแล้ว -> ยกเลิกไม่ได้
          if (nowMinutes >= earliestStartMinutes) {
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      print('Error checking cancel time: $e');
      return false;
    }
  }

  //ผู้ใช้ต้องสแกน QR ของสนามจริง

  // แสดง Status Card
  Widget _buildStatusCard() {
    final currentStatus = widget.bookingData['status'] ?? BookingStatus.pending;
    final statusColor = BookingStatus.statusColors[currentStatus] ?? '#9E9E9E';
    final Color cardColor = Color(int.parse(statusColor.replaceFirst('#', '0xFF')));
    
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              BookingStatus.statusIcons[currentStatus] ?? '📋',
              style: TextStyle(fontSize: 20),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  BookingStatus.statusMessages[currentStatus] ?? 'สถานะไม่ทราบ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cardColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  BookingStatus.statusDescriptions[currentStatus] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // แสดงปุ่มยกเลิกเฉพาะเมื่อ: 1) สถานะอนุญาต และ 2) ยังไม่ถึงเวลาเริ่ม
          if (BookingStatus.canCancel(currentStatus) && _canCancelByTime())
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.red),
              onPressed: _showCancelDialog,
              tooltip: 'ยกเลิกการจอง',
            ),
        ],
      ),
    );
  }

  // แสดง Dialog ยกเลิกการจอง
  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController reasonController = TextEditingController();
        
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('ยกเลิกการจอง'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('คุณต้องการยกเลิกการจองนี้หรือไม่?'),
              SizedBox(height: 16),
              Text(
                'หมายเหตุ: หากยกเลิกแล้ว คนอื่นจะสามารถจองเวลานี้ได้',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'เหตุผลการยกเลิก (ไม่บังคับ)',
                  hintText: 'เช่น มีธุระเร่งด่วน, เปลี่ยนแผน',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ไม่ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelBooking(reasonController.text);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('ยกเลิกการจอง', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // แสดงข้อมูลสถานะ
  void _showStatusInfo() {
    final currentStatus = widget.bookingData['status'] ?? BookingStatus.pending;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Text(BookingStatus.statusIcons[currentStatus] ?? '📋'),
              SizedBox(width: 8),
              Text('ข้อมูลสถานะการจอง'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusInfoRow('สถานะปัจจุบัน', BookingStatus.statusMessages[currentStatus] ?? 'ไม่ทราบ'),
              SizedBox(height: 8),
              _buildStatusInfoRow('รายละเอียด', BookingStatus.statusDescriptions[currentStatus] ?? ''),
              SizedBox(height: 16),
              Text('ขั้นตอนการใช้งาน:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('1. ${BookingStatus.statusMessages[BookingStatus.pending]}'),
              Text('2. ${BookingStatus.statusMessages[BookingStatus.confirmed]}'),
              Text('3. ${BookingStatus.statusMessages[BookingStatus.checkedIn]}'),
              Text('4. ${BookingStatus.statusMessages[BookingStatus.completed]}'),
              if (BookingStatus.affectsPoints(currentStatus)) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Text(
                    'การจองนี้ส่งผลต่อคะแนนของคุณ',
                    style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ปิด'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    );
  }

  // ยกเลิกการจอง
  Future<void> _cancelBooking(String reason) async {
    try {
      setState(() {
        isSubmittingBooking = true;
      });

      // หา bookingId ที่ถูกต้อง
      final bookingId = widget.bookingData['firebaseId'] ?? 
                       widget.bookingData['bookingId'] ?? 
                       widget.bookingData['id'];

      if (bookingId == null) {
        throw Exception('ไม่พบ booking ID');
      }

      print('🚫 Cancelling booking: $bookingId');

      final result = await BookingService.cancelBooking(bookingId);

      if (result['success']) {
        // อัปเดตสถานะในหน้านี้
        widget.bookingData['status'] = BookingStatus.cancelled;
        widget.bookingData['cancelledAt'] = DateTime.now().toIso8601String();
        if (reason.isNotEmpty) {
          widget.bookingData['cancellationReason'] = reason;
        }

        setState(() {
          isSubmittingBooking = false;
        });

        // แสดงข้อความสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result['message']}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // ไปหน้าประวัติการจอง (อนุญาตให้ย้อนกลับได้)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BookingHistoryPage()),
        );
      } else {
        setState(() {
          isSubmittingBooking = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isSubmittingBooking = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadSettings() async {
    final uploadMode = await SettingsService.isQRUploadModeEnabled();
    setState(() {
      isUploadMode = uploadMode;
    });
  }

  Future<void> _loadBackendSettings() async {
    try {
      // โหลด settings จาก backend
      final qrSetting = await ContentService.getContent('require_qr_verification');
      final locationSetting = await ContentService.getContent('require_location_verification');
      
  // backend settings loaded
      
      setState(() {
        // แปลงค่าเป็น boolean (รองรับทั้ง '0'/'1' และ 'false'/'true')
        requireQR = qrSetting == '1' || qrSetting?.toLowerCase() == 'true';
        requireLocation = locationSetting == '1' || locationSetting?.toLowerCase() == 'true';
        isLoadingSettings = false;
      });
      
  // parsed settings
      
      // ถ้าปิดทั้ง QR และ Location ให้ไป submit ทันที
      if (!requireQR && !requireLocation) {
  // Both QR and Location disabled, auto-submitting booking
        // ไม่ต้องยืนยัน QR และ Location ให้ submit เลย
        await Future.delayed(Duration(milliseconds: 100)); // รอให้ UI update
        _submitBooking();
      } else if (!requireQR && requireLocation) {
        // ถ้าปิดแค่ QR แต่เปิด Location ให้ข้ามไปยืนยัน location
  // QR disabled, proceeding to location verification
        await Future.delayed(Duration(milliseconds: 100));
        _proceedToLocationVerification();
      }
    } catch (e) {
  // error loading backend settings
      setState(() {
        isLoadingSettings = false;
        // ถ้า error ให้ใช้ค่า default (เปิดทั้งหมด เพื่อความปลอดภัย)
        requireQR = true;
        requireLocation = true;
      });
    }
  }

  Future<void> _scanQRCode() async {
    if (!widget.isRegularBooking) {
      // การจองกิจกรรมไม่ต้องแสกน QR
      _proceedToLocationVerification();
      return;
    }

    // ถ้าปิดการตรวจสอบ QR ให้ข้ามไปยืนยัน location หรือ submit เลย
    if (!requireQR) {
  // QR verification disabled, skipping to location/submit
      _proceedToLocationVerification();
      return;
    }

    setState(() {
      isScanning = true;
    });

    try {
      String? scannedData;
      
      if (isUploadMode) {
        scannedData = await EnhancedQRReaderService.readFromImagePicker();
      } else {
        // ใช้กล้องแสกน (ต้องเพิ่ม UI สำหรับ mobile_scanner)
        scannedData = await _showCameraScanner();
      }

      if (scannedData != null) {
    // scanned data received (logging suppressed)
        
        // แสดงข้อความแจ้งผลการอ่าน QR Code
        _showQRReadResult(scannedData);
        
          try {
            // Simplified behavior: only treat QR content as plain court name text.
            final expectedCourtName = _normalize(widget.bookingData['courtName']?.toString() ?? '');
            final scannedText = _normalize(scannedData.toString());

            if (scannedText.isNotEmpty && scannedText == expectedCourtName) {
              setState(() {
                isScanning = false;
                // store the raw scanned QR payload so submit/confirm calls can include it
                qrData = scannedData?.toString() ?? '';
                if (requireLocation) {
                  currentStep = requireQR ? 1 : 0;
                }
              });
              _proceedToLocationVerification();
            } else {
              _showErrorDialog(
                'QR Code ไม่ตรงกับสนามที่จอง\n\n'
                'สนามที่จอง: ${widget.bookingData['courtName'] ?? ''}\n'
                'QR Code ที่แสกน: ${_sanitize(scannedData)}\n\n'
                'กรุณาแสกน QR Code ของสนามที่ถูกต้อง'
              );
            }
          } catch (parseError) {
            _showErrorDialog('QR Code ไม่ถูกต้อง - กรุณาลองอีกครั้ง');
          }
      } else {
        _showErrorDialog(
          'ไม่สามารถอ่าน QR Code ได้\n\n'
          'เคล็ดลับ:\n'
          '• ตรวจสอบว่ารูปภาพชัดเจน\n'
          '• ถ่ายรูป QR Code ทั้งหมด\n'
          '• ใช้แสงที่เพียงพอ\n'
          '• หลีกเลี่ยงเงาบนรูปภาพ'
        );
      }
    } catch (e) {
      _showErrorDialog('เกิดข้อผิดพลาดในการแสกน QR Code\n${e.toString()}');
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  Future<String?> _showCameraScanner() async {
    return await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          height: 400,
          child: Column(
            children: [
              AppBar(
                title: Text('แสกน QR Code'),
                leading: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    try {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final b in barcodes) {
                        if (b.format == BarcodeFormat.qrCode) {
                          final value = b.rawValue?.trim();
                          if (value != null && value.isNotEmpty) {
                            Navigator.pop(context, value);
                            break;
                          }
                        }
                      }
                    } catch (_) {}
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _proceedToLocationVerification() async {
    // ถ้าไม่ต้องตรวจสอบ location ให้ข้ามไป submit เลย
    if (!requireLocation) {
      print('✅ Location verification disabled, proceeding to submit');
      _goToSubmitStep();
      return;
    }

    setState(() {
      isVerifyingLocation = true;
    });

    try {
      final result = await EnhancedLocationService.verifyCourtLocation(
        widget.bookingData['courtId'],
        context
      );
      
      setState(() {
        locationVerificationResult = result;
        isVerifyingLocation = false;
      });

      if (result['success']) {
        _goToSubmitStep();
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      setState(() {
        isVerifyingLocation = false;
      });
      _showErrorDialog('เกิดข้อผิดพลาดในการตรวจสอบตำแหน่ง: ${e.toString()}');
    }
  }

  void _goToSubmitStep() {
    // คำนวณ step index ของ Submit (ขึ้นอยู่กับว่าข้าม QR/Location หรือไม่)
    int submitStepIndex = 0;
    if (requireQR) submitStepIndex++;
    if (requireLocation) submitStepIndex++;
    
    setState(() {
      currentStep = submitStepIndex;
    });
    _submitBooking();
  }

  Future<void> _submitBooking() async {
    setState(() {
      isSubmittingBooking = true;
    });

    try {
      // สำหรับการจองที่มีอยู่แล้ว ให้ยืนยันด้วย QR Code และตำแหน่ง
      final dynamic existingIdDyn = widget.bookingData['id'] ?? widget.bookingData['bookingId'] ?? widget.bookingData['firebaseId'];
      final String? existingBookingId = existingIdDyn != null ? existingIdDyn.toString() : null;
      if (existingBookingId != null && existingBookingId.isNotEmpty) {
        final response = await BookingService.confirmBookingWithQR(
          bookingId: existingBookingId,
          qrData: qrData ?? '',
          latitude: userLocation?.latitude,
          longitude: userLocation?.longitude,
        );
        
        setState(() {
          isSubmittingBooking = false;
        });

        if (response['success']) {
          setState(() {
            // คำนวณ completion step index
            int completionStepIndex = 0;
            if (requireQR) completionStepIndex++;
            if (requireLocation) completionStepIndex++;
            completionStepIndex++; // submit step
            currentStep = completionStepIndex;
          });
          _showSuccessDialog();
        } else {
          _showErrorDialog(response['error'] ?? 'การยืนยันไม่สำเร็จ');
        }
        return;
      }

  // สำหรับการจองใหม่ (กรณีที่ยังไม่ได้บันทึก)
      Map<String, dynamic> bookingDataWithVerification = Map.from(widget.bookingData);
      bookingDataWithVerification['isLocationVerified'] = true;
      bookingDataWithVerification['isQRVerified'] = widget.isRegularBooking;
      bookingDataWithVerification['verificationTimestamp'] = DateTime.now().toIso8601String();
      
      if (locationVerificationResult != null) {
        bookingDataWithVerification['locationVerification'] = locationVerificationResult;
      }

      final response = await BookingService.createBooking(
        courtId: bookingDataWithVerification['courtId'],
        courtName: bookingDataWithVerification['courtName'] ?? '',
        date: bookingDataWithVerification['date'],
        timeSlots: List<String>.from(bookingDataWithVerification['timeSlots']),
        bookingType: widget.isRegularBooking ? 'regular' : 'activity',
        participantCodes: List<String>.from(bookingDataWithVerification['participantCodes'] ?? const []),
      );
      
      setState(() {
        isSubmittingBooking = false;
      });

      if (response['success']) {
        setState(() {
          // คำนวณ completion step index
          int completionStepIndex = 0;
          if (requireQR) completionStepIndex++;
          if (requireLocation) completionStepIndex++;
          completionStepIndex++; // submit step
          currentStep = completionStepIndex;
        });
        _showSuccessDialog();
      } else if (response['requiresConfirmation'] == true) {
        // ตรวจสอบว่า QR Code ที่สแกนตรงกับการจองที่รอยืนยันหรือไม่
        final List<dynamic> existingBookings = List<dynamic>.from(response['existingBookings'] as List);

        // Normalize helper
        String norm(String? s) => (s ?? '')
            .replaceAll(RegExp(r"[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]"), '')
            .replaceAll('\uFEFF', '')
            .replaceAll('\u00A0', ' ')
            .replaceAll(RegExp(r"\s+"), ' ')
            .trim()
            .toLowerCase();

    final scannedCourtName = _normalize(bookingDataWithVerification['courtName']?.toString());

    // 1) Try to find by normalized name and overlapping timeSlots/date if available
    Map<String, dynamic>? target = {};
    if (scannedCourtName.isNotEmpty) {
          final List<String> desiredSlots = List<String>.from(
              (bookingDataWithVerification['timeSlots'] as List?) ?? const []);
          final String desiredDate = (bookingDataWithVerification['date'] ?? '').toString().split('T').first;
          final candidates = existingBookings.cast<Map<String, dynamic>>().where((b) {
            final name = norm(b['courtName']?.toString());
            final sameName = name == scannedCourtName || name.contains(scannedCourtName) || scannedCourtName.contains(name);
            if (!sameName) return false;
            // check time overlap if present
            final List<String> bSlots = List<String>.from((b['timeSlots'] as List?) ?? const []);
            final bool slotOverlap = desiredSlots.isEmpty || bSlots.any((s) => desiredSlots.contains(s));
            // check same day if present
            final String bDate = (b['date'] ?? '').toString().split('T').first;
            final bool sameDay = desiredDate.isEmpty || bDate == desiredDate;
            return slotOverlap && sameDay;
          }).toList();
          if (candidates.isNotEmpty) target = candidates.first;
        }

        // 3) Final fallback: if exactly 1 pending exists today, assume it's the same booking
        if (target.isEmpty && existingBookings.length == 1) {
          target = existingBookings.first as Map<String, dynamic>;
        }

        if (target.isEmpty) {
          _showErrorDialog(
            'QR Code ไม่ตรงกับการจองที่มีอยู่\n\n'
            'การจองที่มีอยู่: ${existingBookings.map((b) => b['courtName']).join(', ')}\n'
            'QR Code ที่สแกน: ${bookingDataWithVerification['courtName']}\n\n'
            'กรุณาสแกน QR Code ของสนามที่คุณจองไว้'
          );
          return;
        }

        // เมื่อ QR Code ตรงกัน ให้เช็คอินโดยอัปเดตสถานะการจองที่มีอยู่
        final bookingId = target['id']?.toString();
        if (bookingId == null || bookingId.isEmpty) {
          _showErrorDialog('ไม่พบหมายเลขการจองที่ต้องเช็คอิน');
          return;
        }
        print('✅ Check-in for existing booking ID: $bookingId');
        await _checkInBooking(bookingId);
      } else {
        _showErrorDialog(response['error'] ?? 'เกิดข้อผิดพลาดในการจองสนาม');
      }
    } catch (e) {
      setState(() {
        isSubmittingBooking = false;
      });
      _showErrorDialog('เกิดข้อผิดพลาด: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('เกิดข้อผิดพลาด'),
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

  void _showQRReadResult(String scannedData) {
    // Keep this function intentionally small: treat QR payload as plain text court name.
    final detectedCourt = _sanitize(scannedData);
    final expectedCourt = widget.bookingData['courtName'] ?? 'ไม่ระบุ';
    final expectedNorm = _normalize(expectedCourt.toString());
    final scannedNorm = _normalize(detectedCourt);
    final bool isMatch = expectedNorm.isNotEmpty && scannedNorm == expectedNorm;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isMatch ? Icons.qr_code_scanner : Icons.qr_code_2,
              color: isMatch ? Colors.green : Colors.orange,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'ผลการอ่าน QR Code',
                style: TextStyle(
                  color: isMatch ? Colors.green[700] : Colors.orange[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMatch ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMatch ? Colors.green[200]! : Colors.orange[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สนามที่ตรวจพบ: $detectedCourt',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('สนามที่ต้องการ: $expectedCourt'),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        isMatch ? Icons.check_circle : Icons.warning,
                        color: isMatch ? Colors.green[600] : Colors.orange[600],
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isMatch 
                            ? 'QR Code ตรงกับสนามที่จอง ✓'
                            : 'QR Code ไม่ตรงกับสนามที่จอง',
                          style: TextStyle(
                            color: isMatch ? Colors.green[700] : Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isMatch) ...[
              SizedBox(height: 12),
              Text(
                'กรุณาตรวจสอบว่าคุณอยู่ที่สนามที่ถูกต้องและแสกน QR Code อีกครั้ง',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'ตกลง',
              style: TextStyle(
                color: isMatch ? Colors.green[600] : Colors.orange[600],
              ),
            ),
          ),
          if (!isMatch)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _scanQRCode(); // Allow user to scan again
              },
              child: Text(
                'แสกนใหม่',
                style: TextStyle(color: Colors.blue[600]),
              ),
            ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'เช็คอินสำเร็จ!',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green[600], size: 20),
                      SizedBox(width: 8),
                      Text(
                        'สถานะการจอง: เช็คอินเรียบร้อยแล้ว',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'คุณได้เข้าใช้สนามเรียบร้อยแล้ว สามารถเริ่มการเล่นได้ตามเวลาที่กำหนด',
                    style: TextStyle(color: Colors.green[600]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text('รายละเอียดการจอง:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            _buildBookingDetailRow('สนาม', widget.bookingData['courtName'] ?? 'ไม่ระบุ'),
            _buildBookingDetailRow('วันที่', widget.bookingData['date'] ?? 'ไม่ระบุ'),
            _buildBookingDetailRow('เวลา', (widget.bookingData['timeSlots'] as List).join(', ')),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'การจองนี้พร้อมใช้งานทันที ไม่ต้องรอการอนุมัติ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BookingHistoryPage()),
              );
            },
            child: Text('ดูประวัติการจอง'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserHomePage(username: 'User')),
              );
            },
            child: Text('กลับหน้าหลัก'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = widget.bookingData['status'] ?? BookingStatus.pending;
    final canCancel = BookingStatus.canCancel(currentStatus);
    
    return Scaffold(
      backgroundColor: Color(0xFFF0F8FF),
      appBar: AppBar(
        backgroundColor: Colors.teal[700],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ยืนยันสถานะการจอง',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '${BookingStatus.statusIcons[currentStatus]} ${BookingStatus.statusMessages[currentStatus]}',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (canCancel)
            IconButton(
              icon: Icon(Icons.cancel_outlined, color: Colors.white),
              onPressed: _showCancelDialog,
              tooltip: 'ยกเลิกการจอง',
            ),
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showStatusInfo,
            tooltip: 'ข้อมูลสถานะ',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusCard(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: widget.isRegularBooking ? _buildRegularBookingFlow() : _buildActivityBookingFlow(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegularBookingFlow() {
    // แสดง loading ขณะโหลด settings
    if (isLoadingSettings) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('กำลังโหลดการตั้งค่า...'),
          ],
        ),
      );
    }

    // สร้าง steps แบบ dynamic ตาม settings
    List<Step> steps = [];
    int stepIndex = 0;

    // Step 0: QR Code (ถ้าเปิดใช้งาน)
    if (requireQR) {
      steps.add(Step(
        title: Text('แสกน QR Code'),
        content: _buildQRScanStep(),
        isActive: currentStep >= stepIndex,
        state: currentStep > stepIndex ? StepState.complete : StepState.indexed,
      ));
      stepIndex++;
    }

    // Step 1: Location (ถ้าเปิดใช้งาน)
    if (requireLocation) {
      final locationStepIndex = stepIndex;
      steps.add(Step(
        title: Text('ยืนยันตำแหน่ง'),
        content: _buildLocationVerificationStep(),
        isActive: currentStep >= locationStepIndex,
        state: currentStep > locationStepIndex ? StepState.complete : 
               currentStep == locationStepIndex ? StepState.indexed : StepState.disabled,
      ));
      stepIndex++;
    }

    // Step 2: Submit Booking (เสมอ)
    final submitStepIndex = stepIndex;
    steps.add(Step(
      title: Text('บันทึกการจอง'),
      content: _buildSubmitBookingStep(),
      isActive: currentStep >= submitStepIndex,
      state: currentStep > submitStepIndex ? StepState.complete : 
             currentStep == submitStepIndex ? StepState.indexed : StepState.disabled,
    ));
    stepIndex++;

    // Step 3: Completion (เสมอ)
    final completionStepIndex = stepIndex;
    steps.add(Step(
      title: Text('เสร็จสิ้น'),
      content: _buildCompletionStep(),
      isActive: currentStep >= completionStepIndex,
      state: currentStep == completionStepIndex ? StepState.complete : StepState.disabled,
    ));

    return Stepper(
      currentStep: currentStep,
      onStepTapped: (step) {
        if (step <= currentStep) {
          setState(() {
            currentStep = step;
          });
        }
      },
      steps: steps,
    );
  }

  Widget _buildActivityBookingFlow() {
    return Column(
      children: [
        Expanded(
          child: _buildSubmitBookingStep(),
        ),
        Container(
          padding: EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: isSubmittingBooking ? null : _submitBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              minimumSize: Size(double.infinity, 48),
            ),
            child: isSubmittingBooking
                ? CircularProgressIndicator(color: Colors.white)
                : Text('บันทึกการจองกิจกรรม', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildQRScanStep() {
    return Column(
      children: [
        // ไม่แสดง QR ภายในหน้าเช็คอิน
        // แสดงปุ่มให้เลือกแสกนด้วยกล้อง หรือ อัปโหลดรูปได้ทันที
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: isScanning
                  ? null
                  : () {
                      setState(() {
                        // บังคับโหมดอัปโหลดเสมอ (ไม่ใช้สแกนกล้อง)
                        isUploadMode = true;
                      });
                      _scanQRCode();
                    },
              icon: Icon(Icons.upload_file, color: Colors.teal[700]),
              label: Text('อัปโหลดรูป QR Code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal[700],
                side: BorderSide(color: Colors.teal[700]!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationVerificationStep() {
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
          Icon(
            isVerifyingLocation 
                ? Icons.location_searching 
                : locationVerificationResult?['success'] == true
                    ? Icons.location_on
                    : Icons.location_off,
            size: 64,
            color: isVerifyingLocation 
                ? Colors.orange 
                : locationVerificationResult?['success'] == true
                    ? Colors.green
                    : Colors.red,
          ),
          SizedBox(height: 16),
          Text(
            isVerifyingLocation 
                ? 'กำลังตรวจสอบตำแหน่ง...'
                : locationVerificationResult?['success'] == true
                    ? 'ยืนยันตำแหน่งสำเร็จ'
                    : 'ไม่สามารถยืนยันตำแหน่งได้',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isVerifyingLocation 
                  ? Colors.orange 
                  : locationVerificationResult?['success'] == true
                      ? Colors.green
                      : Colors.red,
            ),
          ),
          SizedBox(height: 8),
          if (locationVerificationResult != null)
            Text(
              locationVerificationResult!['message'],
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          SizedBox(height: 12),
          if (locationVerificationResult != null &&
              locationVerificationResult!['userLocation'] != null)
            MapLocationViewer(
              location: LatLng(
                (locationVerificationResult!['userLocation']['latitude'] as num).toDouble(),
                (locationVerificationResult!['userLocation']['longitude'] as num).toDouble(),
              ),
              title: 'ตำแหน่งของคุณ (อ่านจาก GPS) - ตรวจสอบความถูกต้อง',
              zoom: 16.0,
              height: 220,
            ),
          if (isVerifyingLocation)
            Padding(
              padding: EdgeInsets.only(top: 16),
              child: CircularProgressIndicator(),
            ),
          if (!isVerifyingLocation)
            Padding(
              padding: EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (locationVerificationResult != null && locationVerificationResult!['success'] == true)
                          ? null
                          : _proceedToLocationVerification,
                      icon: Icon(Icons.my_location),
                      label: Text((locationVerificationResult != null && locationVerificationResult!['success'] == true)
                          ? 'ตำแหน่งยืนยันแล้ว'
                          : 'ยืนยันตำแหน่ง'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // ปุ่มรีเฟรชตำแหน่งขนาดเล็ก สำหรับให้ผู้ใช้กดเพื่อเรียกการตรวจสอบตำแหน่งซ้ำ
                  Container(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: isVerifyingLocation ? null : _proceedToLocationVerification,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal[700],
                        minimumSize: Size(48, 48),
                        padding: EdgeInsets.zero,
                      ),
                      child: Icon(Icons.refresh, color: Colors.teal[700]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitBookingStep() {
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
          _buildBookingDetailRow('สนาม', widget.bookingData['courtName']),
          _buildBookingDetailRow('วันที่', widget.bookingData['date']),
          _buildBookingDetailRow('เวลา', (widget.bookingData['timeSlots'] as List).join(', ')),
          _buildBookingDetailRow(
            'ประเภทการจอง', 
            widget.isRegularBooking ? 'การจองปกติ' : 'การจองกิจกรรม'
          ),
          if (widget.isRegularBooking) ...[
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.qr_code, color: Colors.green),
                SizedBox(width: 8),
                Text('QR Code: ยืนยันแล้ว', style: TextStyle(color: Colors.green)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.green),
                SizedBox(width: 8),
                Text('ตำแหน่ง: ยืนยันแล้ว', style: TextStyle(color: Colors.green)),
              ],
            ),
          ],
          if (isSubmittingBooking) ...[
            SizedBox(height: 16),
            Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionStep() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text(
            'การจองเสร็จสมบูรณ์!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'คุณสามารถดูรายละเอียดการจองในหน้าประวัติการจอง',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // เช็คอินโดยอัปเดตสถานะการจอง
  Future<void> _checkInBooking(String bookingId) async {
    print('🔄 _checkInBooking called for booking ID: $bookingId');
    
    setState(() {
      isSubmittingBooking = true;
    });

    try {
      final response = await BookingService.updateBookingStatus(
        bookingId: bookingId,
        status: BookingStatus.checkedIn,
      );

      if (response['success']) {
        setState(() {
          // คำนวณ completion step index
          int completionStepIndex = 0;
          if (requireQR) completionStepIndex++;
          if (requireLocation) completionStepIndex++;
          completionStepIndex++; // submit step
          currentStep = completionStepIndex;
        });
        _showSuccessDialog();
      } else {
        _showErrorDialog(response['error'] ?? 'เกิดข้อผิดพลาดในการเช็คอิน');
      }
    } catch (e) {
      _showErrorDialog('เกิดข้อผิดพลาด: ${e.toString()}');
    } finally {
      setState(() {
        isSubmittingBooking = false;
      });
    }
  }
}
