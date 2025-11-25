import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services/api_service.dart';
import 'config/app_config.dart';
import 'Login.dart';
import 'package:web/web.dart' as html;

class EmailVerificationPage extends StatefulWidget {
  final String email;
  final bool showResendOption;
  
  const EmailVerificationPage({
    Key? key, 
    required this.email,
    this.showResendOption = true,
  }) : super(key: key);

  @override
  _EmailVerificationPageState createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isResending = false;
  bool _canResend = true;
  int _resendCountdown = 0;
  Timer? _resendTimer;
  Timer? _statusCheckTimer;
  Timer? _focusCheckTimer; // เพิ่ม timer สำหรับ focus checking
  
  String _message = '';
  Color _messageColor = Colors.black87;
  bool _isCheckingStatus = false;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _message = 'เราได้ส่งลิงก์ยืนยันไปยังอีเมลของคุณแล้ว';
    
    // Debug: แสดงข้อมูลการเริ่มต้น
    print('EmailVerificationPage initialized for: ${widget.email}');
    print('Starting real-time verification checking...');
    
    // เริ่มการตรวจสอบ real-time
    _startStatusChecking();
    _startFocusChecking();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  void _startFocusChecking() {
    _focusCheckTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // ตรวจสอบ localStorage อย่างรวดเร็ว
      if (!_isCheckingStatus) {
        try {
          final verified = html.window.localStorage.getItem('email_verified');
          if (verified == 'true') {
            html.window.localStorage.removeItem('email_verified');
            _statusCheckTimer?.cancel();
            _focusCheckTimer?.cancel();
            
            if (mounted) {
              setState(() {
                _message = 'พบการยืนยันอีเมลแล้ว!';
                _messageColor = Colors.green[700]!;
              });
              
              // รอ 0.5 วินาทีแล้วแสดง popup
              await Future.delayed(Duration(milliseconds: 500));
              if (mounted) {
                _showSuccessPopup();
              }
            }
            return;
          }
        } catch (e) {
          // localStorage not available
        }
      }
    });
  }

  Future<void> _checkVerificationStatus() async {
    if (_isCheckingStatus) return;
    
    setState(() {
      _isCheckingStatus = true;
      _message = 'กำลังตรวจสอบกับฐานข้อมูล...';
      _messageColor = Colors.blue[600]!;
    });

    try {
      print('Checking verification status in backend for: ${widget.email}');
      
      // เรียก API เพื่อตรวจสอบสถานะจากระบบ
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/check-verification-status/${Uri.encodeComponent(widget.email)}'),
        headers: {'Content-Type': 'application/json'},
      );
      
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['isVerified'] == true) {
          // พบการยืนยันในฐานข้อมูล!
          _statusCheckTimer?.cancel();
          _focusCheckTimer?.cancel();
          
          print('Email verification found in backend!');
          
          if (mounted) {
            setState(() {
              _message = 'พบการยืนยันในฐานข้อมูลแล้ว! 🎉';
              _messageColor = Colors.green[700]!;
            });
            
            // รอ 1 วินาทีแล้วแสดง popup
            await Future.delayed(Duration(seconds: 1));
            if (mounted) {
              _showSuccessPopup();
            }
          }
          return;
        }
      }
      
      // ยังไม่พบการยืนยัน - ยังคงตรวจสอบต่อไป
      if (mounted) {
        setState(() {
          _message = 'เราได้ส่งลิงก์ยืนยันไปยังอีเมลของคุณแล้ว';
          _messageColor = Colors.black87;
        });
      }
      
    } catch (e) {
      print('Verification check error: $e');
      
      // ถ้า API ล้มเหลว ลองตรวจสอบ localStorage เป็น fallback
      try {
  final verified = html.window.localStorage.getItem('email_verified');
  final verificationTime = html.window.localStorage.getItem('verification_time');
        
        print('Fallback to localStorage: verified=$verified, time=$verificationTime');
        
        if (verified == 'true') {
          html.window.localStorage.removeItem('email_verified');
          html.window.localStorage.removeItem('verification_time');
          
          _statusCheckTimer?.cancel();
          _focusCheckTimer?.cancel();
          
          if (mounted) {
            setState(() {
              _message = 'พบการยืนยันอีเมลแล้ว! (จาก localStorage)';
              _messageColor = Colors.green[700]!;
            });
            
            await Future.delayed(Duration(seconds: 1));
            if (mounted) {
              _showSuccessPopup();
            }
          }
          return;
        }
      } catch (localStorageError) {
        print('localStorage fallback error: $localStorageError');
      }
      
      // แสดงข้อความปกติถ้าทั้ง API และ localStorage ล้มเหลว
      if (mounted) {
        setState(() {
          _message = 'เราได้ส่งลิงก์ยืนยันไปยังอีเมลของคุณแล้ว';
          _messageColor = Colors.black87;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
        });
      }
    }
  }

  void _startStatusChecking() {
    // เริ่มตรวจสอบทันทีหลังจาก 2 วินาที
    Timer(Duration(seconds: 2), () {
      if (mounted) _checkVerificationStatus();
    });
    
    // ตรวจสอบทุก 3 วินาที
    _statusCheckTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _checkVerificationStatus();
    });
  }

  void _showSuccessPopup() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 16,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green[400]!, Colors.green[600]!],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 64,
                ),
                SizedBox(height: 16),
                Text(
                  'ยืนยันอีเมลสำเร็จ!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'คุณสามารถเข้าสู่ระบบได้แล้ว',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // ปิด popup
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginPage(
                          verificationSuccess: true,
                          successMessage: 'ยืนยันอีเมลสำเร็จ! กรุณาเข้าสู่ระบบ',
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'ไปหน้าเข้าสู่ระบบ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green[600],
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
      _canResend = false;
    });

    try {
      final response = await ApiService.resendVerificationEmail(email: widget.email);
      
      if (response['success']) {
        setState(() {
          _message = 'ส่งอีเมลยืนยันใหม่แล้ว กรุณาตรวจสอบอีเมลของคุณ';
          _messageColor = Colors.green[700]!;
        });
        
        // เริ่มนับถอยหลัง 60 วินาที
        _resendCountdown = 60;
        _resendTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          setState(() {
            _resendCountdown--;
          });
          
          if (_resendCountdown <= 0) {
            timer.cancel();
            setState(() {
              _canResend = true;
            });
          }
        });
      } else {
        setState(() {
          _message = response['message'] ?? 'เกิดข้อผิดพลาดในการส่งอีเมล';
          _messageColor = Colors.red[700]!;
          _canResend = true;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'เกิดข้อผิดพลาดในการเชื่อมต่อ กรุณาลองใหม่อีกครั้ง';
        _messageColor = Colors.red[700]!;
        _canResend = true;
      });
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  @override
  void dispose() {
    print('EmailVerificationPage disposing...');
    _animationController.dispose();
    _resendTimer?.cancel();
    _statusCheckTimer?.cancel();
    _focusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F8FF),
      appBar: AppBar(
        title: Text(
          'ยืนยันอีเมล',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF0F8FF),
              Color(0xFFE1F5FE),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 40),
                    
                    // Email Icon
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.email_outlined,
                        size: 64,
                        color: Colors.blue[700],
                      ),
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Title
                    Text(
                      'ยืนยันอีเมลของคุณ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Email address
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.email, color: Colors.blue[600], size: 20),
                          SizedBox(width: 8),
                          Text(
                            widget.email,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Status message
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _messageColor == Colors.green[700] 
                            ? Colors.green[50] 
                            : _messageColor == Colors.blue[600]
                                ? Colors.blue[50]
                                : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _messageColor == Colors.green[700] 
                              ? Colors.green[200]! 
                              : _messageColor == Colors.blue[600]
                                  ? Colors.blue[200]!
                                  : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_isCheckingStatus)
                            Container(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(_messageColor),
                              ),
                            )
                          else
                            Icon(
                              _messageColor == Colors.green[700] 
                                  ? Icons.check_circle_outline
                                  : Icons.info_outline,
                              color: _messageColor,
                              size: 20,
                            ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _message,
                              style: TextStyle(
                                fontSize: 16,
                                color: _messageColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Instructions
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline, color: Colors.orange[600]),
                              SizedBox(width: 8),
                              Text(
                                'วิธีการยืนยัน',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          _buildInstructionStep(
                            '1',
                            'ตรวจสอบอีเมลในกล่องขาเข้า',
                            Icons.inbox,
                          ),
                          _buildInstructionStep(
                            '2',
                            'คลิกลิงก์ยืนยันในอีเมล',
                            Icons.link,
                          ),
                          _buildInstructionStep(
                            '3',
                            'ระบบจะตรวจสอบอัตโนมัติ',
                            Icons.autorenew,
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.blue[600], size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'ระบบตรวจสอบสถานะแบบอัตโนมัติทุก 3 วินาที',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Action buttons
                    if (widget.showResendOption)
                      Column(
                        children: [
                          Text(
                            'ไม่ได้รับอีเมล?',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _canResend && !_isResending ? _resendVerificationEmail : null,
                                icon: _isResending 
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Icon(Icons.refresh),
                                label: Text(
                                  _isResending 
                                      ? 'กำลังส่ง...'
                                      : _canResend 
                                          ? 'ส่งอีเมลใหม่'
                                          : 'ส่งใหม่ได้ใน ${_resendCountdown}s',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[600],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  // ยกเลิกการสมัคร และลบข้อมูลผู้ใช้ที่ยังไม่ยืนยัน
                                  setState(() { _message = 'กำลังยกเลิกการสมัคร...'; _messageColor = Colors.red[700]!; });
                                  final resp = await ApiService.cancelRegistration(email: widget.email);
                                  if (mounted) {
                                    if (resp['success'] == true) {
                                      _statusCheckTimer?.cancel();
                                      _focusCheckTimer?.cancel();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('ยกเลิกการสมัครเรียบร้อยแล้ว'), backgroundColor: Colors.green)
                                      );
                                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(resp['message'] ?? 'ยกเลิกไม่สำเร็จ'), backgroundColor: Colors.red)
                                      );
                                    }
                                  }
                                },
                                icon: Icon(Icons.cancel, color: Colors.red[700]),
                                label: Text('ยกเลิกการสมัคร'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.red[300]!),
                                  foregroundColor: Colors.red[700],
                                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    
                    SizedBox(height: 24),
                    
                    // Back to login
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginPage(),
                          ),
                        );
                      },
                      child: Text(
                        'กลับไปหน้าเข้าสู่ระบบ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
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

  Widget _buildInstructionStep(String number, String text, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.blue[600],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Icon(icon, color: Colors.grey[600], size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
