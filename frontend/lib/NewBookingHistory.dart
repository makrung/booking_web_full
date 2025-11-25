import 'package:flutter/material.dart';
import 'services/booking_service.dart';
import 'models/app_constants.dart';
import 'package:intl/intl.dart';

class BookingHistoryPage extends StatefulWidget {
  @override
  _BookingHistoryPageState createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  List<dynamic> bookings = [];
  bool isLoading = true;
  String? error;
  String _qHistory = '';
  String _status = 'all'; // all|pending|confirmed|cancelled
  DateTimeRange? _dateRange;

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
      print('Loading user bookings...'); // Debug
      final result = await BookingService.getUserBookings();
      print('BookingService result: $result'); // Debug
      
      if (result['success']) {
        final loadedBookings = result['bookings'] as List;
        print('Loaded ${loadedBookings.length} bookings'); // Debug
        
        setState(() {
          bookings = loadedBookings;
          isLoading = false;
        });
      } else {
        throw Exception(result['error'] ?? 'ไม่สามารถโหลดประวัติการจองได้');
      }
    } catch (e) {
      print('Error loading bookings: $e'); // Debug
      setState(() {
        error = 'เกิดข้อผิดพลาดในการโหลดประวัติการจอง: $e';
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SILPAKORN STADIUM', style: TextStyle(fontSize: 18)),
            Text(
              'ประวัติการจองสนามกีฬา',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
    body: isLoading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        error!,
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBookings,
                        child: Text('ลองใหม่'),
                      ),
                    ],
                  ),
                )
              : bookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'ยังไม่มีประวัติการจอง',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filtered().length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ค้นหาจาก ชื่อสนาม วันที่ เวลา ประเภท'),
                                    onChanged: (v) => setState(() => _qHistory = v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: _status,
                                  items: const [
                                    DropdownMenuItem(value: 'all', child: Text('ทุกสถานะ')),
                                    DropdownMenuItem(value: 'pending', child: Text('รอดำเนินการ')),
                                    DropdownMenuItem(value: 'confirmed', child: Text('อนุมัติแล้ว')),
                                    DropdownMenuItem(value: 'cancelled', child: Text('ยกเลิก')),
                                  ],
                                  onChanged: (v) => setState(() => _status = v ?? 'all'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    final picked = await showDateRangePicker(
                                      context: context,
                                      firstDate: DateTime(now.year - 2),
                                      lastDate: DateTime(now.year + 1),
                                      initialDateRange: _dateRange,
                                    );
                                    if (picked != null) setState(() => _dateRange = picked);
                                  },
                                  icon: const Icon(Icons.date_range),
                                  label: Text(_dateRange == null
                                      ? 'เลือกช่วงวัน'
                                      : '${DateFormat('dd/MM/yy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yy').format(_dateRange!.end)}'),
                                ),
                              ]),
                            );
                          }
                          final booking = _filtered()[index-1] as Map<String, dynamic>;
                          return _buildBookingCard(booking);
                        },
                      ),
                    ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] ?? BookingStatus.pending;
    final statusColor = BookingStatus.statusColors[status] ?? '#9E9E9E';
    final Color cardColor = Color(int.parse(statusColor.replaceFirst('#', '0xFF')));
    final statusIcon = BookingStatus.statusIcons[status] ?? '📋';
    final statusMessage = BookingStatus.statusMessages[status] ?? 'ไม่ทราบสถานะ';

    // Parse date
    DateTime? bookingDate;
    try {
      bookingDate = DateTime.parse(booking['date']);
    } catch (e) {
      // Handle parsing error
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardColor.withValues(alpha: 0.3), width: 2),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sports_tennis, color: Colors.teal, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking['courtName'] ?? 'ไม่ทราบชื่อสนาม',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                  ),
                  if ((booking['role'] ?? '') == 'participant')
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Text(
                        'ใช้โค้ดร่วม',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(statusIcon, style: TextStyle(fontSize: 16)),
                        SizedBox(width: 4),
                        Text(
                          statusMessage,
                          style: TextStyle(
                            color: cardColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    bookingDate != null
                        ? DateFormat('d MMM yyyy').format(bookingDate)
                        : booking['date'] ?? 'ไม่ทราบวันที่',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatTimeSlots(booking),
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.category, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    booking['activityType'] ?? 'ไม่ทราบประเภท',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
              if (booking['note'] != null && booking['note'].isNotEmpty) ...[
                SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking['note'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],
              // เพิ่มข้อความเตือนสำหรับสถานะ pending
              if (booking['status'] == 'pending') ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[600], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ℹ️ สามารถใช้สนามได้ตามปกติขณะรอตรวจสอบการใช้งาน',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[600], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚠️ หากพบว่าจองแล้วไม่ใช้สนาม จะเสียคะแนนการใช้งานสนาม',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'จองเมื่อ: ${_formatTimestamp(booking['createdAt'])}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                    if ((booking['status'] == 'pending' || booking['status'] == 'approved') && _canCancelByTime(booking))
                      TextButton(
                        onPressed: () => _showCancelDialog(booking),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: Text('ยกเลิก'),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
    // ห้ามยกเลิกถ้าถึงเวลาเริ่มแล้ว
    bool _canCancelByTime(Map<String, dynamic> booking) {
      try {
        final dateStr = booking['date']?.toString();
        final timeSlots = booking['timeSlots'] is List ? List<String>.from(booking['timeSlots']) : [];
        if (dateStr == null || timeSlots.isEmpty) return true;
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final normalizedDate = dateStr.contains('T') ? dateStr.split('T')[0] : dateStr;
        int? earliestStartMins;
        for (final slot in timeSlots) {
          if (!slot.contains('-')) continue;
          final startStr = slot.split('-')[0];
          final parts = startStr.split(':');
          if (parts.length == 2) {
            final h = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            if (h != null && m != null) {
              final mins = h * 60 + m;
              earliestStartMins = earliestStartMins == null ? mins : (mins < earliestStartMins ? mins : earliestStartMins);
            }
          }
        }
        if (normalizedDate == todayStr && earliestStartMins != null) {
          final nowMins = now.hour * 60 + now.minute;
          if (nowMins >= earliestStartMins) return false;
        }
        if (normalizedDate.compareTo(todayStr) < 0) return false;
        return true;
      } catch (_) {
        return true;
      }
    }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return 'ไม่ทราบเวลา';
      
      DateTime dateTime;
      if (timestamp is Map && timestamp.containsKey('_seconds')) {
        // Firestore timestamp
        dateTime = DateTime.fromMillisecondsSinceEpoch(
          timestamp['_seconds'] * 1000,
        );
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'ไม่ทราบเวลา';
      }
      
      return DateFormat('d MMM yyyy HH:mm').format(dateTime);
    } catch (e) {
      return 'ไม่ทราบเวลา';
    }
  }

  List<dynamic> _filtered() {
    final q = _qHistory.trim().toLowerCase();
    return bookings.where((b) {
      final m = (b is Map) ? b : {};
      // Text match
      final textOk = q.isEmpty ||
          (m['courtName']?.toString().toLowerCase() ?? '').contains(q) ||
          (m['date']?.toString().toLowerCase() ?? '').contains(q) ||
          (m['timeSlots']?.toString().toLowerCase() ?? '').contains(q) ||
          (m['activityType']?.toString().toLowerCase() ?? '').contains(q) ||
          (m['activityName']?.toString().toLowerCase() ?? '').contains(q) ||
          (m['status']?.toString().toLowerCase() ?? '').contains(q);
      // Status filter
      final statusStr = (m['status']?.toString() ?? '').toLowerCase();
      final statusOk = _status == 'all' || statusStr == _status;
      // Date range filter
      bool dateOk = true;
      if (_dateRange != null) {
        try {
          final d = DateTime.parse((m['date'] ?? '').toString());
          final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
          final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
          dateOk = (d.isAtSameMomentAs(start) || d.isAfter(start)) && (d.isAtSameMomentAs(end) || d.isBefore(end));
        } catch (_) {
          dateOk = false;
        }
      }
      return textOk && statusOk && dateOk;
    }).toList();
  }

  void _showCancelDialog(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('ยืนยันการยกเลิก'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คุณต้องการยกเลิกการจองนี้หรือไม่?'),
            SizedBox(height: 8),
            Text('สนาม: ${booking['courtName'] ?? 'ไม่ทราบ'}'),
            Text('วันที่: ${booking['date'] ?? 'ไม่ทราบ'}'),
            Text('เวลา: ${(booking['timeSlot'] ?? '').toString().replaceAll('-', ' - ').isNotEmpty ? (booking['timeSlot'] ?? '').toString().replaceAll('-', ' - ') : 'ไม่ทราบเวลา'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => _cancelBooking(booking['id']),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('ยืนยันการยกเลิก', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(String bookingId) async {
    Navigator.pop(context); // ปิด dialog

    // แสดง loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await BookingService.cancelBooking(bookingId);
      
      // ปิด loading dialog
      Navigator.pop(context);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        _loadBookings(); // รีเฟรชรายการ
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // ปิด loading dialog
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ฟังก์ชันสำหรับจัดรูปแบบการแสดงช่วงเวลา
  String _formatTimeSlots(Map<String, dynamic> booking) {
    try {
      // ตรวจสอบว่ามี timeSlots (array) หรือ timeSlot (string)
      if (booking['timeSlots'] != null && booking['timeSlots'] is List) {
        List<String> timeSlots = List<String>.from(booking['timeSlots']);
        if (timeSlots.isEmpty) return 'ไม่ทราบเวลา';
        
        // จัดเรียงและแสดงช่วงเวลา
        timeSlots.sort();
        return timeSlots.join(', ');
      } else if (booking['timeSlot'] != null && booking['timeSlot'].toString().isNotEmpty) {
        // แปลงจาก comma-separated string
        String timeSlotString = booking['timeSlot'].toString();
        if (timeSlotString.contains(',')) {
          List<String> timeSlots = timeSlotString.split(',').map((e) => e.trim()).toList();
          timeSlots.sort();
          return timeSlots.join(', ');
        } else {
          return timeSlotString.replaceAll('-', ' - ');
        }
      }
      
      return 'ไม่ทราบเวลา';
    } catch (e) {
      return 'ไม่ทราบเวลา';
    }
  }
}
