import 'app_constants.dart';

class ActivityRequest {
  final String id;
  final String responsiblePersonName;
  final String responsiblePersonId;
  final String responsiblePersonPhone;
  final String responsiblePersonEmail;
  final String activityName;
  final String activityDescription;
  final DateTime activityDate;
  final String timeSlot;
  final String courtId;
  final String organizationDocument; // เอกสารจากหน่วยงาน
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime requestDate;
  final String? rejectionReason;
  final String? approvedBy;
  final DateTime? approvedDate;

  ActivityRequest({
    required this.id,
    required this.responsiblePersonName,
    required this.responsiblePersonId,
    required this.responsiblePersonPhone,
    required this.responsiblePersonEmail,
    required this.activityName,
    required this.activityDescription,
    required this.activityDate,
    required this.timeSlot,
    required this.courtId,
    required this.organizationDocument,
    this.status = ActivityRequestStatus.pending,
    required this.requestDate,
    this.rejectionReason,
    this.approvedBy,
    this.approvedDate,
  }) : assert(ActivityRequestStatus.isValid(status), 'Invalid status: $status');

  factory ActivityRequest.fromJson(Map<String, dynamic> json) {
    return ActivityRequest(
      id: json['id'] ?? '',
      responsiblePersonName: json['responsiblePersonName'] ?? '',
      responsiblePersonId: json['responsiblePersonId'] ?? '',
      responsiblePersonPhone: json['responsiblePersonPhone'] ?? '',
      responsiblePersonEmail: json['responsiblePersonEmail'] ?? '',
      activityName: json['activityName'] ?? '',
      activityDescription: json['activityDescription'] ?? '',
      activityDate: DateTime.parse(json['activityDate']),
      timeSlot: json['timeSlot'] ?? '',
      courtId: json['courtId'] ?? '',
      organizationDocument: json['organizationDocument'] ?? '',
      status: json['status'] ?? ActivityRequestStatus.pending,
      requestDate: DateTime.parse(json['requestDate']),
      rejectionReason: json['rejectionReason'],
      approvedBy: json['approvedBy'],
      approvedDate: json['approvedDate'] != null 
          ? DateTime.parse(json['approvedDate']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'responsiblePersonName': responsiblePersonName,
      'responsiblePersonId': responsiblePersonId,
      'responsiblePersonPhone': responsiblePersonPhone,
      'responsiblePersonEmail': responsiblePersonEmail,
      'activityName': activityName,
      'activityDescription': activityDescription,
      'activityDate': activityDate.toIso8601String(),
      'timeSlot': timeSlot,
      'courtId': courtId,
      'organizationDocument': organizationDocument,
      'status': status,
      'requestDate': requestDate.toIso8601String(),
      'rejectionReason': rejectionReason,
      'approvedBy': approvedBy,
      'approvedDate': approvedDate?.toIso8601String(),
    };
  }

  // เช็คว่าคำขอหมดอายุหรือไม่
  bool get isExpired {
    final now = DateTime.now();
    const expireDays = 30; // จำนวนวันที่คำขอหมดอายุ
    return now.difference(requestDate).inDays > expireDays;
  }

  // สถานะเป็นข้อความ (ใช้ constants แทน)
  String get statusText => ActivityRequestStatus.getStatusText(status);

  // สีสถานะ (ใช้ constants แทน)
  String get statusColor => ActivityRequestStatus.getStatusColor(status);
  
  // เช็คว่าสถานะเป็น pending
  bool get isPending => status == ActivityRequestStatus.pending;
  
  // เช็คว่าสถานะเป็น approved
  bool get isApproved => status == ActivityRequestStatus.approved;
  
  // เช็คว่าสถานะเป็น rejected
  bool get isRejected => status == ActivityRequestStatus.rejected;
  
  // คัดลอก object พร้อมแก้ไขบางฟิลด์
  ActivityRequest copyWith({
    String? id,
    String? responsiblePersonName,
    String? responsiblePersonId,
    String? responsiblePersonPhone,
    String? responsiblePersonEmail,
    String? activityName,
    String? activityDescription,
    DateTime? activityDate,
    String? timeSlot,
    String? courtId,
    String? organizationDocument,
    String? status,
    DateTime? requestDate,
    String? rejectionReason,
    String? approvedBy,
    DateTime? approvedDate,
  }) {
    return ActivityRequest(
      id: id ?? this.id,
      responsiblePersonName: responsiblePersonName ?? this.responsiblePersonName,
      responsiblePersonId: responsiblePersonId ?? this.responsiblePersonId,
      responsiblePersonPhone: responsiblePersonPhone ?? this.responsiblePersonPhone,
      responsiblePersonEmail: responsiblePersonEmail ?? this.responsiblePersonEmail,
      activityName: activityName ?? this.activityName,
      activityDescription: activityDescription ?? this.activityDescription,
      activityDate: activityDate ?? this.activityDate,
      timeSlot: timeSlot ?? this.timeSlot,
      courtId: courtId ?? this.courtId,
      organizationDocument: organizationDocument ?? this.organizationDocument,
      status: status ?? this.status,
      requestDate: requestDate ?? this.requestDate,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedDate: approvedDate ?? this.approvedDate,
    );
  }
  
  @override
  String toString() {
    return 'ActivityRequest(id: $id, activityName: $activityName, status: $status)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityRequest && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}
