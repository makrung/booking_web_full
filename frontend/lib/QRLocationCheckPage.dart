import 'package:flutter/material.dart';
import 'services/booking_service.dart';
import 'services/settings_service.dart';
import 'models/app_constants.dart';
import 'package:intl/intl.dart';
import 'QRLocationVerificationPage.dart';

class QRLocationCheckPage extends StatefulWidget {
  @override
  _QRLocationCheckPageState createState() => _QRLocationCheckPageState();
}

class _QRLocationCheckPageState extends State<QRLocationCheckPage> {
  List<dynamic> bookings = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await BookingService.getUserBookings();
      if (result['success']) {
        // กรองเฉพาะการจองที่ยังไม่ได้เช็คอิน และเป็นการจองปกติ
        final today = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(today);
        
  // debug logs removed for production
        
        // Determine test mode (prefer notifier for immediacy)
        final storedTestMode = await SettingsService.isTestModeEnabled();
        final isTestMode = SettingsService.testModeNotifier.value || storedTestMode;

        final filteredBookings = (result['bookings'] as List).where((booking) {
          final bookingDate = booking['date'];

          // แปลงวันที่การจองให้เป็นรูปแบบ yyyy-MM-dd
          String bookingDateStr;
          if (bookingDate.toString().contains('T')) {
            bookingDateStr = bookingDate.split('T')[0];
          } else {
            bookingDateStr = bookingDate.toString();
          }

          final isRegular = booking['bookingType'] == 'regular';
          final isNotCheckedIn = (booking['isLocationVerified'] != true && booking['isQRVerified'] != true);

          // ตรวจสอบว่าไม่ได้อยู่ในสถานะที่ไม่ควรแสดงในหน้าเช็คอิน
          final status = booking['status'];
          final isValidForCheckIn = status != BookingStatus.cancelled &&
              status != BookingStatus.expired &&
              status != BookingStatus.noShow &&
              status != BookingStatus.completed &&
              status != BookingStatus.penalized;

          if (isTestMode) {
            // In test mode: show pending regular bookings regardless of date
            return isRegular && isNotCheckedIn && isValidForCheckIn;
          } else {
            // Normal mode: show only today's regular bookings
            final isToday = bookingDateStr == todayStr;
            return isToday && isRegular && isNotCheckedIn && isValidForCheckIn;
          }
        }).toList();

        print('Filtered bookings: ${filteredBookings.length}');

        setState(() {
          bookings = filteredBookings;
          isLoading = false;
        });
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F8FF),
      appBar: AppBar(
        backgroundColor: Colors.teal[700],
        title: Text(
          'เช็คอิน QR & ตำแหน่ง',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ข้อมูลคำอธิบาย
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700]),
                    SizedBox(width: 8),
                    Text(
                      'วิธีการเช็คอิน',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '1. เลือกการจองที่ต้องการเช็คอิน\n'
                  '2. ไปยังสนามที่จอง\n'
                  '3. แสกน QR Code ที่สนาม\n'
                  '4. ยืนยันตำแหน่งของคุณ\n'
                  '5. เริ่มใช้สนามได้ทันที',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
          ),

          // รายการการจอง
          Expanded(
            child: _buildBookingsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'เกิดข้อผิดพลาด',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(error!, textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBookings,
              child: Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'ไม่มีการจองที่ต้องเช็คอิน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'คุณได้เช็คอินครบทุกการจองแล้ว\nหรือไม่มีการจองในวันนี้',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        return _buildBookingCard(bookings[index]);
      },
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final timeSlots = booking['timeSlots'] is List 
        ? (booking['timeSlots'] as List).join(', ')
        : booking['timeSlots']?.toString() ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _startCheckIn(booking),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'รอเช็คอิน',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.qr_code_scanner, color: Colors.grey[600]),
                ],
              ),
              SizedBox(height: 12),
              Text(
                booking['courtName'] ?? '',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    _formatDate(booking['date']),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    timeSlots,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startCheckIn(booking),
                  icon: Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: Text(
                    'เริ่มเช็คอิน',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startCheckIn(Map<String, dynamic> booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRLocationVerificationPage(
          bookingData: booking,
          isRegularBooking: true,
        ),
      ),
    ).then((_) {
      // รีเฟรชข้อมูลเมื่อกลับมา
      _loadBookings();
    });
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
