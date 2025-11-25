import 'package:flutter/material.dart';
import 'dart:async';
import 'services/api_service.dart';
import 'Login.dart';
import 'UserHomePage.dart';

class EmailVerificationSuccessPage extends StatefulWidget {
  final String? token;
  final String? email;
  final String? password;
  
  const EmailVerificationSuccessPage({
    Key? key, 
    this.token,
    this.email,
    this.password,
  }) : super(key: key);

  @override
  _EmailVerificationSuccessPageState createState() => _EmailVerificationSuccessPageState();
}

class _EmailVerificationSuccessPageState extends State<EmailVerificationSuccessPage>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late AnimationController _checkAnimationController;
  late AnimationController _countdownController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _colorAnimation;
  
  bool _isVerifying = true;
  bool _verificationSuccess = false;
  bool _isAutoLoggingIn = false;
  String _message = 'กำลังยืนยันอีเมล...';
  String _errorMessage = '';
  bool _tokenExpired = false;
  int _countdown = 3;
  Timer? _countdownTimer;
  String? _userName;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    if (widget.token != null) {
      _verifyEmail();
    } else {
      setState(() {
        _isVerifying = false;
        _verificationSuccess = false;
        _errorMessage = 'ไม่พบโทเค็นยืนยัน';
      });
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _checkAnimationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _countdownController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _checkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkAnimationController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _countdownController,
      curve: Curves.easeInOut,
    ));

    _colorAnimation = ColorTween(
      begin: Colors.blue[600],
      end: Colors.green[600],
    ).animate(CurvedAnimation(
      parent: _checkAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _checkAnimationController.dispose();
    _countdownController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    try {
      final response = await ApiService.verifyEmail(widget.token!);
      
      if (response['success'] == true) {
        setState(() {
          _isVerifying = false;
          _verificationSuccess = true;
          _message = 'ยืนยันอีเมลสำเร็จ!';
          _userName = 'ผู้ใช้'; // ไม่มีข้อมูลผู้ใช้จาก API
        });
        
        await _checkAnimationController.forward();
        
        // เริ่มการเข้าสู่ระบบอัตโนมัติ
        await Future.delayed(Duration(milliseconds: 800));
        _startAutoLogin();
        
      } else {
        setState(() {
          _isVerifying = false;
          _verificationSuccess = false;
          _errorMessage = response['error'] ?? 'ไม่สามารถยืนยันอีเมลได้';
          if (response['expired'] == true) {
            _tokenExpired = true;
          }
        });
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _verificationSuccess = false;
        _errorMessage = 'เกิดข้อผิดพลาดในการเชื่อมต่อ';
      });
    }
  }

  void _startAutoLogin() async {
    setState(() {
      _isAutoLoggingIn = true;
    });

    // เริ่มนับถอยหลัง
    _countdownController.forward();
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _countdown--;
          if (_countdown <= 0) {
            timer.cancel();
            _performAutoLogin();
          }
        });
      }
    });
  }

  void _performAutoLogin() async {
    if (widget.email != null && widget.password != null) {
      try {
        final loginResponse = await ApiService.login(
          email: widget.email!,
          password: widget.password!,
        );

        if (loginResponse['success'] == true && mounted) {
          // บันทึก token และข้อมูลผู้ใช้
          await ApiService.saveToken(loginResponse['token']);
          
          // ไปหน้า UserHomePage
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => UserHomePage(
                username: _userName ?? loginResponse['user']?['firstName'] ?? 'ผู้ใช้',
              ),
            ),
            (route) => false,
          );
        } else {
          // หากเข้าสู่ระบบไม่สำเร็จ ให้ไปหน้า Login
          _goToLoginWithSuccess();
        }
      } catch (e) {
        // หากเกิดข้อผิดพลาด ให้ไปหน้า Login
        _goToLoginWithSuccess();
      }
    } else {
      // หากไม่มีข้อมูลสำหรับ auto login
      _goToLoginWithSuccess();
    }
  }

  void _goToLoginWithSuccess() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginPage(),
        ),
        (route) => false,
      );
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  void _resendVerificationEmail() async {
    try {
      final response = await ApiService.resendVerificationEmail(email: widget.email ?? '');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['success'] == true 
              ? 'ส่งอีเมลยืนยันใหม่แล้ว' 
              : 'ไม่สามารถส่งอีเมลได้'),
          backgroundColor: response['success'] == true ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A8A), // มหาวิทยาลัยศิลปกรรม - น้ำเงินเข้ม
              Color(0xFF3B82F6), // น้ำเงินกลาง
              Color(0xFFF5F7FA), // ขาวอ่อน
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // University Logo Area
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.school,
                        size: 60,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    
                    SizedBox(height: 30),
                    
                    // University Name
                    Text(
                      'มหาวิทยาลัยศิลปกรรมศาสตร์',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: 10),
                    
                    Text(
                      'ระบบจองสนามกีฬา',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: 50),
                    
                    // Main Content Card
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(maxWidth: 400),
                      padding: EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 25,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Status Icon
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _verificationSuccess 
                                      ? [Color(0xFF10B981), Color(0xFF059669)] // เขียวสำเร็จ
                                      : _isVerifying
                                          ? [Color(0xFF3B82F6), Color(0xFF1D4ED8)] // น้ำเงินรอ
                                          : [Color(0xFFEF4444), Color(0xFFDC2626)], // แดงผิดพลาด
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_verificationSuccess ? Color(0xFF10B981) : Color(0xFF3B82F6)).withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: _isVerifying
                                  ? _buildLoadingIcon()
                                  : _verificationSuccess
                                      ? _buildSuccessIcon()
                                      : _buildErrorIcon(),
                            ),
                          ),
                          
                          SizedBox(height: 30),
                          
                          // Title
                          Text(
                            _isVerifying 
                                ? 'กำลังยืนยันอีเมล'
                                : _verificationSuccess
                                    ? 'ยืนยันสำเร็จ!'
                                    : 'ยืนยันไม่สำเร็จ',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _verificationSuccess 
                                  ? Color(0xFF059669)
                                  : _isVerifying 
                                      ? Color(0xFF1D4ED8)
                                      : Color(0xFFDC2626),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          SizedBox(height: 20),
                          
                          // Message
                          Text(
                            _isVerifying 
                                ? 'กรุณารอสักครู่...'
                                : _verificationSuccess
                                    ? 'ยินดีต้อนรับสู่ระบบจองสนามกีฬา\nของมหาวิทยาลัยศิลปกรรมศาสตร์'
                                    : _errorMessage,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          // Auto Login Section
                          if (_isAutoLoggingIn && _verificationSuccess) ...[
                            SizedBox(height: 30),
                            
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF10B981).withValues(alpha: 0.3),
                                          blurRadius: 15,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(height: 15),
                                        Text(
                                          'กำลังเข้าสู่ระบบอัตโนมัติ',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          'ใน $_countdown วินาที',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 30),
                    
                    // Action Buttons
                    if (!_isVerifying && !_isAutoLoggingIn) ...[
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(maxWidth: 300),
                        child: _verificationSuccess 
                            ? _buildSuccessButton()
                            : _buildErrorButtons(),
                      ),
                    ],
                    
                    SizedBox(height: 20),
                    
                    // Footer
                    Text(
                      '© 2025 มหาวิทยาลัยศิลปกรรมศาสตร์',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIcon() {
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: Duration(seconds: 2),
        tween: Tween(begin: 0, end: 2 * 3.14159),
        builder: (context, value, child) {
          return Transform.rotate(
            angle: value,
            child: Icon(
              Icons.refresh,
              size: 50,
              color: Colors.white,
            ),
          );
        },
        onEnd: () {
          // Repeat animation automatically
          if (mounted && _isVerifying) {
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return ScaleTransition(
      scale: _checkAnimation,
      child: Icon(
        Icons.check_circle,
        size: 60,
        color: Colors.white,
      ),
    );
  }

  Widget _buildErrorIcon() {
    return Icon(
      Icons.error,
      size: 60,
      color: Colors.white,
    );
  }

  Widget _buildSuccessButton() {
    return ElevatedButton.icon(
      onPressed: _goToLogin,
      icon: Icon(Icons.login, size: 24),
      label: Text(
        'เข้าสู่ระบบ',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF059669),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 8,
        shadowColor: Color(0xFF059669).withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildErrorButtons() {
    return Column(
      children: [
        if (_tokenExpired) ...[
          ElevatedButton.icon(
            onPressed: _resendVerificationEmail,
            icon: Icon(Icons.refresh, size: 24),
            label: Text(
              'ส่งอีเมลยืนยันใหม่',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEA580C),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 5,
            ),
          ),
          SizedBox(height: 16),
        ],
        OutlinedButton.icon(
          onPressed: _goToLogin,
          icon: Icon(Icons.arrow_back, size: 20),
          label: Text(
            'กลับไปหน้าเข้าสู่ระบบ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Color(0xFF1D4ED8),
            side: BorderSide(color: Color(0xFF1D4ED8), width: 2),
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ],
    );
  }
}
