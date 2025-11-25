import 'package:booking_web_full/Schedule.dart';
import 'package:flutter/material.dart';
import 'Login.dart';
import 'services/auth_service.dart';
import 'NewsPage.dart';
import 'services/news_service.dart';
import 'models/news.dart';
import 'package:marquee/marquee.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SILPAKORN STADIUM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Segoe UI',
        scaffoldBackgroundColor: Color(0xFFF0F8FF),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.teal[700],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  NewsItem? _latestNews;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadLatestNews();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // รีเฟรชสถานะการล็อกอินเมื่อกลับมาที่หน้านี้
    _checkLoginStatus();
  }

  Future<void> _loadLatestNews() async {
    try {
      final latest = await NewsService.latest();
      if (mounted) setState(() => _latestNews = latest);
    } catch (e) {
      // ignore silently on home
    }
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    final isAdmin = await AuthService.isAdmin();
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isAdmin = isAdmin;
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('ออกจากระบบ'),
          ],
        ),
        content: Text('คุณต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('ออกจากระบบ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthService.logout();
        setState(() {
          _isLoggedIn = false;
        });
        
        // แสดงข้อความยืนยัน
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ออกจากระบบสำเร็จ'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการออกจากระบบ'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showContactInfo() {
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
              IconButton(
                icon: Icon(Icons.article, color: Colors.white),
                tooltip: 'ข่าวสาร',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NewsPage()),
                  );
                },
              ),
              // ปุ่ม Admin Dashboard (แสดงเฉพาะสำหรับ admin)
              if (_isLoggedIn && _isAdmin)
                IconButton(
                  icon: Icon(Icons.admin_panel_settings, color: Colors.white),
                  onPressed: () {
                    Navigator.pushNamed(context, '/admin-dashboard');
                  },
                  tooltip: 'หน้าแดชบอร์ดแอดมิน',
                ),
              
              // แสดงปุ่มออกจากระบบเมื่อล็อกอินแล้ว
              if (_isLoggedIn)
                PopupMenuButton<String>(
                  icon: Icon(Icons.account_circle, color: Colors.white, size: 28),
                  onSelected: (value) async {
                    if (value == 'logout') {
                      await _handleLogout();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
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
                )
              else
                IconButton(
                  icon: Icon(Icons.login, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LoginPage()),
                    );
                  },
                  tooltip: 'เข้าสู่ระบบ',
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SILPAKORN STADIUM',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'ระบบจองสนามกีฬา มหาวิทยาลัยศิลปากร',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                  ),
                ],
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
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
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
                  
                  // Navigation Buttons Section
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
                    child: Column(
                      children: [
                        // แสดงสถานะการล็อกอิน
                        if (!_isLoggedIn)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'กรุณาเข้าสู่ระบบเพื่อใช้งานฟีเจอร์จองสนามและดูตาราง',
                                    style: TextStyle(
                                      color: Colors.orange[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        Wrap(
                          spacing: 15,
                          runSpacing: 15,
                          alignment: WrapAlignment.center,
                          children: [
                            // ปุ่มเข้าสู่ระบบ/หน้าผู้ใช้
                            NavButton(
                              label: _isLoggedIn ? 'หน้าผู้ใช้' : 'เข้าสู่ระบบ',
                              icon: _isLoggedIn ? Icons.person : Icons.login,
                              isEnabled: true,
                              onTap: () {
                                if (_isLoggedIn) {
                                  Navigator.pushNamed(context, '/user-home');
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => LoginPage()),
                                  );
                                }
                              },
                            ),
                            // ปุ่มข่าวสาร
                            NavButton(
                              label: 'ข่าวสาร',
                              icon: Icons.article,
                              isEnabled: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => NewsPage()),
                                );
                              },
                            ),
                            // ปุ่มแดชบอร์ดแอดมิน - แสดงเฉพาะเมื่อเป็นแอดมิน
                            if (_isLoggedIn && _isAdmin)
                              NavButton(
                                label: 'แดชบอร์ดแอดมิน',
                                icon: Icons.admin_panel_settings,
                                isEnabled: true,
                                onTap: () async {
                                  final currentUser = await AuthService.getCurrentUser();
                                  if (currentUser != null) {
                                    Navigator.pushNamed(context, '/admin-dashboard');
                                  }
                                },
                              ),
                            // ปุ่มตารางสนาม - แสดงเฉพาะเมื่อล็อกอินแล้ว
                            if (_isLoggedIn)
                              NavButton(
                                label: 'ตารางสนาม',
                                icon: Icons.schedule,
                                isEnabled: true,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => SchedulePage()),
                                  );
                                },
                              ),
                            // ปุ่มติดต่อ - แสดงเสมอ
                            NavButton(
                              label: 'ติดต่อ',
                              icon: Icons.contact_support,
                              isEnabled: true,
                              onTap: () {
                                _showContactInfo();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 40),

                  // Latest News Ticker
                  if (_latestNews != null) ...[
                    Container(
                      width: double.infinity,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal[200]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.teal[600],
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.campaign, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('ข่าวสารล่าสุด', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Marquee(
                              text: '${_latestNews!.title}  —  ${_latestNews!.contentText}',
                              blankSpace: 60,
                              velocity: 30,
                              style: TextStyle(color: Colors.teal[900]),
                              pauseAfterRound: Duration(seconds: 1),
                              startPadding: 12,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.open_in_new, color: Colors.teal[700]),
                            tooltip: 'เปิดข่าว',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => NewsPage()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                  
                  // Welcome Message
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
                          _isLoggedIn 
                              ? 'ยินดีต้อนรับกลับ!'
                              : 'ยินดีต้อนรับสู่ระบบจองสนามกีฬา ม.ศิลปากร',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          _isLoggedIn 
                              ? 'กดปุ่ม "หน้าผู้ใช้" เพื่อเริ่มจองสนามกีฬา'
                              : 'กรุณาเข้าสู่ระบบเพื่อใช้งานฟีเจอร์จองสนามและดูตาราง',
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
                  
                  // Sports Fields Section
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
                  
                  // Instructions
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
                            _isLoggedIn 
                                ? 'คุณสามารถเข้าไปจองสนามได้ในหน้าผู้ใช้'
                                : 'กรุณาเข้าสู่ระบบเพื่อใช้งานระบบจองสนาม',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.teal[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 40),
                  
                  // Footer
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

class NavButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isEnabled;

  const NavButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isEnabled = true,
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
              boxShadow: widget.isEnabled ? [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ] : [],
            ),
            child: ElevatedButton(
              onPressed: widget.isEnabled ? () {
                _animationController.forward().then((_) {
                  _animationController.reverse();
                  widget.onTap();
                });
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isEnabled ? Colors.teal[600] : Colors.grey[400],
                foregroundColor: widget.isEnabled ? Colors.white : Colors.grey[600],
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
            _animationController.forward();
          },
          onExit: (_) {
            _animationController.reverse();
          },
          child: Card(
            elevation: _elevationAnimation.value,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.teal[50]!,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                        image: DecorationImage(
                          image: AssetImage(widget.image),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            widget.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.teal[600],
                            ),
                            textAlign: TextAlign.center,
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
