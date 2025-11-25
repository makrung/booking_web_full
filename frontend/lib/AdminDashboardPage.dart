import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'AdminSettingsPage.dart';
import 'CourtManagementPageSimple.dart';
import 'Homepage.dart';
import 'widgets/simple_court_qr.dart';
import 'package:intl/intl.dart';
import 'AdminNewsPage.dart';
import 'services/points_service.dart';
import 'MessagesPage.dart';
import 'AdminPointsRequestsPage.dart';
import 'dart:async';
import 'services/activity_requests_service.dart';
import 'services/content_service.dart';
// For CSV/Excel downloads
import 'package:excel/excel.dart' as xls;
import 'utils/save_file.dart';

class AdminDashboardPage extends StatefulWidget {
  final String adminName;

  const AdminDashboardPage({super.key, required this.adminName});

  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  Map<String, dynamic> dashboardData = {};
  List<dynamic> users = [];
  List<dynamic> bookings = [];
  List<dynamic> courts = [];
  List<dynamic> activityRequests = []; // เก็บไว้แต่ไม่โหลดข้อมูล
  List<dynamic> deletedUsers = [];
  bool _showingDeleted = false;
  int _baseDailyRights = 1; // ค่า default หากโหลดไม่ได้
  
  bool isLoading = true;
  String? error;

  // Points request stats for badges
  int _pendingPoints = 0;
  int _unreadPoints = 0;
  int _unreadInbox = 0;
  Timer? _inboxTimer;
  int _lastUnreadInbox = 0;
  int _pendingActivities = 0;

  // Search queries for tabs
  String _qUsers = '';
  String _qBookings = '';
  String _bookingsSort = 'none'; // none|latest|oldest
  String _qCourts = '';
  String _qActivities = '';
  String _activitiesSort = 'none'; // none|latest|oldest
  // Status filters
  String _bookingStatusFilter = 'all'; // all|pending|confirmed|cancelled
  String _activityStatusFilter = 'all'; // all|pending|approved|rejected
  String _userStatusFilter = 'all'; // all|active|suspended|req_blocked|msg_blocked
  String _courtStatusFilter = 'all'; // all|active|inactive

  // Simple paging (Load more)
  int _usersShown = 30;
  int _bookingsShown = 30;
  int _courtsShown = 30;
  int _activitiesShown = 30;

  // Analytics filters
  String _period = 'month'; // 'day' | 'month' | 'year'
  DateTime _selectedDay = DateTime.now();
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  // Server-side analytics cache
  Map<String, dynamic>? _serverAnalytics;

  @override
  void initState() {
    super.initState();
  _tabController = TabController(length: 7, vsync: this); // ภาพรวม, ผู้ใช้, การจอง, สนาม, คำขอกิจกรรม, ข่าวสาร, คำขอเพิ่มคะแนน
    _loadDashboardData();
    _checkAuthPersistence();
    _loadPointsStats();
    _loadInboxUnread().then((_) {
      _lastUnreadInbox = _unreadInbox;
      _startInboxPolling();
    });
    // Preload server analytics for default period
    _refreshServerAnalytics();
  }

  Future<void> _loadPointsStats() async {
    try {
      final stats = await PointsService.adminRequestsStats();
      if (!mounted) return;
      setState(() {
        _pendingPoints = stats['pending'] ?? 0;
        _unreadPoints = stats['unreadPending'] ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _checkAuthPersistence() async {
    // ตรวจสอบว่ายังล็อกอินอยู่หรือไม่และยังเป็น admin หรือไม่
    final isLoggedIn = await AuthService.isLoggedIn();
    final isAdmin = await AuthService.isAdmin();
    
    if (!isLoggedIn || !isAdmin) {
      if (mounted) {
        // ถ้าไม่ได้ล็อกอินหรือไม่ใช่ admin ให้กลับไปหน้าหลัก
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      }
    }
  }

  Future<void> _loadInboxUnread() async {
    try {
      final n = await PointsService.unreadMessagesCount();
      if (!mounted) return;
      setState(() { _unreadInbox = n; });
    } catch (_) {}
  }

  void _startInboxPolling() {
    _inboxTimer?.cancel();
    _inboxTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        final n = await PointsService.unreadMessagesCount();
        if (!mounted) return;
        if (n > _lastUnreadInbox) {
          // new messages arrived
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('มีข้อความใหม่ในกล่องข้อความ'),
              action: SnackBarAction(
                label: 'เปิด',
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesPage()));
                  await _loadInboxUnread();
                },
              ),
            ),
          );
        }
        setState(() {
          _unreadInbox = n;
          _lastUnreadInbox = n;
        });
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inboxTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    // Load data with individual error handling
    Map<String, dynamic> dashboardResult = {'success': false, 'data': {}};
    Map<String, dynamic> usersResult = {'success': false, 'data': []};
  Map<String, dynamic> bookingsResult = {'success': false, 'data': []};
    Map<String, dynamic> courtsResult = {'success': false, 'data': []};
    Map<String, dynamic> activityRequestsResult = {'success': false, 'data': []};
  Map<String, dynamic> deletedUsersResult = {'success': true, 'data': []};

    try {
      dashboardResult = await AdminService.getDashboard();
    } catch (e) {
      print('Dashboard error: $e');
    }

    try {
      usersResult = await AdminService.getUsers();
    } catch (e) {
      print('Users error: $e');
    }

    // Load deleted users in background to support Deleted view
    try {
      deletedUsersResult = await AdminService.getDeletedUsers();
    } catch (e) {
      print('Deleted users error: $e');
      deletedUsersResult = {'success': true, 'data': []};
    }

    try {
      bookingsResult = await AdminService.getBookings(); 
    } catch (e) {
      print('Bookings error: $e');
    }

    try {
      courtsResult = await AdminService.getCourts();
    } catch (e) {
      print('Courts error: $e');
    }

    try {
      final list = await ActivityRequestsService.listAll();
      activityRequestsResult = {'success': true, 'data': list};
    } catch (e) {
      print('Activity requests error: $e');
      activityRequestsResult = {'success': true, 'data': []};
    }

    // Load base daily rights from settings content
    int loadedDailyRights = 1;
    try {
      final daily = await ContentService.getContentWithMeta('daily_rights_per_user');
      final v = (daily['value'] ?? '1').toString();
      loadedDailyRights = int.tryParse(v) ?? 1;
    } catch (e) {
      print('Daily rights content error: $e');
    }

    if (mounted) {
      setState(() {
        // Process dashboard data with fallbacks
        dashboardData = dashboardResult['success'] ? dashboardResult['data'] : {
          'totalUsers': usersResult['success'] ? (usersResult['data'] as List).length : 0,
          'totalBookings': bookingsResult['success'] ? (bookingsResult['data'] as List).length : 0,
          'totalCourts': courtsResult['success'] ? (courtsResult['data'] as List).length : 0,
          'activeBookings': bookingsResult['success'] 
            ? (bookingsResult['data'] as List).where((b) => b['status'] == 'confirmed').length 
            : 0,
          'pendingBookings': bookingsResult['success'] 
            ? (bookingsResult['data'] as List).where((b) => b['status'] == 'pending').length 
            : 0,
        };
        
        users = usersResult['success'] && usersResult['data'] is List ? usersResult['data'] : [];
        deletedUsers = deletedUsersResult['success'] && deletedUsersResult['data'] is List ? deletedUsersResult['data'] : [];
        bookings = bookingsResult['success'] && bookingsResult['data'] is List ? bookingsResult['data'] : [];
        courts = courtsResult['success'] && courtsResult['data'] is List ? courtsResult['data'] : [];
        activityRequests = activityRequestsResult['success'] && activityRequestsResult['data'] is List ? activityRequestsResult['data'] : [];
        _pendingActivities = activityRequests.where((e) => (e['status'] ?? 'pending') == 'pending').length;
        isLoading = false;
        _baseDailyRights = loadedDailyRights;
      });
      // refresh analytics for current filter after data loaded
      _refreshServerAnalytics();
    }
  }

  Future<void> _refreshServerAnalytics() async {
    try {
      Map<String, dynamic> resp;
      if (_period == 'day') {
        final d = DateFormat('yyyy-MM-dd').format(_selectedDay);
        resp = await AdminService.getAnalytics(period: 'day', date: d);
      } else if (_period == 'month') {
        resp = await AdminService.getAnalytics(period: 'month', year: _selectedYear, month: _selectedMonth);
      } else {
        resp = await AdminService.getAnalytics(period: 'year', year: _selectedYear);
      }
      if (!mounted) return;
      if (resp['success'] == true) {
        setState(() { _serverAnalytics = resp['data']; });
      } else {
        setState(() { _serverAnalytics = null; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _serverAnalytics = null; });
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการออกจากระบบ'),
        content: Text('คุณต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('ออกจากระบบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        title: Text(
          'Admin Dashboard - ${widget.adminName}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.home, color: Colors.white),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage()));
          },
          tooltip: 'กลับหน้าหลัก',
        ),
        actions: [
          IconButton(
            tooltip: 'กล่องข้อความ',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesPage()));
              // Mark all as read for immediate badge clear
              try { await PointsService.markAllMessagesRead(); } catch (_) {}
              await _loadInboxUnread();
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
          // Direct access to News Management from main actions (not hidden in overflow)
          IconButton(
            icon: Icon(Icons.article, color: Colors.white),
            tooltip: 'จัดการข่าวสาร',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminNewsPage()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'home':
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage()));
                  break;
                case 'settings':
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AdminSettingsPage()));
                  break;
                case 'courts':
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CourtManagementPage()));
                  break;
                case 'logout':
                  _handleLogout();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'home',
                child: Row(
                  children: [
                    Icon(Icons.home, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text('กลับหน้าหลัก'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text('ตั้งค่าระบบ'),
                  ],
                ),
              ),

              PopupMenuItem(
                value: 'courts',
                child: Row(
                  children: [
                    Icon(Icons.sports_tennis, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text('จัดการสนาม'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('ออกจากระบบ', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: Icon(Icons.dashboard), text: 'ภาพรวม'),
            Tab(icon: Icon(Icons.people), text: 'ผู้ใช้'),
            Tab(icon: Icon(Icons.book_online), text: 'การจอง'),
            Tab(icon: Icon(Icons.sports_tennis), text: 'สนาม'),
            Tab(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.event_note),
                  if (_pendingActivities > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        child: Text('$_pendingActivities', style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
              text: _pendingActivities > 0 ? 'คำขอกิจกรรม ($_pendingActivities)' : 'คำขอกิจกรรม',
            ),
            Tab(icon: Icon(Icons.article), text: 'จัดการข่าวสาร'),
            Tab(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.add_task),
                  if (_unreadPoints > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        child: Text('$_unreadPoints', style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
              text: _pendingPoints > 0 ? 'คำขอเพิ่มคะแนน (${_pendingPoints})' : 'คำขอเพิ่มคะแนน',
            ),
            // แท็บใหม่สำหรับคำขอเพิ่มคะแนน
          ],
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal[700]),
                  SizedBox(height: 16),
                  Text('กำลังโหลดข้อมูล...'),
                ],
              ),
        )
      : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(error!),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        child: Text('ลองใหม่'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(),
                    _buildUsersTab(),
                    _buildBookingsTab(),
                    _buildCourtsTab(),
                    _buildActivityRequestsTab(),
                    // Embed AdminNewsPage as a tab (without nested AppBar)
                    AdminNewsPage(embedded: true),
                    _buildPointsRequestsTab(),
                  ],
                ),
    );
  }

  Widget _buildPointsRequestsTab() {
    return const AdminPointsRequestsPage();
  }

  Widget _buildDashboardTab() {
  // Try to use server analytics (faster on large datasets)
  final filtered = _filteredBookingsByPeriod();
  final courtStats = _serverAnalytics != null ? Map<String,int>.from((_serverAnalytics!['courtCounts'] ?? {})) : _computeCourtStats(filtered);
  final totalFilteredBookings = _serverAnalytics != null ? (_serverAnalytics!['totalFilteredBookings'] ?? filtered.length) : filtered.length;
  final courtsWithBookings = _serverAnalytics != null ? (_serverAnalytics!['courtsWithBookings'] ?? courtStats.length) : courtStats.length;
  final totalCourtsCount = _serverAnalytics != null ? (_serverAnalytics!['totalCourts'] ?? courts.length) : courts.length;
    final usedCourtsRate = totalCourtsCount > 0 ? (courtsWithBookings * 100.0 / totalCourtsCount) : 0.0;
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('ช่วงข้อมูล:', style: TextStyle(fontWeight: FontWeight.w600)),
              ChoiceChip(
                label: const Text('วัน'),
                selected: _period == 'day',
                onSelected: (_) { setState(() { _period = 'day'; }); _refreshServerAnalytics(); },
              ),
              ChoiceChip(
                label: const Text('เดือน'),
                selected: _period == 'month',
                onSelected: (_) { setState(() { _period = 'month'; }); _refreshServerAnalytics(); },
              ),
              ChoiceChip(
                label: const Text('ปี'),
                selected: _period == 'year',
                onSelected: (_) { setState(() { _period = 'year'; }); _refreshServerAnalytics(); },
              ),
              if (_period == 'day')
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDay,
                      firstDate: DateTime(DateTime.now().year - 3),
                      lastDate: DateTime(DateTime.now().year + 1),
                    );
                    if (picked != null) { setState(() { _selectedDay = picked; _selectedYear = picked.year; _selectedMonth = picked.month; }); _refreshServerAnalytics(); }
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(DateFormat('dd/MM/yyyy').format(_selectedDay)),
                ),
              if (_period != 'day')
                DropdownButton<int>(
                  value: _selectedYear,
                  items: _yearsFromBookings().map((y) => DropdownMenuItem(value: y, child: Text('ปี $y'))).toList(),
                  onChanged: (v) { setState(() { _selectedYear = v ?? _selectedYear; }); _refreshServerAnalytics(); },
                ),
              if (_period == 'month')
                DropdownButton<int>(
                  value: _selectedMonth,
                  items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text('เดือน $m'))).toList(),
                  onChanged: (v) { setState(() { _selectedMonth = v ?? _selectedMonth; }); _refreshServerAnalytics(); },
                ),
            ],
          ),
          const SizedBox(height: 12),
          // สถิติภาพรวม
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                'ผู้ใช้ทั้งหมด',
                (dashboardData['totalUsers'] ?? users.length).toString(),
                Icons.people,
                Colors.blue,
              ),
              _buildStatCard(
                'การจอง (ในช่วง)',
                totalFilteredBookings.toString(),
                Icons.book_online,
                Colors.green,
              ),
              _buildStatCard(
                'สนามทั้งหมด',
                (dashboardData['totalCourts'] ?? courts.length).toString(),
                Icons.sports_tennis,
                Colors.orange,
              ),
              _buildStatCard(
                'สนามถูกใช้งาน (%)',
                '${usedCourtsRate.toStringAsFixed(1)}%',
                Icons.percent,
                Colors.purple,
              ),
            ],
          ),
          
          SizedBox(height: 24),
          
          if (bookings.isNotEmpty) ...[
            // Time series chart for selected period
            Text('แนวโน้มการจองตามช่วงที่เลือก', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 4),
            Text('แกน X: เวลา (ตามช่วงที่เลือก)  •  แกน Y: จำนวนการจอง', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Container(height: 300, padding: const EdgeInsets.all(16), decoration: _panelDecoration(), child: _buildPeriodLineChart(filtered, server: _serverAnalytics)),
            const SizedBox(height: 24),
            // Per-court bar chart
            Text('จำนวนการจองตามสนาม', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 4),
            Text('แกน X: ชื่อสนาม  •  แกน Y: จำนวนการจอง', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Container(height: 320, padding: const EdgeInsets.all(16), decoration: _panelDecoration(), child: _buildCourtBarChart(courtStats)),
            const SizedBox(height: 24),
            // Per-court pie chart
            Text('สัดส่วนการจองแต่ละสนาม (%)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 8),
            Container(height: 320, padding: const EdgeInsets.all(16), decoration: _panelDecoration(), child: _buildCourtPieChart(courtStats)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _downloadCsv(filtered),
                  icon: const Icon(Icons.file_download),
                  label: const Text('ดาวน์โหลด CSV'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _downloadExcel(filtered),
                  icon: const Icon(Icons.table_chart),
                  label: const Text('ดาวน์โหลด Excel'),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  

  BoxDecoration _panelDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), spreadRadius: 1, blurRadius: 10)],
      );

  List<int> _yearsFromBookings() {
    final years = <int>{};
    for (final b in bookings) {
      final s = (b['date'] ?? '').toString();
      if (s.length >= 4) {
        final y = int.tryParse(s.substring(0, 4));
        if (y != null) years.add(y);
      }
    }
    years.add(DateTime.now().year);
    final list = years.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> _filteredBookingsByPeriod() {
    final List<Map<String, dynamic>> filtered = [];
    for (final it in bookings) {
      final s = (it['date'] ?? '').toString();
      DateTime? d; try { d = DateTime.parse(s); } catch (_) {}
      if (d == null) continue;
      if (_period == 'day') {
        final k1 = DateFormat('yyyy-MM-dd').format(d);
        final k2 = DateFormat('yyyy-MM-dd').format(_selectedDay);
        if (k1 == k2) filtered.add(it as Map<String, dynamic>);
      } else if (_period == 'month') {
        if (d.year == _selectedYear && d.month == _selectedMonth) filtered.add(it as Map<String, dynamic>);
      } else {
        if (d.year == _selectedYear) filtered.add(it as Map<String, dynamic>);
      }
    }
    return filtered;
  }

  Map<String, int> _computeCourtStats(List<Map<String, dynamic>> list) {
    final map = <String, int>{};
    for (final b in list) {
      final courtName = (b['courtName'] ?? 'ไม่ระบุ').toString();
      map[courtName] = (map[courtName] ?? 0) + 1;
    }
    return map;
  }

  Widget _buildPeriodLineChart(List<Map<String, dynamic>> list, {Map<String, dynamic>? server}) {
    // Prefer server-provided buckets for performance on large datasets
    final Map<String, int> buckets = {};
    List<String> labels = [];
    if (server != null && server['labels'] is List && server['buckets'] is Map) {
      labels = List<String>.from(server['labels']);
      final b = Map<String, dynamic>.from(server['buckets']);
      b.forEach((k, v) { buckets[k] = int.tryParse(v.toString()) ?? 0; });
      if (labels.isEmpty) {
        // fallback to client if labels missing
      } else {
        // proceed with server data
      }
    }
    if (labels.isEmpty) {
      if (list.isEmpty) return const Center(child: Text('ไม่มีข้อมูลในช่วงนี้'));
      // Client-side compute
      if (_period == 'year') {
        labels = List.generate(12, (i) => (i + 1).toString());
        for (var i = 1; i <= 12; i++) buckets['$i'] = 0;
        for (final b in list) {
          final d = DateTime.tryParse((b['date'] ?? '').toString());
          if (d == null) continue; buckets['${d.month}'] = (buckets['${d.month}'] ?? 0) + 1;
        }
      } else if (_period == 'month') {
        final days = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
        labels = List.generate(days, (i) => (i + 1).toString());
        for (var i = 1; i <= days; i++) buckets['$i'] = 0;
        for (final b in list) {
          final d = DateTime.tryParse((b['date'] ?? '').toString());
          if (d == null) continue; buckets['${d.day}'] = (buckets['${d.day}'] ?? 0) + 1;
        }
      } else { // day
        labels = List.generate(24, (i) => i.toString());
        for (var i = 0; i < 24; i++) buckets['$i'] = 0;
        for (final b in list) {
          final slots = (b['timeSlots'] is List) ? List<String>.from(b['timeSlots']) : [];
          if (slots.isEmpty && b['timeSlot'] is String) slots.add(b['timeSlot']);
          final hours = slots.map((s){ final h = int.tryParse(s.split(':').first); return h ?? 0; }).toList();
          if (hours.isEmpty) { buckets['0'] = (buckets['0'] ?? 0) + 1; }
          for (final h in hours) { buckets['$h'] = (buckets['$h'] ?? 0) + 1; }
        }
      }
    }
    if (_period == 'year') {
      if (labels.isEmpty) { labels = List.generate(12, (i) => (i + 1).toString()); for (var i=1;i<=12;i++) { buckets['$i']= (buckets['$i'] ?? 0);} }
    } else if (_period == 'month') {
      if (labels.isEmpty) { final days = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth); labels = List.generate(days, (i) => (i + 1).toString()); for (var i=1;i<=days;i++){ buckets['$i']=(buckets['$i'] ?? 0);} }
    } else { // day
      if (labels.isEmpty) { labels = List.generate(24, (i) => i.toString()); for (var i=0;i<24;i++){ buckets['$i']=(buckets['$i'] ?? 0);} }
    }
    final keys = labels;
    final spots = <FlSpot>[];
    for (var i = 0; i < keys.length; i++) {
      final k = keys[i];
      spots.add(FlSpot(i.toDouble(), (buckets[k] ?? 0).toDouble()));
    }

    // Dynamic axis labels
    String xAxisName;
    if (_period == 'year') {
      xAxisName = 'แกน X: เดือน (1–12)';
    } else if (_period == 'month') {
      final days = keys.length;
      xAxisName = 'แกน X: วันที่ (1–$days)';
    } else {
      xAxisName = 'แกน X: ชั่วโมง (0–23)';
    }
    const yAxisName = 'แกน Y: จำนวนการจอง';

    final maxX = (keys.length - 1).toDouble();
    final chart = LineChart(LineChartData(
      minX: 0,
      maxX: maxX,
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (value, meta){
            // แสดงเฉพาะตำแหน่งจำนวนเต็ม เพื่อไม่ให้ซ้ำ 1 1 1 2 2 2
            if (value % 1 != 0) return const SizedBox.shrink();
            final idx = value.toInt();
            if (idx>=0 && idx<keys.length) {
              return Text(keys[idx], style: const TextStyle(fontSize: 9));
            }
            return const SizedBox.shrink();
          },
        )),
        // ไม่ใช้ axisNameWidget ของ fl_chart เพื่อควบคุมการจัดวางให้ตรง "หัวเส้นแกน"
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.teal,
          barWidth: 3,
          dotData: FlDotData(show: true),
        )
      ],
    ));

    // วางคำอธิบายแกน X/Y ไว้บริเวณมุมซ้ายล่างใกล้จุดกำเนิดแกน (ตามภาพที่ต้องการ)
    return Stack(
      children: [
        // เผื่อพื้นที่ด้านล่างเล็กน้อยสำหรับคำอธิบาย และด้านซ้ายมี reserved ของ leftTitles อยู่แล้ว
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(top: 18, right: 28, bottom: 24),
            child: chart,
          ),
        ),
        // คำอธิบายแกน X ที่มุมซ้ายล่าง (เหนือเส้นแกนนิดเดียว)
        Positioned(
          bottom: 2,
          left: 8,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: Text(
            xAxisName,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          ),
        ),
        // คำอธิบายแกน Y วางตามแนวแกนซ้าย ใกล้จุดกำเนิด (เลื่อนขึ้นเล็กน้อยเหนือแกน X)
        Positioned(
          bottom: 26,
          left: 0,
          child: RotatedBox(
            quarterTurns: 3,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(
              yAxisName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourtBarChart(Map<String,int> stats) {
    if (stats.isEmpty) return const Center(child: Text('ไม่มีข้อมูล'));
    final sorted = stats.entries.toList()..sort((a,b)=> b.value.compareTo(a.value));
    final top = sorted.take(10).toList();
    final labels = top.map((e) => e.key).toList();
    final groups = <BarChartGroupData>[];
    for (var i=0; i<labels.length; i++) {
      final v = top[i].value.toDouble();
      groups.add(BarChartGroupData(x: i, barRods: [BarChartRodData(toY: v, color: Colors.indigo, width: 14)]));
    }
    const xAxisName = 'แกน X: สนาม';
    const yAxisName = 'แกน Y: จำนวนการจอง';

    final chart = BarChart(BarChartData(
      barGroups: groups,
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (value, meta){
            if (value % 1 != 0) return const SizedBox.shrink();
            final idx = value.toInt();
            if (idx>=0 && idx<labels.length) {
              return SizedBox(width: 60, child: Text(labels[idx], style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis));
            }
            return const SizedBox.shrink();
          },
        )),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
    ));

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24, right: 8),
            child: chart,
          ),
        ),
        Positioned(
          bottom: 2,
          left: 8,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: const Text(
              xAxisName,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ),
        Positioned(
          bottom: 26,
          left: 0,
          child: RotatedBox(
            quarterTurns: 3,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: const Text(
                yAxisName,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourtPieChart(Map<String,int> stats) {
    if (stats.isEmpty) return const Center(child: Text('ไม่มีข้อมูล'));
    // Use all courts in the pie chart. Generate a distinct color per court by evenly
    // distributing hues across the number of courts so colors are as different as possible.
    final entries = stats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value).toDouble();
    final sections = <PieChartSectionData>[];
    final labels = <MapEntry<String, int>>[];
    // Build sections and compute angles for rotated percent badges
    double cumulative = 0.0;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final pct = total > 0 ? (e.value * 100.0 / total) : 0.0;
      // Evenly spaced hue distribution
      final hue = (360.0 * i / (entries.length)).toDouble();
      final color = HSVColor.fromAHSV(1.0, hue % 360.0, 0.65, 0.72).toColor();
      final sweep = (e.value / total) * 2 * math.pi;
      final mid = cumulative + sweep / 2;
      cumulative += sweep;

      sections.add(PieChartSectionData(
        value: e.value.toDouble(),
        color: color,
        title: '', // move percent into badge for rotated text
        radius: 80,
        badgeWidget: Transform.rotate(angle: mid, child: Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87))),
        // push badges further out to avoid overlap and keep them readable
        badgePositionPercentageOffset: 1.3,
      ));
      labels.add(e);
    }

    // Build legend entries with matching colors and percentages
    final legendItems = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      final e = labels[i];
      final hue = (360.0 * i / labels.length) % 360.0;
      final color = HSVColor.fromAHSV(1.0, hue, 0.65, 0.72).toColor();
      final pct = total > 0 ? (e.value * 100.0 / total) : 0.0;
      legendItems.add(Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Flexible(child: Text('${e.key} (${e.value})', overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ));
    }

    final chart = SizedBox(
      width: 460,
      height: 360,
      child: PieChart(PieChartData(sections: sections, sectionsSpace: 2, centerSpaceRadius: 40)),
    );

    final legend = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 320),
      child: LayoutBuilder(builder: (ctx, lg) {
        final available = lg.maxWidth;
        int cols = 1;
        if (available > 900) cols = 4;
        else if (available > 700) cols = 3;
        else if (available > 420) cols = 2;
        else cols = 1;
        cols = cols.clamp(1, labels.length);

        // Determine item height and legend height
        const itemHeight = 28.0;
        final perCol = (labels.length / cols).ceil();
        final desiredHeight = (perCol * itemHeight) + 12.0; // padding
        final legendHeight = desiredHeight.clamp(80.0, 320.0);

        // Debug print of labels (helps verify which courts are included)
        try { print('Court legend labels (${labels.length}): ${labels.map((e) => e.key).join(', ')}'); } catch (_) {}

        // Build a simple list widget for the legend contents that can be placed
        // either inline (right side) or stacked below the chart depending on width.
        Widget legendList = Scrollbar(
          thumbVisibility: true,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            itemCount: labels.length,
            itemBuilder: (context, i) {
              final e = labels[i];
              final hue = (360.0 * i / labels.length) % 360.0;
              final color = HSVColor.fromAHSV(1.0, hue, 0.65, 0.72).toColor();
              final pct = total > 0 ? (e.value * 100.0 / total) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  const SizedBox(width: 8),
                  Text('${e.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              );
            },
          ),
        );

        // Return a column with small header then the legendList widget
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 6, bottom: 6),
              child: Text('แสดง ${labels.length} สนาม', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
            ),
            SizedBox(height: legendHeight, child: legendList),
          ],
        );
      }),
    );

    // Responsive: side-by-side on wide screens, stacked on narrow screens
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 900) {
        // Use a fixed-width legend panel on the right to match the mockup
        final legendWidth = (constraints.maxWidth * 0.36).clamp(320.0, 520.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: chart)),
            const SizedBox(width: 24),
            SizedBox(width: legendWidth, child: legend),
          ],
        );
      } else if (constraints.maxWidth > 700) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: chart)),
            const SizedBox(width: 16),
            SizedBox(width: 320, child: legend),
          ],
        );
      }
      return Column(children: [chart, const SizedBox(height: 12), legend]);
    });
  }

  // (Removed unused _legendDot helper; legend rendered inline in _buildCourtPieChart)

  Uint8List _buildCsvBytes(List<Map<String, dynamic>> list) {
    final buf = StringBuffer();
    buf.writeln('id,courtName,userName,date,timeSlots,status,activityName,note');
    String san(dynamic v) => (v ?? '').toString().replaceAll(',', ' ').replaceAll('\n', ' ').trim();
    for (final b in list) {
      final id = san(b['id'] ?? b['bookingId']);
      final court = san(b['courtName']);
      final user = san(b['userName']);
      final date = san(b['date']);
      final time = (b['timeSlots'] is List) ? (b['timeSlots'] as List).join('|') : san(b['timeSlots']);
      final status = san(b['status']);
      final act = san(b['activityName'] ?? b['activity']);
      final note = san(b['note']);
      buf.writeln('$id,$court,$user,$date,$time,$status,$act,$note');
    }
    return Uint8List.fromList(buf.toString().codeUnits);
  }

  void _downloadCsv(List<Map<String, dynamic>> list) {
    final bytes = _buildCsvBytes(list);
    SaveFileHelper.saveBytes(
      fileName: 'bookings_${DateTime.now().millisecondsSinceEpoch}.csv',
      mimeType: 'text/csv',
      bytes: bytes,
    );
  }

  void _downloadExcel(List<Map<String, dynamic>> list) {
    final file = xls.Excel.createExcel();
    final sheet = file['Bookings'];
    // Header style
    final headerStyle = xls.CellStyle(
      bold: true,
      horizontalAlign: xls.HorizontalAlign.Center,
      verticalAlign: xls.VerticalAlign.Center,
    );
    sheet.appendRow([
      xls.TextCellValue('id'),
      xls.TextCellValue('courtName'),
      xls.TextCellValue('userName'),
      xls.TextCellValue('date'),
      xls.TextCellValue('timeSlots'),
      xls.TextCellValue('status'),
      xls.TextCellValue('activityName'),
      xls.TextCellValue('note'),
    ]);
    // Apply header style row 1 (index 0)
    for (var c = 0; c < 8; c++) {
      final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.cellStyle = headerStyle;
    }
    // Set column widths
    const widths = [18.0, 22.0, 22.0, 14.0, 28.0, 14.0, 22.0, 30.0];
    for (var c = 0; c < widths.length; c++) {
      try { sheet.setColumnWidth(c, widths[c]); } catch (_) {}
    }
    for (final b in list) {
      String s(dynamic v) => (v ?? '').toString();
      final timeStr = (b['timeSlots'] is List) ? (b['timeSlots'] as List).join('|') : s(b['timeSlots']);
      sheet.appendRow([
        xls.TextCellValue(s(b['id'] ?? b['bookingId'])),
        xls.TextCellValue(s(b['courtName'])),
        xls.TextCellValue(s(b['userName'])),
        xls.TextCellValue(s(b['date'])),
        xls.TextCellValue(timeStr),
        xls.TextCellValue(s(b['status'])),
        xls.TextCellValue(s(b['activityName'] ?? b['activity'])),
        xls.TextCellValue(s(b['note'])),
      ]);
    }
    final bytes = Uint8List.fromList(file.encode()!);
    SaveFileHelper.saveBytes(
      fileName: 'bookings_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      bytes: bytes,
    );
  }

  Widget _buildUsersTab() {
    final baseList = _showingDeleted ? deletedUsers : users;
    // Text search
    final list0 = _qUsers.trim().isEmpty ? baseList : baseList.where((u) {
      final m = (u is Map) ? u : {};
      final q = _qUsers.toLowerCase();
      return (m['firstName']?.toString().toLowerCase() ?? '').contains(q)
          || (m['lastName']?.toString().toLowerCase() ?? '').contains(q)
          || (m['email']?.toString().toLowerCase() ?? '').contains(q)
          || (m['studentId']?.toString().toLowerCase() ?? '').contains(q)
          || (m['role']?.toString().toLowerCase() ?? '').contains(q);
    }).toList();
    // Status filter
    final filtered = _userStatusFilter == 'all' ? list0 : list0.where((u) {
      final m = (u is Map) ? u : {};
      switch (_userStatusFilter) {
        case 'active':
          return m['isActive'] == true;
        case 'suspended':
          return m['isActive'] == false;
        case 'req_blocked':
          return m['isRequestBlocked'] == true;
        case 'msg_blocked':
          return m['isMessagesBlocked'] == true;
        default:
          return true;
      }
    }).toList();
    final showing = filtered.take(_usersShown).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              // Search box
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ค้นหาผู้ใช้ด้วยชื่อ อีเมล รหัส หรือบทบาท'),
                  onChanged: (v) => setState(() { _qUsers = v; }),
                ),
              ),
              const SizedBox(width: 12),
              // Status filter dropdown
              DropdownButton<String>(
                value: _userStatusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('ทุกสถานะ')),
                  DropdownMenuItem(value: 'active', child: Text('ใช้งาน')),
                  DropdownMenuItem(value: 'suspended', child: Text('ระงับ')),
                  DropdownMenuItem(value: 'req_blocked', child: Text('บล็อคส่งคำขอ')),
                  DropdownMenuItem(value: 'msg_blocked', child: Text('บล็อคข้อความ')),
                ],
                onChanged: (v) => setState(() { _userStatusFilter = v ?? 'all'; _usersShown = 30; }),
              ),
              const SizedBox(width: 12),
              FilterChip(
                selected: !_showingDeleted,
                label: const Text('ผู้ใช้ปกติ'),
                onSelected: (_) => setState(() { _showingDeleted = false; }),
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _showingDeleted,
                label: const Text('ผู้ใช้ที่ถูกลบ'),
                onSelected: (_) async {
                  setState(() { _showingDeleted = true; });
                  // Ensure latest deleted list
                  final res = await AdminService.getDeletedUsers();
                  if (mounted && res['success']==true) setState(() { deletedUsers = res['data']; });
                },
              ),
              const Spacer(),
              if (_showingDeleted && deletedUsers.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () async {
                    final confirmed = await _confirmDialog('ลบทั้งหมด', 'ต้องการลบผู้ใช้ทั้งหมดในถังขยะถาวรหรือไม่?');
                    if (confirmed == true) {
                      final resp = await AdminService.purgeAllDeletedUsers();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? resp['error'] ?? '')));
                        await _loadDashboardData();
                        setState(() { _showingDeleted = true; });
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('ลบทั้งหมด'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
            ],
          ),
        ),
        Expanded(
          child: showing.isEmpty
              ? Center(child: Text(_showingDeleted ? 'ไม่มีผู้ใช้ในถังขยะ' : 'ไม่พบผลลัพธ์'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: showing.length + 1,
                  itemBuilder: (context, index) {
                    if (index == showing.length) {
                      final more = filtered.length - showing.length;
                      if (more <= 0) return const SizedBox.shrink();
                      return Center(child: TextButton(onPressed: ()=> setState(()=> _usersShown += 30), child: Text('โหลดเพิ่ม (+${more.clamp(0,30)})')));
                    }
                    return _showingDeleted
                        ? _buildDeletedUserCard(showing[index] as Map<String, dynamic>)
                        : _buildUserCard(showing[index] as Map<String, dynamic>);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildUserCard(Map<String, dynamic> user) {
  final int baseDailyRights = _baseDailyRights;
    final int extraDailyRights = (user['extraDailyRights'] is int)
        ? (user['extraDailyRights'] as int)
        : int.tryParse('${user['extraDailyRights'] ?? 0}') ?? 0;
    final int effectiveDailyRights = baseDailyRights + extraDailyRights;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.teal[100],
            child: Text(
              '${user['firstName']?[0] ?? ''}${user['lastName']?[0] ?? ''}',
              style: TextStyle(
                color: Colors.teal[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  user['email'] ?? '',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  'รหัส: ${user['studentId'] ?? 'N/A'}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _badge((user['isActive'] ?? false) ? 'ใช้งาน' : 'ระงับ', (user['isActive'] ?? false) ? Colors.green : Colors.red),
                    if (user['isRequestBlocked'] == true) _badge('บล็อคส่งคำขอ', Colors.orange),
                    if (user['isMessagesBlocked'] == true) _badge('บล็อคข้อความ', Colors.orange),
                    if (user['role'] == 'admin') _badge('ADMIN', Colors.blue),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'สิทธิ์/วัน: รวม $effectiveDailyRights (ระบบ $baseDailyRights + เพิ่ม $extraDailyRights)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'toggle') {
                final resp = await AdminService.toggleUserStatus(user['id']);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? resp['error'] ?? '')));
                  await _loadDashboardData();
                }
              } else if (value == 'block_requests') {
                final confirmed = await _confirmDialog('บล็อคการส่งคำขอ', 'ต้องการสลับสถานะการบล็อคการส่งคำขอของผู้ใช้นี้หรือไม่?');
                if (confirmed == true) {
                  final target = !(user['isRequestBlocked'] == true);
                  final reason = target ? await _inputReasonDialog('เหตุผลในการบล็อค (ไม่บังคับ)') : null;
                  final resp = await AdminService.setUserBlock(user['id'], requestBlocked: target, reason: reason);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? resp['error'] ?? '')));
                    await _loadDashboardData();
                  }
                }
              } else if (value == 'block_messages') {
                final confirmed = await _confirmDialog('บล็อคข้อความถึงแอดมิน', 'ต้องการสลับสถานะการบล็อคข้อความของผู้ใช้นี้หรือไม่?');
                if (confirmed == true) {
                  final target = !(user['isMessagesBlocked'] == true);
                  final resp = await AdminService.setUserBlock(user['id'], messagesBlocked: target);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? resp['error'] ?? '')));
                    await _loadDashboardData();
                  }
                }
              } else if (value == 'extra_rights') {
                await _showAdjustExtraRightsDialog(user);
              } else if (value == 'edit') {
                await _showEditUserDialog(user);
              } else if (value == 'delete') {
                final confirmed = await _confirmDialog('ลบผู้ใช้', 'ต้องการลบ/ระงับผู้ใช้นี้หรือไม่?');
                if (confirmed == true) {
                  final resp = await AdminService.deleteUser(user['id']);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? resp['error'] ?? '')));
                    await _loadDashboardData();
                  }
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'toggle', child: _menuRow(Icons.power_settings_new, (user['isActive'] ?? false) ? 'ระงับการใช้งาน' : 'เปิดการใช้งาน')),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'block_requests', child: _menuRow(Icons.block, (user['isRequestBlocked'] == true) ? 'ปลดบล็อคส่งคำขอ' : 'บล็อคการส่งคำขอ')),
              PopupMenuItem(value: 'block_messages', child: _menuRow(Icons.chat_bubble_outline, (user['isMessagesBlocked'] == true) ? 'ปลดบล็อคข้อความ' : 'บล็อคข้อความ')),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'extra_rights', child: _menuRow(Icons.exposure, 'ปรับสิทธิ์/วัน (แอดมินเพิ่ม)')),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'edit', child: _menuRow(Icons.edit, 'แก้ไขข้อมูล')),
              PopupMenuItem(value: 'delete', child: _menuRow(Icons.delete, 'ลบผู้ใช้')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedUserCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), spreadRadius: 1, blurRadius: 10),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.red[100],
            child: Icon(Icons.delete, color: Colors.red[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${user['firstName'] ?? ''} ${user['lastName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(user['email'] ?? '', style: TextStyle(color: Colors.grey[600])),
                Text('รหัส: ${user['studentId'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                if (user['deletedAt'] != null) ...[
                  const SizedBox(height: 4),
                  Text('ลบเมื่อ: ${user['deletedAt'] is String ? user['deletedAt'] : ''}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final resp = await AdminService.restoreDeletedUser(user['id']);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? resp['error'] ?? '')));
                    await _loadDashboardData();
                    setState(() { _showingDeleted = false; });
                  }
                },
                icon: const Icon(Icons.restore),
                label: const Text('กู้คืน'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final confirmed = await _confirmDialog('ลบถาวร', 'ต้องการลบผู้ใช้นี้ถาวรหรือไม่?');
                  if (confirmed == true) {
                    final resp = await AdminService.purgeDeletedUser(user['id']);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? resp['error'] ?? '')));
                      await _loadDashboardData();
                      setState(() { _showingDeleted = true; });
                    }
                  }
                },
                icon: const Icon(Icons.delete_forever),
                label: const Text('ลบถาวร'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _menuRow(IconData icon, String text) {
    return Row(children: [Icon(icon, size: 18, color: Colors.grey[700]), const SizedBox(width: 8), Text(text)]);
  }

  Future<void> _showAdjustExtraRightsDialog(Map<String, dynamic> user) async {
  int baseDailyRights = _baseDailyRights;
    int currentExtra = (user['extraDailyRights'] is int)
        ? (user['extraDailyRights'] as int)
        : int.tryParse('${user['extraDailyRights'] ?? 0}') ?? 0;
    final value = ValueNotifier<int>(currentExtra);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('ปรับสิทธิ์/วัน (แอดมินเพิ่ม)')
          ,content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ผู้ใช้: ${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'),
              const SizedBox(height: 8),
              Text('สิทธิ์ระบบ: $baseDailyRights/วัน'),
              const SizedBox(height: 8),
              ValueListenableBuilder<int>(
                valueListenable: value,
                builder: (context, v, _) {
                  final eff = baseDailyRights + v;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('เพิ่มโดยแอดมิน: $v'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () { if (value.value > -10) value.value = value.value - 1; },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$v', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: () { if (value.value < 50) value.value = value.value + 1; },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          const SizedBox(width: 12),
                          const Text('(ช่วง -10 ถึง 50)')
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('รวมต่อวัน: $eff สิทธิ์'),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
          ],
        );
      },
    );

    if (saved == true) {
      final resp = await AdminService.setExtraDailyRights(user['id'], value.value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resp['message'] ?? resp['error'] ?? '')),
        );
        await _loadDashboardData();
      }
    }
  }

  Future<bool?> _confirmDialog(String title, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('ยืนยัน', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Future<String?> _inputReasonDialog(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'เหตุผล', hintText: 'เช่น สแปมคำขอ, ใช้งานผิดกติกา')), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('ข้าม')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('บันทึก')),
        ],
      ),
    );
  }

  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    final firstName = TextEditingController(text: user['firstName'] ?? '');
    final lastName = TextEditingController(text: user['lastName'] ?? '');
    final email = TextEditingController(text: user['email'] ?? '');
    final phone = TextEditingController(text: user['phone'] ?? '');
    final studentId = TextEditingController(text: (user['studentId'] ?? '').toString());
    final points = TextEditingController(text: (user['points'] ?? 0).toString());
    final role = ValueNotifier<String>((user['role'] ?? 'user').toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แก้ไขข้อมูลผู้ใช้'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: firstName, decoration: const InputDecoration(labelText: 'ชื่อ')), 
              TextField(controller: lastName, decoration: const InputDecoration(labelText: 'นามสกุล')), 
              TextField(controller: email, decoration: const InputDecoration(labelText: 'อีเมล')), 
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'เบอร์โทร')), 
              TextField(controller: studentId, decoration: const InputDecoration(labelText: 'รหัสนักศึกษา/เลขบัตรประชาชน')), 
              TextField(controller: points, decoration: const InputDecoration(labelText: 'คะแนน'), keyboardType: TextInputType.number), 
              ValueListenableBuilder<String>(
                valueListenable: role,
                builder: (context, value, _) => DropdownButtonFormField<String>(
                  value: value,
                  decoration: const InputDecoration(labelText: 'บทบาท'),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('ผู้ใช้')),
                    DropdownMenuItem(value: 'admin', child: Text('ผู้ดูแลระบบ')),
                  ],
                  onChanged: (v) => role.value = v ?? 'user',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('บันทึก')),
        ],
      ),
    );

    if (saved == true) {
      final payload = {
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'studentId': studentId.text.trim(),
        'points': int.tryParse(points.text.trim()) ?? 0,
        'role': role.value,
      };
      final resp = await AdminService.updateUser(user['id'], payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? resp['error'] ?? '')));
        await _loadDashboardData();
      }
    }
  }

  Widget _buildBookingsTab() {
    final base = bookings;
    // Apply client-side sort if requested
    List<dynamic> sortedBookings = List.from(base);
    if (_bookingsSort == 'latest') {
      // Sort by createdAt descending (most recent first). Fallback to epoch if missing.
      sortedBookings.sort((a, b) => _toDateTime(b['createdAt']).compareTo(_toDateTime(a['createdAt'])));
    } else if (_bookingsSort == 'oldest') {
      // Sort by createdAt ascending (oldest first)
      sortedBookings.sort((a, b) => _toDateTime(a['createdAt']).compareTo(_toDateTime(b['createdAt'])));
    }
  final filtered = _qBookings.trim().isEmpty && _bookingStatusFilter=='all' ? sortedBookings : sortedBookings.where((b){
      final m = (b is Map)? b: {};
      final q = _qBookings.toLowerCase();
      final matchesText = (m['courtName']?.toString().toLowerCase() ?? '').contains(q)
        || (m['userName']?.toString().toLowerCase() ?? '').contains(q)
        || (m['date']?.toString().toLowerCase() ?? '').contains(q)
        || (m['status']?.toString().toLowerCase() ?? '').contains(q)
        || (m['activityType']?.toString().toLowerCase() ?? '').contains(q)
        || (m['activityName']?.toString().toLowerCase() ?? '').contains(q);
      final matchesStatus = _bookingStatusFilter=='all' || (m['status']?.toString() ?? '') == _bookingStatusFilter;
      return matchesText && matchesStatus;
    }).toList();
    final showing = filtered.take(_bookingsShown).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16,16,16,8),
        child: Row(children: [
          Expanded(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ค้นหาการจองด้วย ชื่อสนาม ผู้จอง วันที่ สถานะ ประเภทกิจกรรม'), onChanged: (v)=> setState(() { _qBookings = v; _bookingsShown = 30; }))),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _bookingStatusFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('ทุกสถานะ')),
              DropdownMenuItem(value: 'pending', child: Text('รอการอนุมัติ')),
              DropdownMenuItem(value: 'confirmed', child: Text('อนุมัติแล้ว')),
              DropdownMenuItem(value: 'cancelled', child: Text('ยกเลิก')),
            ],
            onChanged: (v)=> setState(()=> _bookingStatusFilter = v ?? 'all'),
          ),
          const SizedBox(width: 12),
          // Sort control
          DropdownButton<String>(
            value: _bookingsSort,
            items: const [
              DropdownMenuItem(value: 'none', child: Text('เรียง: ปกติ')),
              DropdownMenuItem(value: 'latest', child: Text('เรียง: ล่าสุด')),
              DropdownMenuItem(value: 'oldest', child: Text('เรียง: เก่า')),
            ],
            onChanged: (v) => setState(() => _bookingsSort = v ?? 'none'),
          ),
        ]),
      ),
      Expanded(
        child: showing.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('ไม่พบผลลัพธ์'),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: showing.length + 1,
                itemBuilder: (context, index) {
                  if (index == showing.length) {
                    final more = filtered.length - showing.length;
                    if (more <= 0) return const SizedBox.shrink();
                    return Center(child: TextButton(onPressed: ()=> setState(()=> _bookingsShown += 30), child: Text('โหลดเพิ่ม (+${more.clamp(0,30)})')));
                  }
                  return _buildBookingCard(showing[index]);
                },
              ),
      ),
    ]);
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'unknown';
    Color statusColor;
    String statusText;
    
    switch (status) {
      case 'confirmed':
        statusColor = Colors.green;
        statusText = 'อนุมัติแล้ว';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'รอการอนุมัติ';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'ยกเลิก';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                booking['courtName'] ?? 'ไม่ระบุสนาม',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'วันที่: ${booking['date'] ?? 'N/A'}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (booking['timeSlots'] != null) ...[
            Text(
              'เวลา: ${(booking['timeSlots'] as List).join(', ')}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
          if (booking['userName'] != null) ...[
            Text(
              'ผู้จอง: ${booking['userName']}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () async {
                await _showEditBookingDialog(booking);
              },
              icon: const Icon(Icons.edit),
              label: const Text('แก้ไข'),
            ),
          )
          ,const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final ok = await _confirmDialog('ลบการจอง', 'ต้องการลบการจองนี้หรือไม่?');
                if (ok == true) {
                  final id = (booking['id'] ?? booking['bookingId'] ?? '').toString();
                  if (id.isNotEmpty) {
                    final resp = await AdminService.deleteBooking(id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? resp['error'] ?? '')));
                      await _loadDashboardData();
                    }
                  }
                }
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('ลบการจอง', style: TextStyle(color: Colors.red)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _showEditBookingDialog(Map<String, dynamic> booking) async {
    final bookingId = (booking['id'] ?? booking['bookingId'] ?? booking['docId'] ?? '').toString();
    final dateCtl = TextEditingController(text: (booking['date'] ?? '').toString());
    final timeCtl = TextEditingController(
      text: booking['timeSlots'] is List
          ? (booking['timeSlots'] as List).join(', ')
          : (booking['timeSlots']?.toString() ?? ''),
    );
    final noteCtl = TextEditingController(text: (booking['note'] ?? '').toString());
    final activityNameCtl = TextEditingController(text: (booking['activityName'] ?? booking['activity'] ?? '').toString());
    // Sanitize initial status to match dropdown items to avoid assertion errors
    const allowedStatuses = ['pending', 'confirmed', 'cancelled'];
    String initialStatus = (booking['status'] ?? 'pending').toString();
    if (!allowedStatuses.contains(initialStatus)) {
      if (initialStatus == 'checked-in' || initialStatus == 'completed') {
        initialStatus = 'confirmed';
      } else {
        // For statuses like expired, no-show, penalized, default to cancelled in the editor
        initialStatus = 'cancelled';
      }
    }
    final statusVN = ValueNotifier<String>(initialStatus);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขการจอง'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: dateCtl, decoration: const InputDecoration(labelText: 'วันที่ (YYYY-MM-DD)')),
              TextField(controller: timeCtl, decoration: const InputDecoration(labelText: 'ช่วงเวลา (คั่นด้วย , )')),
              ValueListenableBuilder<String>(
                valueListenable: statusVN,
                builder: (context, v, _) => DropdownButtonFormField<String>(
                  value: v,
                  decoration: const InputDecoration(labelText: 'สถานะ'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('รอการอนุมัติ')),
                    DropdownMenuItem(value: 'confirmed', child: Text('อนุมัติแล้ว')),
                    DropdownMenuItem(value: 'cancelled', child: Text('ยกเลิก')),
                  ],
                  onChanged: (nv) => statusVN.value = nv ?? 'pending',
                ),
              ),
              TextField(controller: activityNameCtl, decoration: const InputDecoration(labelText: 'ชื่อกิจกรรม (ถ้ามี)')),
              TextField(controller: noteCtl, decoration: const InputDecoration(labelText: 'หมายเหตุ')), 
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
        ],
      ),
    );

    if (saved == true && bookingId.isNotEmpty) {
      final timeSlots = timeCtl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final payload = <String, dynamic>{
        if (dateCtl.text.trim().isNotEmpty) 'date': dateCtl.text.trim(),
        if (timeSlots.isNotEmpty) 'timeSlots': timeSlots,
        // Only include status if the admin changed it from the initial sanitized value
        if (statusVN.value != initialStatus) 'status': statusVN.value,
        'note': noteCtl.text.trim(),
        if (activityNameCtl.text.trim().isNotEmpty) 'activity': activityNameCtl.text.trim(),
      };
      final resp = await AdminService.editBooking(bookingId, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((resp['success'] == true) ? 'บันทึกการจองแล้ว' : (resp['error'] ?? 'แก้ไขการจองไม่สำเร็จ'))),
        );
        await _loadDashboardData();
      }
    }
  }

  Widget _buildCourtsTab() {
    final base = courts;
    final filteredByText = _qCourts.trim().isEmpty ? base : base.where((c){
      final m = (c is Map)? c: {};
      final q = _qCourts.toLowerCase();
      return (m['name']?.toString().toLowerCase() ?? '').contains(q)
        || (m['category']?.toString().toLowerCase() ?? '').contains(q)
        || (m['number']?.toString().toLowerCase() ?? '').contains(q);
    }).toList();
    // Apply status filter
    final filtered = _courtStatusFilter == 'all' ? filteredByText : filteredByText.where((c){
      final m = (c is Map)? c: {};
      final available = (m['isAvailable'] ?? true) == true;
      if (_courtStatusFilter == 'active') return available;
      if (_courtStatusFilter == 'inactive') return !available;
      return true;
    }).toList();
    final showing = filtered.take(_courtsShown).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16,16,16,0),
          child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ค้นหาสนามด้วยชื่อ ประเภท หมายเลข'), onChanged: (v)=> setState(() { _qCourts = v; _courtsShown = 30; })),
        ),
        // Status filter row
        Padding(
          padding: const EdgeInsets.fromLTRB(16,8,16,0),
          child: Row(
            children: [
              const Icon(Icons.filter_alt, color: Colors.teal),
              const SizedBox(width: 8),
              const Text('กรองสถานะ:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _courtStatusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                  DropdownMenuItem(value: 'active', child: Text('พร้อมใช้')),
                  DropdownMenuItem(value: 'inactive', child: Text('ปิดใช้งาน')),
                ],
                onChanged: (v){ if (v!=null) setState(()=> _courtStatusFilter = v); },
              ),
              const Spacer(),
              Text('แสดงผล: ${showing.length}/${filtered.length}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
        if (showing.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('ไม่พบผลลัพธ์'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CourtManagementPage()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('จัดการสนาม'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (showing.isNotEmpty) Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.teal[700]),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'จัดการสนาม',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                    Text(
                      'คลิกปุ่มด้านล่างเพื่อจัดการสนามทั้งหมด',
                      style: TextStyle(color: Colors.teal[600]),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CourtManagementPage()),
                ),
                child: Text('จัดการสนาม'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        if (showing.isNotEmpty) Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: showing.length + 1,
            itemBuilder: (context, index) {
              if (index == showing.length) {
                final more = filtered.length - showing.length;
                if (more <= 0) return const SizedBox.shrink();
                return Center(child: TextButton(onPressed: ()=> setState(()=> _courtsShown += 30), child: Text('โหลดเพิ่ม (+${more.clamp(0,30)})')));
              }
              return _buildCourtCard(showing[index]);
            },
          ),
        ),
      ],
    );
  }

  // Normalize various timestamp representations into a DateTime.
  // Supports DateTime, int (seconds or milliseconds), ISO strings, and Firestore-like maps {seconds,nanoseconds}.
  DateTime _toDateTime(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is DateTime) return v;
    if (v is int) {
      // Heuristic: milliseconds if > 1e12
      if (v > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (v is double) {
      final iv = v.toInt();
      if (iv > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(iv);
      return DateTime.fromMillisecondsSinceEpoch(iv * 1000);
    }
    if (v is String) {
      // Try ISO parse first
      try {
        return DateTime.parse(v);
      } catch (_) {
        final n = num.tryParse(v);
        if (n != null) {
          final iv = n.toInt();
          if (iv > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(iv);
          return DateTime.fromMillisecondsSinceEpoch(iv * 1000);
        }
      }
    }
    if (v is Map) {
      final s = v['seconds'] ?? v['_seconds'];
      final ns = v['nanoseconds'] ?? v['_nanoseconds'] ?? v['nanos'];
      if (s != null) {
        final secs = (s is int) ? s : int.tryParse(s.toString()) ?? 0;
        final nanos = (ns is int) ? ns : int.tryParse(ns.toString()) ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(secs * 1000 + (nanos / 1000000).toInt());
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _buildCourtCard(Map<String, dynamic> court) {
    final isAvailable = court['isAvailable'] ?? true;
    final isActivityOnly = court['isActivityOnly'] ?? false;
    final courtName = court['name'] ?? 'ไม่ระบุชื่อ';
    final courtId = court['id'] ?? '';
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isAvailable 
                ? (isActivityOnly ? Colors.purple[100] : Colors.green[100])
                : Colors.red[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getCourtIcon(court['category']),
            color: isAvailable 
                ? (isActivityOnly ? Colors.purple[700] : Colors.green[700])
                : Colors.red[700],
          ),
        ),
        title: Text(
          courtName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ประเภท: ${_getTypeText(court['type'])} - ${_getCategoryText(court['category'])}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (court['number'] != null) ...[
              Text(
                'หมายเลข: ${court['number']}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isAvailable ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isAvailable ? 'พร้อมใช้' : 'ปิดใช้งาน',
                style: TextStyle(
                  color: isAvailable ? Colors.green[700] : Colors.red[700],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isActivityOnly) ...[
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'กิจกรรม',
                  style: TextStyle(
                    color: Colors.purple[700],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ข้อมูลตำแหน่ง
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ข้อมูลตำแหน่ง',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      if (court['location'] != null && court['location'] is Map) ...[
                        Text('📍 พิกัด:'),
                        Text('  Lat: ${(court['location']['latitude'] as double?)?.toStringAsFixed(6) ?? 'ไม่ระบุ'}'),
                        Text('  Lng: ${(court['location']['longitude'] as double?)?.toStringAsFixed(6) ?? 'ไม่ระบุ'}'),
                        if (court['address'] != null) ...[
                          SizedBox(height: 4),
                          Text('🏠 ที่อยู่: ${court['address']}'),
                        ],
                      ] else ...[
                        Text('ไม่มีข้อมูลตำแหน่ง', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 16),
                // QR Code Section
                Expanded(
                  flex: 1,
                  child: SimpleCourtQRWidget(
                    courtName: courtName,
                    courtId: courtId,
                    size: 120,
                    showControls: true,
                    isPreview: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods สำหรับแปลงข้อมูล
  IconData _getCourtIcon(String? category) {
    switch (category) {
      case 'tennis': return Icons.sports_tennis;
      case 'basketball': return Icons.sports_basketball;
      case 'badminton': return Icons.sports_tennis;
      case 'futsal': return Icons.sports_soccer;
      case 'football': return Icons.sports_soccer;
      case 'volleyball': return Icons.sports_volleyball;
      case 'takraw': return Icons.sports_tennis;
      case 'table_tennis': return Icons.table_restaurant;
      case 'multipurpose': return Icons.sports;
      default: return Icons.sports;
    }
  }

  String _getTypeText(String? type) {
    switch (type) {
      case 'outdoor': return 'กลางแจ้ง';
      case 'indoor': return 'ในร่ม';
      default: return type ?? 'ไม่ระบุ';
    }
  }

  String _getCategoryText(String? category) {
    switch (category) {
      case 'tennis': return 'เทนนิส';
      case 'basketball': return 'บาสเกตบอล';
      case 'badminton': return 'แบดมินตัน';
      case 'futsal': return 'ฟุตซอล';
      case 'football': return 'ฟุตบอล';
      case 'volleyball': return 'วอลเลย์บอล';
      case 'takraw': return 'ตะกร้อ';
      case 'table_tennis': return 'เทเบิลเทนนิส';
      case 'multipurpose': return 'อเนกประสงค์';
      default: return category ?? 'ไม่ระบุ';
    }
  }

  Widget _buildActivityRequestsTab() {
    final base = activityRequests;
    // Apply client-side sort if requested
    List<dynamic> sortedActivities = List.from(base);
    if (_activitiesSort == 'latest') {
      // Sort by createdAt descending (most recent requests first)
      sortedActivities.sort((a, b) => _toDateTime(b['createdAt']).compareTo(_toDateTime(a['createdAt'])));
    } else if (_activitiesSort == 'oldest') {
      // Sort by createdAt ascending
      sortedActivities.sort((a, b) => _toDateTime(a['createdAt']).compareTo(_toDateTime(b['createdAt'])));
    }
    final list0 = _qActivities.trim().isEmpty ? sortedActivities : sortedActivities.where((a){
      final m = (a is Map) ? a : {};
      final q = _qActivities.toLowerCase();
      return (m['courtName']?.toString().toLowerCase() ?? '').contains(q)
        || (m['activityName']?.toString().toLowerCase() ?? '').contains(q)
        || (m['status']?.toString().toLowerCase() ?? '').contains(q)
        || (m['responsiblePersonName']?.toString().toLowerCase() ?? '').contains(q)
        || (m['requesterName']?.toString().toLowerCase() ?? '').contains(q);
    }).toList();
    final filtered = _activityStatusFilter=='all' ? list0 : list0.where((a){
      final s = (a is Map && a['status'] != null) ? a['status'].toString() : '';
      return s == _activityStatusFilter;
    }).toList();
    final showing = filtered.take(_activitiesShown).toList();
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: (showing.isEmpty ? 2 : showing.length + 2),
        itemBuilder: (context, i) {
          if (i == 0) {
                return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ค้นหาคำขอด้วย สนาม กิจกรรม ผู้รับผิดชอบ ผู้ส่งคำขอ สถานะ'), onChanged: (v)=> setState(() { _qActivities = v; _activitiesShown = 30; }))),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _activityStatusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('ทุกสถานะ')),
                    DropdownMenuItem(value: 'pending', child: Text('รอการอนุมัติ')),
                    DropdownMenuItem(value: 'approved', child: Text('อนุมัติแล้ว')),
                    DropdownMenuItem(value: 'rejected', child: Text('ไม่อนุมัติ')),
                  ],
                  onChanged: (v)=> setState(()=> _activityStatusFilter = v ?? 'all'),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _activitiesSort,
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('เรียง: ปกติ')),
                    DropdownMenuItem(value: 'latest', child: Text('เรียง: ล่าสุด')),
                    DropdownMenuItem(value: 'oldest', child: Text('เรียง: เก่า')),
                  ],
                  onChanged: (v) => setState(() => _activitiesSort = v ?? 'none'),
                ),
              ]),
            );
          }
          if (showing.isEmpty && i == 1) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('ไม่พบผลลัพธ์'),
            ));
          }
          if (i == showing.length + 1) {
            final more = filtered.length - showing.length;
            if (more <= 0) return const SizedBox.shrink();
            return Center(child: TextButton(onPressed: ()=> setState(()=> _activitiesShown += 30), child: Text('โหลดเพิ่ม (+${more.clamp(0,30)})')));
          }
          final a = showing[i-1] as Map<String, dynamic>;
          final status = (a['status'] ?? 'pending').toString();
          final court = (a['courtName'] ?? '-').toString();
          final activityName = (a['activityName'] ?? a['activity'] ?? '-').toString();
          final activityDesc = (a['activityDescription'] ?? a['description'] ?? '').toString();
          // Format dates as dd/MM/yyyy
          String _fmt(String s) {
            try { final d = DateTime.tryParse(s); if (d != null) return DateFormat('dd/MM/yyyy').format(d); } catch (_) {}
            return s;
          }
          final dates = (a['activityDates'] is List && (a['activityDates'] as List).isNotEmpty)
              ? (a['activityDates'] as List).map((e) => _fmt(e.toString())).join(', ')
              : _fmt((a['activityDate']?.toString() ?? '-'));
          final respName = (a['responsiblePersonName'] ?? '').toString();
          final respPhone = (a['responsiblePersonPhone'] ?? '').toString();
          final respEmail = (a['responsiblePersonEmail'] ?? '').toString();
          final requester = (a['requesterName'] ?? '').toString();
          final requesterId = (a['requesterStudentId'] ?? '').toString();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(court, style: const TextStyle(fontWeight: FontWeight.bold)),
                      _StatusPill(status: status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('วันที่: $dates'),
                  const SizedBox(height: 6),
                  Text('กิจกรรม: $activityName'),
                  if (activityDesc.isNotEmpty) Text('รายละเอียด: $activityDesc', maxLines: 3, overflow: TextOverflow.ellipsis),
                  Text('ผู้ส่งคำขอ: ${requester.isNotEmpty ? requester : '-'} ${requesterId.isNotEmpty ? '(ID: $requesterId)' : ''}'),
                  Text('ผู้รับผิดชอบ: $respName'),
                  Text('เบอร์: $respPhone'),
                  Text('อีเมล: $respEmail'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (status == 'pending') ...[
                        ElevatedButton.icon(
                          onPressed: () async {
                            await ActivityRequestsService.setStatus(id: a['id'], status: 'approved');
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อนุมัติเรียบร้อย')));
                            await _loadDashboardData();
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('อนุมัติทั้งหมด'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final reason = await _askRejectReason(context);
                            if (reason == null) return;
                            await ActivityRequestsService.setStatus(id: a['id'], status: 'rejected', rejectionReason: reason);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ปฏิเสธคำขอแล้ว')));
                            await _loadDashboardData();
                          },
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('ปฏิเสธ', style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: () async { await _showEditActivityRequestDialog(a); },
                        icon: const Icon(Icons.edit),
                        label: const Text('แก้ไขคำขอ'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final ok = await _confirmDialog('ลบคำขอกิจกรรม', 'ต้องการลบคำขอนี้หรือไม่?');
                          if (ok == true) {
                            final resp = await AdminService.deleteActivityRequest(a['id']);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? resp['error'] ?? '')));
                              await _loadDashboardData();
                            }
                          }
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('ลบคำขอ', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditActivityRequestDialog(Map<String, dynamic> req) async {
    final actNameCtl = TextEditingController(text: (req['activityName'] ?? req['activity'] ?? '').toString());
    final actDescCtl = TextEditingController(text: (req['activityDescription'] ?? req['description'] ?? '').toString());
    final respNameCtl = TextEditingController(text: (req['responsiblePersonName'] ?? '').toString());
    final respPhoneCtl = TextEditingController(text: (req['responsiblePersonPhone'] ?? '').toString());
    final respEmailCtl = TextEditingController(text: (req['responsiblePersonEmail'] ?? '').toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขคำขอกิจกรรม'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: actNameCtl, decoration: const InputDecoration(labelText: 'ชื่อกิจกรรม')), 
              TextField(controller: actDescCtl, decoration: const InputDecoration(labelText: 'รายละเอียดกิจกรรม'), maxLines: 3), 
              TextField(controller: respNameCtl, decoration: const InputDecoration(labelText: 'ผู้รับผิดชอบ')), 
              TextField(controller: respPhoneCtl, decoration: const InputDecoration(labelText: 'เบอร์ผู้รับผิดชอบ')), 
              TextField(controller: respEmailCtl, decoration: const InputDecoration(labelText: 'อีเมลผู้รับผิดชอบ')), 
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
        ],
      ),
    );

    if (saved == true) {
      final payload = {
        'activityName': actNameCtl.text.trim(),
        'activityDescription': actDescCtl.text.trim(),
        'responsiblePersonName': respNameCtl.text.trim(),
        'responsiblePersonPhone': respPhoneCtl.text.trim(),
        'responsiblePersonEmail': respEmailCtl.text.trim(),
      };
      final resp = await AdminService.editActivityRequest(req['id'], payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((resp['success'] == true) ? 'บันทึกคำขอแล้ว' : (resp['error'] ?? 'แก้ไขคำขอไม่สำเร็จ'))),
        );
        await _loadDashboardData();
      }
    }
  }

  Future<String?> _askRejectReason(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('เหตุผลการปฏิเสธ'),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'ระบุเหตุผล')), 
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
            ElevatedButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('ยืนยัน')),
          ],
        );
      }
    );
    if (ok == true) return controller.text.trim();
    return null;
  }

}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});
  Color get _color => status == 'approved' ? Colors.green : status == 'rejected' ? Colors.red : Colors.orange;
  @override
  Widget build(BuildContext context) {
    String label;
    switch (status) {
      case 'approved':
        label = 'อนุมัติแล้ว';
        break;
      case 'rejected':
        label = 'ไม่อนุมัติ';
        break;
      default:
        label = 'รอการอนุมัติ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _color)),
      child: Text(label, style: TextStyle(color: _color)),
    );
  }
}

