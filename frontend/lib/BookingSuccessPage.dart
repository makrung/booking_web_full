import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'UserHomePage.dart';
import 'QRLocationCheckPage.dart';
import 'services/content_service.dart';
import 'services/auth_service.dart';

class BookingSuccessPage extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const BookingSuccessPage({Key? key, required this.bookingData}) : super(key: key);

  @override
  _BookingSuccessPageState createState() => _BookingSuccessPageState();
}

class _BookingSuccessPageState extends State<BookingSuccessPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _checkmarkController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkmarkAnimation;
  int _autoCancelPenaltyPoints = 50; // will be loaded from settings
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _checkmarkController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut)
    );
    
    _checkmarkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkmarkController, curve: Curves.easeInOut)
    );
    
    _animationController.forward();
    Future.delayed(Duration(milliseconds: 400), () {
      _checkmarkController.forward();
    });

    _loadPenaltySetting();
    _initAdminFlag();
  }
  Future<void> _initAdminFlag() async {
    // seed from bookingData then confirm via auth
    bool seed = (widget.bookingData['isAdmin'] == true);
    try {
      final isAdmin = await AuthService.isAdmin();
      if (mounted) setState(() { _isAdmin = seed || isAdmin; });
    } catch (_) {
      if (mounted) setState(() { _isAdmin = seed; });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _checkmarkController.dispose();
    super.dispose();
  }

  Future<void> _loadPenaltySetting() async {
    try {
      // Admin can change this via Admin Settings (stored in settings collection)
      final v = await ContentService.getContent('penalty_no_checkin_auto_cancel');
      if (!mounted) return;
      final n = int.tryParse((v ?? '').toString());
      if (n != null && n >= 0) {
        setState(() {
          _autoCancelPenaltyPoints = n;
        });
      }
    } catch (_) {
      // keep default
    }
  }

  @override
  Widget build(BuildContext context) {
  // แอดมิน: ซ่อนปุ่มเช็คอินและแสดงปุ่มตกลงอย่างเดียว
  final bool isAdmin = _isAdmin;
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        title: Text(
          'จองสำเร็จ!',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(height: 20),
              
              // Success Animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _checkmarkAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: CheckmarkPainter(progress: _checkmarkAnimation.value),
                        child: Container(),
                      );
                    },
                  ),
                ),
              ),
              
              SizedBox(height: 30),
              
              Text(
                '🎉 จองสำเร็จแล้ว!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 10),
              
              Text(
                isAdmin
                  ? 'การจองของคุณถูกบันทึกเรียบร้อยแล้ว'
                  : 'การจองของคุณได้รับการยืนยันแล้ว\nกรุณามาเช็คอินตรงเวลา',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 30),
              
              // Booking Details Card
              _buildBookingDetailsCard(),
              
              SizedBox(height: 30),
              
              // Warning Box (ซ่อนสำหรับแอดมิน)
              if (!isAdmin) Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[300]!, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange[600],
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'สำคัญ!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'หากไม่ได้มาเช็คอินตรงเวลา คุณจะถูกหักคะแนน ${_autoCancelPenaltyPoints} คะแนน',
                            style: TextStyle(
                              color: Colors.orange[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 30),
              
              // Action Buttons
              Column(
                children: [
                  // ปุ่มหลัก: สำหรับแอดมิน ให้เป็นปุ่ม 'ตกลง' เด้งกลับทันที
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _goToHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAdmin ? Colors.teal : Colors.green[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        isAdmin ? 'ตกลง' : 'กลับหน้าหลัก',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (!isAdmin) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _goToCheckIn,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('ไปหน้าเช็คอิน'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal[700],
                          side: BorderSide(color: Colors.teal[300]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingDetailsCard() {
    final date = DateTime.parse(widget.bookingData['date']);
    final isActivity = _isActivityBooking();
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'รายละเอียดการจอง',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          
          SizedBox(height: 16),
          
          _buildDetailRow(
            'ประเภท',
            isActivity ? '🎯 กิจกรรม' : '🏃‍♂️ การจองทั่วไป',
            Icons.category,
          ),
          
          _buildDetailRow(
            'สนาม',
            widget.bookingData['courtName'] ?? 'ไม่ระบุ',
            Icons.sports_tennis,
          ),
          
          _buildDetailRow(
            'วันที่',
            DateFormat('EEEE dd MMMM yyyy', 'th').format(date),
            Icons.calendar_today,
          ),
          
          _buildDetailRow(
            'เวลา',
            (widget.bookingData['timeSlots'] as List?)?.join(', ') ?? 
            widget.bookingData['timeSlotDisplay'] ?? 'ไม่ระบุ',
            Icons.access_time,
          ),
          
          _buildDetailRow(
            'กีฬา',
            widget.bookingData['activityType'] ?? 'ไม่ระบุ',
            Icons.sports,
          ),
          
          if (widget.bookingData['note']?.isNotEmpty == true)
            _buildDetailRow(
              'หมายเหตุ',
              widget.bookingData['note'],
              Icons.note,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.green[600],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isActivityBooking() {
    return widget.bookingData['bookingType'] == 'activity';
  }

  // ปุ่มเช็คอินถูกถอดสำหรับแอดมิน; ผู้ใช้ทั่วไปเช็คอินจากหน้าหลังได้

  void _goToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => UserHomePage(username: 'User'),
      ),
      (route) => false,
    );
  }

  void _goToCheckIn() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QRLocationCheckPage()),
    );
  }
}

// Custom Painter สำหรับ Checkmark Animation
class CheckmarkPainter extends CustomPainter {
  final double progress;

  CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final checkmarkPath = Path();

    // เส้นทางของ checkmark
    final startPoint = Offset(center.dx - 15, center.dy);
    final middlePoint = Offset(center.dx - 5, center.dy + 10);
    final endPoint = Offset(center.dx + 15, center.dy - 10);

    if (progress >= 0.0) {
      checkmarkPath.moveTo(startPoint.dx, startPoint.dy);
      
      if (progress <= 0.5) {
        // วาดเส้นแรก
        final currentPoint = Offset.lerp(startPoint, middlePoint, progress * 2)!;
        checkmarkPath.lineTo(currentPoint.dx, currentPoint.dy);
      } else {
        // วาดเส้นแรกเสร็จแล้ว วาดเส้นที่สอง
        checkmarkPath.lineTo(middlePoint.dx, middlePoint.dy);
        final currentPoint = Offset.lerp(middlePoint, endPoint, (progress - 0.5) * 2)!;
        checkmarkPath.lineTo(currentPoint.dx, currentPoint.dy);
      }
    }

    canvas.drawPath(checkmarkPath, paint);
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
