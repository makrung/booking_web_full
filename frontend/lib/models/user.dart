class User {
  final String id;
  final String firstName;
  final String lastName;
  final String studentId; // รหัสนักศึกษา หรือ เลขบัตรประชาชน
  final String email;
  final String phone;
  final bool isActive;
  final int points; // เพิ่มฟิลด์คะแนน
  final bool isEmailVerified; // ฟิลด์สำหรับสถานะการยืนยันอีเมล
  final String? emailVerificationToken; // โทเค็นสำหรับยืนยันอีเมล
  final DateTime? emailVerificationExpiry; // วันหมดอายุของโทเค็น
  final DateTime? createdAt;
  final String userType; // 'student' หรือ 'external' เพื่อแยกประเภทผู้ใช้

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.studentId,
    required this.email,
    required this.phone,
    required this.isActive,
    this.points = 100, // คะแนนเริ่มต้น 100
    this.isEmailVerified = false, // ค่าเริ่มต้นยังไม่ยืนยัน
    this.emailVerificationToken,
    this.emailVerificationExpiry,
    this.createdAt,
    this.userType = 'student', // ค่าเริ่มต้นเป็นนักศึกษา
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      studentId: json['studentId'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      isActive: json['isActive'] ?? true,
      points: json['points'] ?? 100,
      isEmailVerified: json['isEmailVerified'] ?? false,
      emailVerificationToken: json['emailVerificationToken'],
      emailVerificationExpiry: json['emailVerificationExpiry'] != null 
          ? DateTime.parse(json['emailVerificationExpiry']) 
          : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      userType: json['userType'] ?? 'student',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'studentId': studentId,
      'email': email,
      'phone': phone,
      'isActive': isActive,
      'points': points,
      'isEmailVerified': isEmailVerified,
      'emailVerificationToken': emailVerificationToken,
      'emailVerificationExpiry': emailVerificationExpiry?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'userType': userType,
    };
  }

  String get fullName => '$firstName $lastName';
  
  // ตรวจสอบว่าเป็นนักศึกษาหรือไม่
  bool get isStudent => userType == 'student';
  
  // ตรวจสอบว่าเป็นบุคคลภายนอกหรือไม่
  bool get isExternal => userType == 'external';
  
  // ได้ชื่อประเภทผู้ใช้งานเป็นภาษาไทย
  String get userTypeDisplayName => isStudent ? 'นักศึกษา' : 'บุคคลภายนอก';
  
  // ตรวจสอบว่าสามารถจองได้หรือไม่
  bool get canMakeBooking => isActive && points > 0 && isEmailVerified;
  
  // ตรวจสอบว่าโทเค็นยืนยันอีเมลหมดอายุหรือไม่
  bool get isVerificationTokenExpired => 
      emailVerificationExpiry == null || 
      DateTime.now().isAfter(emailVerificationExpiry!);
}
