import 'package:booking_web_full/EmailVerificationPage.dart';
import 'package:flutter/material.dart';
import 'package:booking_web_full/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/content_service.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;

  void _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final studentId = _studentIdController.text.trim();
    final email = _emailController.text.toLowerCase().trim(); // Normalize email
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('รหัสผ่านและยืนยันรหัสผ่านไม่ตรงกัน'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // ตรวจสอบอีเมล (ยอมรับทุกรูปแบบอีเมล)
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('กรุณากรอกอีเมลที่ถูกต้อง'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // ตรวจสอบเบอร์โทรศัพท์
    if (phone.length != 10 || int.tryParse(phone) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('กรุณากรอกเบอร์โทรศัพท์ที่ถูกต้อง'),
            backgroundColor: Colors.red),
      );
      return;
    }

  // แสดง loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // ตรวจนโยบายสมัครด้วยเมลธรรมดา (ฝั่ง client เพื่อ UX ที่ดี) แต่ฝั่ง server จะตรวจซ้ำ
      try {
        final meta = await ContentService.getContentWithMeta('allow_non_university_registration');
        final allow = ((meta['value'] ?? '1').toString() == '1' || (meta['value'] ?? 'true').toString() == 'true');
        bool isUniEmail = email.endsWith('@silpakorn.edu') || email.endsWith('@su.ac.th');
        if (!allow && !isUniEmail) {
          if (Navigator.canPop(context)) Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('สามารถสมัครได้ด้วยเมล @silpakorn.edu กับ @su.ac.th เท่านั้น'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } catch (_) {}

      print('🚀 Starting registration process for: $email');
      
      // เรียก API สำหรับ register
      final result = await ApiService.register(
        firstName: firstName,
        lastName: lastName,
        studentId: studentId,
        email: email,
        phone: phone,
        password: password,
      );

      print('📊 Registration API response: $result');

      // ปิด loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // ตรวจสอบการตอบสนองจาก API
      if (result['success'] == true) {
        print('✅ Registration successful, navigating to verification page');
        
        // เก็บข้อมูลสำหรับ auto login
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('temp_email', email);
          await prefs.setString('temp_password', password);
          print('💾 Temporary credentials saved');
        } catch (e) {
          print('⚠️ Failed to save temporary credentials: $e');
        }
        
        // นำทางไปหน้ายืนยันอีเมลแทนที่จะกลับไปหน้า login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationPage(
              email: email,
              showResendOption: true,
            ),
          ),
        );
        
        print('🎯 Navigation to EmailVerificationPage completed');
        
      } else {
        // หากมีข้อผิดพลาด
        String errorMessage = result['message'] ?? 'เกิดข้อผิดพลาดในการสมัครสมาชิก';
        print('❌ Registration failed: $errorMessage');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4)),
        );
      }
    } catch (e) {
      print('💥 Exception during registration: $e');
      
      // ปิด loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      String errorMessage = 'เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์';
      
      // แยกประเภทของ error
      if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        if (errorMessage.contains('Error: ')) {
          errorMessage = errorMessage.replaceAll('Error: ', '');
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.teal[700]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'สมัครสมาชิก',
          style: TextStyle(color: Colors.teal[700]),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: isWideScreen ? 500 : double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    'REGISTER',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ระบบจองสนามกีฬา มหาวิทยาลัยศิลปากร',
                    style: TextStyle(color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '📋 สำหรับการสมัครสมาชิก',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• นักศึกษา: ใช้รหัสนักศึกษา\n• บุคคลภายนอก: ใช้เลขบัตรประชาชน 13 หลัก',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                  // ชื่อ
                  TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person),
                      labelText: 'ชื่อ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'กรุณากรอกชื่อ' : null,
                  ),
                  SizedBox(height: 20),
                  // นามสกุล
                  TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person),
                      labelText: 'นามสกุล',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'กรุณากรอกนามสกุล' : null,
                  ),
                  SizedBox(height: 20),
                  // รหัสนักศึกษา / เลขบัตรประชาชน
                  TextFormField(
                    controller: _studentIdController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.badge),
                      labelText: 'รหัสนักศึกษา / เลขบัตรประชาชน',
                      hintText: 'รหัสนักศึกษา หรือ เลขบัตรประชาชน 13 หลัก',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกรหัสนักศึกษาหรือเลขบัตรประชาชน';
                      }
                      // ตรวจสอบว่าเป็นตัวเลขและมีความยาวที่เหมาะสม
                      if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                        return 'กรุณากรอกเฉพาะตัวเลข';
                      }
                      // ยอมรับรหัสนักศึกษา (8-12 หลัก) หรือเลขบัตรประชาชน (13 หลัก)
                      if (value.length < 8 || value.length > 13) {
                        return 'กรุณากรอกรหัสนักศึกษา (8-12 หลัก) หรือเลขบัตรประชาชน (13 หลัก)';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  // อีเมล
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.email),
                      labelText: 'อีเมล',
                      hintText: 'example@email.com',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกอีเมล';
                      }
                      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(value)) {
                        return 'กรุณากรอกอีเมลที่ถูกต้อง';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  // เบอร์โทรศัพท์
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.phone),
                      labelText: 'เบอร์โทรศัพท์',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value!.isEmpty ? 'กรุณากรอกเบอร์โทรศัพท์' : null,
                  ),
                  SizedBox(height: 20),
                  // รหัสผ่าน
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock),
                      labelText: 'รหัสผ่าน',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'กรุณากรอกรหัสผ่าน' : null,
                  ),
                  SizedBox(height: 20),
                  // ยืนยันรหัสผ่าน
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock),
                      labelText: 'ยืนยันรหัสผ่าน',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'กรุณายืนยันรหัสผ่าน' : null,
                  ),
                  SizedBox(height: 30),
                  // ปุ่มสมัครสมาชิก
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _handleSignUp();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[600],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'สมัครสมาชิก',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
