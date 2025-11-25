import 'package:flutter/material.dart';
import 'package:booking_web_full/Schedule.dart';
import 'BookingSelectionPage.dart';
import 'NewBookingHistory.dart';
import 'QRLocationCheckPage.dart';
import 'services/auth_service.dart';
import 'services/penalty_service.dart';
import 'Login.dart';
import 'NewsPage.dart';
import 'services/news_service.dart';
import 'models/news.dart';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'ProfilePage.dart';
import 'services/points_service.dart';
import 'PenaltyHistoryPage.dart';
import 'dart:async';
import 'RequestsStatusPage.dart';
import 'services/booking_service.dart';
import 'services/content_service.dart';
import 'BookingRulesPage.dart';

class UserHomePage extends StatefulWidget {
  final String username;

  const UserHomePage({super.key, required this.username});

  @override
  _UserHomePageState createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  int currentPoints = 0;
  List<dynamic> upcomingBookings = [];
  bool hasCheckedPenalties = false;
  NewsItem? _latestNews;
  Map<String, dynamic>? _me;
  String? _userCode;
  int _unreadInbox = 0;
  Timer? _inboxTimer;
  int _lastUnread = 0;
  // Booking eligibility / countdown
  Timer? _eligibilityTimer;
  int _secondsUntilReset = 0;
  bool _usedToday = false;
  bool _canBookToday = true;
  int _dailyRights = 1;
  int _remainingRights = 1;
  bool _loadingEligibility = true;
  String? _eligibilityError;
  String? _contactInfoText;
  bool _blockedByDomainPolicy = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _checkAuthPersistence();
    _loadMe();
    _loadUnread();
    _startInboxPolling();
    _loadBookingEligibility();
    _loadContactInfo();
    _loadDomainPolicy();
  }

  Future<void> _checkAuthPersistence() async {
    // ตรวจสอบว่ายังล็อกอินอยู่หรือไม่
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn && mounted) {
      // ถ้าไม่ได้ล็อกอินแล้วให้กลับไปหน้าหลัก
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
  }

  Future<void> _initializeData() async {
    await _checkPenaltiesAndPoints();
    await _loadUpcomingBookings();
    await _loadLatestNews();
  }

  Future<void> _checkPenaltiesAndPoints() async {
    try {
      // ตรวจสอบคะแนนโทษ
      final penaltyResult = await PenaltyService.checkAndApplyPenalties();
      if (penaltyResult['success'] && penaltyResult['totalPenaltyPoints'] > 0) {
        _showPenaltyAlert(penaltyResult['totalPenaltyPoints'], penaltyResult['expiredBookings']);
      }

      // ดึงคะแนนปัจจุบัน
      final pointsResult = await PenaltyService.getCurrentPoints();
      if (pointsResult['success']) {
        setState(() {
          currentPoints = pointsResult['points'];
        });
      }
    } catch (e) {
      print('Error checking penalties: $e');
    }
  }

  Future<void> _loadLatestNews() async {
    try {
      final latest = await NewsService.latest();
      if (mounted) setState(() => _latestNews = latest);
    } catch (e) {
      // ignore silently on user home
    }
  }

  bool _isUniversityEmail(String email) {
    final e = email.toLowerCase().trim();
    return e.endsWith('@silpakorn.edu') || e.endsWith('@su.ac.th');
  }

  Future<void> _loadDomainPolicy() async {
    try {
      final me = await AuthService.getCurrentUser();
      final meta = await ContentService.getContentWithMeta('allow_non_university_booking');
      final allowStr = (meta['value'] ?? '1').toString().toLowerCase();
      final allow = allowStr == '1' || allowStr == 'true';
      final isAdmin = (me?['role'] ?? '') == 'admin';
      final email = (me?['email'] ?? '').toString();
      final isUni = email.isNotEmpty && _isUniversityEmail(email);
      if (mounted) setState(() {
        _blockedByDomainPolicy = !allow && !isAdmin && !isUni;
      });
    } catch (_) {
      if (mounted) setState(() { _blockedByDomainPolicy = false; });
    }
  }

  Future<void> _loadUpcomingBookings() async {
    try {
      final result = await PenaltyService.getUpcomingBookings();
      if (result['success']) {
        setState(() {
          upcomingBookings = result['upcomingBookings'];
        });
        
        if (upcomingBookings.isNotEmpty) {
          _showUpcomingBookingsAlert();
        }
      }
    } catch (e) {
      print('Error loading upcoming bookings: $e');
    }
  }

  Future<void> _loadMe() async {
    try {
      final me = await AuthService.getCurrentUser();
      if (mounted) setState(() {
        _me = me;
        _userCode = me?['userCode']?.toString();
      });
    } catch (_) {}
  }

  Future<void> _loadUnread() async {
    try {
      final n = await PointsService.unreadMessagesCount();
      if (!mounted) return;
      setState(() { _unreadInbox = n; });
    } catch (_) {}
  }

  void _startInboxPolling() {
    _inboxTimer?.cancel();
    _lastUnread = _unreadInbox;
    _inboxTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        final n = await PointsService.unreadMessagesCount();
        if (!mounted) return;
        if (n > _lastUnread) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('มีข้อความใหม่ในกล่องข้อความ'),
              action: SnackBarAction(
                label: 'เปิด',
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesPage()));
                  await _loadUnread();
                },
              ),
            ),
          );
        }
        setState(() {
          _unreadInbox = n;
          _lastUnread = n;
        });
      } catch (_) {}
    });
  }

  Future<void> _loadBookingEligibility() async {
    try {
      setState(() { _loadingEligibility = true; _eligibilityError = null; });
    final res = await BookingService.getCodeStatus();
    final used = (res['usedToday'] == true);
    final dailyRights = int.tryParse((res['dailyRights'] ?? '1').toString()) ?? 1;
    final remainingRights = int.tryParse((res['remainingRights'] ?? (used ? 0 : 1)).toString()) ?? (used ? 0 : 1);
    // ความพร้อมในการจองควรยึดตามสิทธิ์ที่เหลือจริง ไม่ใช่เพียง usedToday
    final canBook = (remainingRights > 0);
      final seconds = (res['secondsUntilReset'] ?? 0) is int
          ? (res['secondsUntilReset'] as int)
          : int.tryParse((res['secondsUntilReset'] ?? '0').toString()) ?? 0;
      setState(() {
        _usedToday = used;
        _canBookToday = canBook;
        _secondsUntilReset = seconds;
        _dailyRights = dailyRights;
        _remainingRights = remainingRights;
        _loadingEligibility = false;
      });
      _startEligibilityCountdown();
    } catch (e) {
      setState(() {
        _eligibilityError = e.toString();
        _loadingEligibility = false;
      });
    }
  }

  void _startEligibilityCountdown() {
    _eligibilityTimer?.cancel();
    if (_secondsUntilReset <= 0) return;
    _eligibilityTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsUntilReset <= 1) {
        setState(() {
          _secondsUntilReset = 0;
          _usedToday = false;
          _canBookToday = true;
          _remainingRights = _dailyRights;
        });
        t.cancel();
      } else {
        setState(() { _secondsUntilReset -= 1; });
      }
    });
  }

  String _formatHMS(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  void _showEligibilityPanel() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      pageBuilder: (ctx, a1, a2) {
        final double topOffset = MediaQuery.of(ctx).padding.top + kToolbarHeight + 8;
        return SafeArea(
          child: Stack(
            children: [
              Positioned(
                right: 12,
                top: topOffset,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 360,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock_clock, color: Colors.teal[700]),
                            const SizedBox(width: 8),
                            Text('สถานะสิทธิการจองวันนี้', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[800])),
                            const Spacer(),
                            IconButton(
                              tooltip: 'ปิด',
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildBookingEligibilityCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 150),
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.05, -0.05), end: Offset.zero).animate(anim),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildEligibilityPill() {
    Widget child;
    if (_loadingEligibility) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 6),
          Text('กำลังตรวจสอบ...', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      );
    } else if (_eligibilityError != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.error_outline, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text('สถานะไม่พร้อม', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      );
    } else if (_blockedByDomainPolicy) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.block, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text('จำกัดเฉพาะอีเมลมหาวิทยาลัย', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      );
    } else if (_canBookToday) {
      final hasCountdown = _secondsUntilReset > 0;
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text('พร้อมจอง (${_remainingRights}/${_dailyRights})', style: const TextStyle(color: Colors.white, fontSize: 12)),
          if (hasCountdown) ...[
            const SizedBox(width: 8),
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('รีเซ็ตสิทธิในอีก ${_formatHMS(_secondsUntilReset)}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ],
      );
    } else {
    final text = _secondsUntilReset > 0
      ? 'ใช้ครบแล้ว (0/${_dailyRights}) · รีเซ็ตใน ${_formatHMS(_secondsUntilReset)}'
      : 'ใช้ครบแล้ว (0/${_dailyRights}) · รอรีเซ็ต';
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _showEligibilityPanel,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBookingEligibilityCard() {
    if (_loadingEligibility) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('กำลังตรวจสอบสิทธิการจองวันนี้...')),
          ],
        ),
      );
    }

    if (_eligibilityError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('ไม่สามารถตรวจสอบสิทธิการจองได้', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(_eligibilityError!),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _loadBookingEligibility,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองอีกครั้ง'),
              ),
            )
          ],
        ),
      );
    }

    if (_canBookToday && !_blockedByDomainPolicy) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text('วันนี้คุณสามารถจองได้ (${_remainingRights}/${_dailyRights})', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (_secondsUntilReset > 0) ...[
              const SizedBox(height: 6),
              Text('สิทธิจะรีเซ็ตใน ${_formatHMS(_secondsUntilReset)}'),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BookingSelectionPage()),
                  );
                },
                icon: const Icon(Icons.sports_soccer),
                label: const Text('ไปจองเลย'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[600]),
              ),
            )
          ],
        ),
      );
    }

    // Not eligible (already used today or blocked)
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
        _blockedByDomainPolicy
          ? 'ชั่วคราว: จำกัดการจองเฉพาะอีเมลมหาวิทยาลัย'
          : (_usedToday
            ? 'วันนี้คุณใช้สิทธิครบแล้ว (0/${_dailyRights})'
            : 'วันนี้ยังไม่สามารถจองได้'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_blockedByDomainPolicy) ...[
            const Text('ขณะนี้ผู้ใช้ที่ไม่ใช่อีเมลของทางมหาวิทยาลัยไม่สามารถทำการจองได้ชั่วคราว'),
          ] else ...[
          if (_secondsUntilReset > 0)
            Text('รอรีเซ็ตภายใน ${_formatHMS(_secondsUntilReset)}'),
          if (_secondsUntilReset == 0)
            const Text('โปรดลองใหม่อีกครั้งในภายหลัง')
          ]
        ],
      ),
    );
  }

  void _showPenaltyAlert(int totalPenalty, List<dynamic> expiredBookings) {
    if (totalPenalty > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('แจ้งเตือนคะแนนโทษ'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('คุณถูกหักคะแนน $totalPenalty คะแนน'),
              SizedBox(height: 8),
              Text('เนื่องจากไม่ได้มายืนยันการจองในเวลาที่กำหนด:'),
              SizedBox(height: 8),
              ...expiredBookings.map((booking) => Text(
                '• ${booking['courtName']} วันที่ ${booking['date']}',
                style: TextStyle(fontSize: 12),
              )),
              SizedBox(height: 8),
              Text('คะแนนปัจจุบัน: $currentPoints คะแนน'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('รับทราบ'),
            ),
          ],
        ),
      );
    }
  }

  void _showUpcomingBookingsAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.schedule, color: Colors.blue),
            SizedBox(width: 8),
            Text('การจองที่ต้องยืนยัน'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('คุณมีการจองที่ต้องยืนยันด้วย QR Code:'),
            SizedBox(height: 8),
            ...upcomingBookings.map((booking) => ListTile(
              leading: Icon(Icons.sports_tennis),
              title: Text(booking['courtName']),
              subtitle: Text('${booking['date']} ${booking['timeSlots'].join(', ')}'),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ภายหลัง'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => QRLocationCheckPage()),
              );
            },
            child: Text('ยืนยันเลย'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการออกจากระบบ'),
        content: Text('คุณต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // ปิด dialog
              
              // แสดง loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(child: CircularProgressIndicator()),
              );
              
              try {
                await AuthService.logout();
                Navigator.pop(context); // ปิด loading
                
                // นำทางไปหน้า login
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginPage()),
                  (route) => false,
                );
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('ออกจากระบบสำเร็จ'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context); // ปิด loading
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('เกิดข้อผิดพลาด: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('ออกจากระบบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showContactInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.contact_support, color: Colors.teal[700]),
            SizedBox(width: 10),
            Text('ข้อมูลติดต่อ'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((_contactInfoText ?? '').trim().isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(_contactInfoText!, style: TextStyle(fontSize: 14, height: 1.35, color: Colors.grey[800])),
                )
              else ...[
                ListTile(
                  leading: Icon(Icons.location_on, color: Colors.teal),
                  title: Text('ที่ตั้ง'),
                  subtitle: Text('มหาวิทยาลัยศิลปากร วิทยาเขตพระราชวังสนามจันทร์'),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: Icon(Icons.phone, color: Colors.teal),
                  title: Text('โทรศัพท์'),
                  subtitle: Text('034-255-800'),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: Icon(Icons.email, color: Colors.teal),
                  title: Text('อีเมล'),
                  subtitle: Text('stadium@su.ac.th'),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: Icon(Icons.access_time, color: Colors.teal),
                  title: Text('เวลาทำการ'),
                  subtitle: Text('จันทร์ - ศุกร์ 08:00 - 20:00\nเสาร์ - อาทิตย์ 08:00 - 18:00'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadContactInfo() async {
    try {
      final v = await ContentService.getContent('contact_info_text');
      if (mounted) setState(() { _contactInfoText = v; });
    } catch (_) {}
  }

  @override
  void dispose() {
    _inboxTimer?.cancel();
    _eligibilityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F8FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.teal[700],
            actions: [
              // Eligibility status at top-right
              _buildEligibilityPill(),
              IconButton(
                tooltip: 'ติดตามสถานะคำขอ',
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsStatusPage()));
                },
                icon: const Icon(Icons.receipt_long, color: Colors.white),
              ),
              // Inbox icon with unread badge
              IconButton(
                tooltip: 'กล่องข้อความ',
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesPage()));
                  try { await PointsService.markAllMessagesRead(); } catch (_) {}
                  await _loadUnread();
                },
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.mail, color: Colors.white),
                    if (_unreadInbox > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                          child: Text('$_unreadInbox', style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.account_circle, color: Colors.white),
                onSelected: (value) async {
                  if (value == 'logout') {
                    await _handleLogout(context);
                  } else if (value == 'profile') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                    await _loadMe();
                  } else if (value == 'messages') {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesPage()));
                  } else if (value == 'requests_status') {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsStatusPage()));
                   }
                 },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.teal),
                        SizedBox(width: 8),
                        Text('โปรไฟล์ของฉัน'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'messages',
                    child: Row(
                      children: [
                        Icon(Icons.mail, color: Colors.teal),
                        SizedBox(width: 8),
                        Text('กล่องข้อความ'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'requests_status',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.teal),
                        SizedBox(width: 8),
                        Text('ติดตามสถานะคำขอ'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text('ออกจากระบบ'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SILPAKORN STADIUM',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'คะแนนปัจจุบัน: $currentPoints คะแนน',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    if (_userCode != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'รหัสของฉัน: ${_userCode!}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1.2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(text: _userCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('คัดลอกรหัสแล้ว')),
                              );
                            },
                            child: const Icon(Icons.copy, size: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    Text(
                      'ระบบจองสนามกีฬา มหาวิทยาลัยศิลปากร',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.teal[700]!,
                      Colors.teal[500]!,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Wrap(
                      spacing: 15,
                      runSpacing: 15,
                      alignment: WrapAlignment.center,
                      children: [
                        NavButton(
                          label: 'จองสนาม',
                          icon: Icons.sports_soccer,
                          onTap: () async {
                            if (_blockedByDomainPolicy) {
                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Row(
                                    children: const [
                                      Icon(Icons.info, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text('ไม่สามารถทำการจองได้ชั่วคราว'),
                                    ],
                                  ),
                                  content: const Text(
                                    'ขณะนี้ระบบจำกัดการจองเฉพาะผู้ใช้อีเมลของมหาวิทยาลัยเท่านั้น\n'
                                    'ผู้ใช้ที่ไม่ใช่อีเมลของทางมหาวิทยาลัยไม่สามารถทำการจองได้ชั่วคราว',
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
                                  ],
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BookingSelectionPage()),
                            );
                          },
                        ),
                        NavButton(
                          label: 'ข่าว',
                          icon: Icons.article,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => NewsPage()),
                          ),
                        ),
                        NavButton(
                          label: 'เช็คอิน QR',
                          icon: Icons.qr_code_scanner,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => QRLocationCheckPage()),
                          ),
                        ),
                        NavButton(
                          label: 'ประวัติการจอง',
                          icon: Icons.history,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BookingHistoryPage()),
                          ),
                        ),
                        NavButton(
                          label: 'ประวัติคะแนน',
                          icon: Icons.stars,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PenaltyHistoryPage()),
                          ),
                        ),
                        NavButton(
                          label: 'ตารางสนาม',
                          icon: Icons.schedule,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SchedulePage()),
                          ),
                        ),
                        NavButton(
                          label: 'กฎการจอง',
                          icon: Icons.rule,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BookingRulesPage()),
                          ),
                        ),
                        NavButton(
                          label: 'ติดต่อ',
                          icon: Icons.contact_support,
                          onTap: () => _showContactInfo(context),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40),

                  // Booking eligibility moved to top-right panel

                  // Latest News (User) - Single line marquee
                  if (_latestNews != null) ...[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => NewsPage()));
                        },
                        child: Container(
                          width: double.infinity,
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.teal[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.teal[600],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.campaign, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text('ข่าวสารล่าสุด', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 20,
                                  child: Marquee(
                                    text: '${_latestNews!.title} • ${_latestNews!.contentText}'.replaceAll('\n', ' '),
                                    blankSpace: 80,
                                    velocity: 25,
                                    pauseAfterRound: Duration(milliseconds: 600),
                                    startPadding: 8,
                                    accelerationDuration: Duration(milliseconds: 400),
                                    accelerationCurve: Curves.linear,
                                    decelerationDuration: Duration(milliseconds: 400),
                                    decelerationCurve: Curves.linear,
                                    style: TextStyle(
                                      color: Colors.teal[900],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.open_in_new, color: Colors.teal[700]),
                                tooltip: 'เปิดข่าว',
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => NewsPage()));
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal[50]!, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.teal[200]!, width: 1),
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: 15),
                        Text(
                          'ยินดีต้อนรับสู่ระบบจองสนามกีฬา ม.ศิลปากร',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'จองสนามกีฬาได้สะดวก รวดเร็ว และง่ายดาย',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.teal[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40),

                  Text(
                    'สนามกีฬาที่สามารถจองได้',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.teal[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 25),

                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 : 3,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.85,
                    children: [
                      FieldCard(
                        image: 'assets/football.jpg',
                        label: 'สนามฟุตบอล',
                        icon: '',
                        description: 'สนามหญ้าจริง ขนาดมาตรฐาน',
                      ),
                      FieldCard(
                        image: 'assets/futsal.jpg',
                        label: 'สนามฟุตซอล',
                        icon: '',
                        description: 'สนามกลางแจ้ง พื้นยาง',
                      ),
                      FieldCard(
                        image: 'assets/basketball.jpg',
                        label: 'สนามบาสเกตบอล',
                        icon: '',
                        description: 'สนามปาเก้ ขนาดมาตรฐาน NBA',
                      ),
                    ],
                  ),

                  SizedBox(height: 40),

                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.teal[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.teal[700], size: 24),
                        SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            'เลือกสนามที่คุณต้องการ "จองสนาม" เพื่อเริ่มต้นการใช้งาน',
                            style: TextStyle(fontSize: 16, color: Colors.teal[700]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40),

                  Container(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Divider(color: Colors.teal[300]),
                        SizedBox(height: 15),
                        Text(
                          '© 2025 มหาวิทยาลัยศิลปากร',
                          style: TextStyle(
                            color: Colors.teal[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'โครงการระบบจองสนามกีฬา',
                          style: TextStyle(
                            color: Colors.teal[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  bool _loading = true; List<dynamic> _messages = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final msgs = await PointsService.inboxMessages(); if (mounted) setState(() { _messages = msgs; _loading = false; }); }
    catch (e) { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('กล่องข้อความ')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.separated(
        itemCount: _messages.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final m = _messages[i];
          return ListTile(
            leading: const Icon(Icons.mail),
            title: Text(m['title'] ?? ''),
            subtitle: Text(m['body'] ?? ''),
            trailing: Text((m['createdAt'] ?? '').toString().replaceFirst('T', ' ').split('.').first),
          );
        },
      ),
    );
  }
}

class NavButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const NavButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  _NavButtonState createState() => _NavButtonState();
}

class _NavButtonState extends State<NavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                _animationController.forward().then((_) {
                  _animationController.reverse();
                  widget.onTap();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 20),
                  SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FieldCard extends StatefulWidget {
  final String image;
  final String label;
  final String icon;
  final String description;

  const FieldCard({
    required this.image,
    required this.label,
    required this.icon,
    required this.description,
  });

  @override
  _FieldCardState createState() => _FieldCardState();
}

class _FieldCardState extends State<FieldCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _elevationAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _elevationAnimation,
      builder: (context, child) {
        return MouseRegion(
          onEnter: (_) {
            setState(() => _isHovered = true);
            _animationController.forward();
          },
          onExit: (_) {
            setState(() => _isHovered = false);
            _animationController.reverse();
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            transform: Matrix4.identity()
              ..scale(_isHovered ? 1.02 : 1.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: 0.1),
                  blurRadius: _elevationAnimation.value,
                  offset: Offset(0, _elevationAnimation.value / 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal[300]!, Colors.teal[500]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            child: Image.asset(
                              widget.image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.teal[100],
                                  child: Center(
                                    child: Text(
                                      widget.icon,
                                      style: TextStyle(fontSize: 40),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.3),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.icon,
                                style: TextStyle(fontSize: 24),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.teal[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            widget.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}