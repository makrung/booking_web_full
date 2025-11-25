import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'services/booking_service.dart';
import 'services/content_service.dart';
import 'services/auth_service.dart';
import 'models/app_constants.dart';
import 'NewAdvancedBookingPage.dart';

class SchedulePage extends StatefulWidget {
  @override
  _SchedulePageState createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Color(0xFFF0F8FF),
        body: Column(
          children: [
            // Custom Header with Back Button
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 20),
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
              child: Column(
                children: [
                  // Header with back button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
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
                                'ตารางการจองสนามกีฬา',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 48), // เพื่อให้ Title อยู่กลาง
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.teal,
                labelColor: Colors.teal[800],
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'ตารางรายวัน'),
                  Tab(text: 'ตารางรายเดือน'),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  DailyScheduleTable(),
                  MonthlyScheduleCalendar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================== ตารางรายวัน ======================
class DailyScheduleTable extends StatefulWidget {
  @override
  _DailyScheduleTableState createState() => _DailyScheduleTableState();
}

class _DailyScheduleTableState extends State<DailyScheduleTable> {
  DateTime selectedDate = DateTime.now();
  List<dynamic> bookings = [];
  bool isLoading = true;
  String? error;

  // Courts pulled from Firestore via API
  Map<String, dynamic> courts = {};
  String? _dailyLegendText;

  Widget _buildImprovedTable() {
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Headers Row
          Container(
            height: 50,
            width: double.infinity,
            child: Row(
              children: [
                // Court name column header
                Container(
                  width: 140,
                  height: 50,
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal[700],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    'สนามกีฬา',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Time slot headers
                Flexible(
                  child: Container(
                    height: 50,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _buildTimeHeaders(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Court rows
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: _buildCourtRows(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTimeHeaders() {
    List<Widget> headers = [];
    for (int hour = 9; hour <= 23; hour++) {
      headers.add(
        Container(
          width: 80,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.teal[600],
            border: Border(
              right: BorderSide(color: Colors.white, width: 1),
            ),
          ),
          child: Text(
            '${hour.toString().padLeft(2, '0')}:00',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
    return headers;
  }

  List<Widget> _buildCourtRows() {
    List<Widget> rows = [];
    
    // Build from courts map
    final entries = courts.entries.toList();
    // sort by type/category/number
    entries.sort((a, b) {
      int c = (a.value['type'] ?? '').toString().compareTo((b.value['type'] ?? '').toString());
      if (c != 0) return c;
      c = (a.value['category'] ?? '').toString().compareTo((b.value['category'] ?? '').toString());
      if (c != 0) return c;
      return ((a.value['number'] ?? 0) as int).compareTo((b.value['number'] ?? 0) as int);
    });

    int index = 0;
    for (final entry in entries) {
      final courtId = entry.key;
      final Map<String, dynamic> courtData = Map<String, dynamic>.from(entry.value);
      // compute openTimes from playStartTime/playEndTime
      courtData['openTimes'] = BookingService.buildTimeSlotsFromCourt(courtData);
      final isEven = index % 2 == 0;
      final courtName = (courtData['name'] as String?) ?? 'ไม่ระบุชื่อสนาม';
      final isCourtAvailable = (courtData['isAvailable'] ?? true) == true;
      
      rows.add(
        Container(
          height: 60,
          width: double.infinity,
          child: Row(
            children: [
              // Court name
              Container(
                width: 140,
                height: 60,
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isEven ? Colors.grey[50] : Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                    right: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isCourtAvailable ? courtName : '$courtName (ปิด)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isCourtAvailable ? Colors.grey[800] : Colors.red[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      isCourtAvailable ? _getCourtTimeInfo(courtData) : 'ปิดให้บริการชั่วคราว',
                      style: TextStyle(
                        fontSize: 10,
                        color: isCourtAvailable ? Colors.grey[600] : Colors.red[400],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Time slots
              Flexible(
                child: Container(
                  height: 60,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _buildTimeSlots(courtData, isEven, courtId, forceClosed: !isCourtAvailable),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      index++;
    }
    
    return rows;
  }

  List<Widget> _buildTimeSlots(Map<String, dynamic> courtData, bool isEven, String courtId, {bool forceClosed = false}) {
    List<Widget> slots = [];
    // Determine open-booking hour for this court
    int _getOpenBookingHour(Map<String, dynamic> court) {
      final explicit = court['openBookingTime']?.toString();
      if (explicit != null && explicit.contains(':')) {
        return int.tryParse(explicit.split(':').first) ?? 9;
      }
      final name = (court['name'] ?? '').toString().toLowerCase();
      if (name.contains('เทนนิส') || name.contains('แบด') || name.contains('bad') || name.contains('tennis')) {
        return 12;
      }
      return 9;
    }

    bool _isPastSlot(DateTime day, String slot) {
      final now = DateTime.now();
      final dayDate = DateTime(day.year, day.month, day.day);
      final todayDate = DateTime(now.year, now.month, now.day);
      if (dayDate.isBefore(todayDate)) return true;
      if (!dayDate.isAtSameMomentAs(todayDate)) return false;
      // same day: compare slot end time with now
      final parts = slot.split('-').last.split(':');
      final endH = int.tryParse(parts[0]) ?? 0;
      final endM = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      final nowMinutes = now.hour * 60 + now.minute;
      final endMinutes = endH * 60 + endM;
      return endMinutes <= nowMinutes;
    }

    final openBookingHour = _getOpenBookingHour(courtData);
    
    for (int hour = 9; hour <= 23; hour++) {
      final timeSlot = '${hour.toString().padLeft(2, '0')}:00-${(hour + 1).toString().padLeft(2, '0')}:00';
      
      // Check if this time slot is in the court's open times
      final openTimes = (courtData['openTimes'] as List<dynamic>?)?.cast<String>() ?? <String>[];
      final isPlayingTime = openTimes.any((slot) => slot.startsWith('${hour.toString().padLeft(2, '0')}:00'));
      
      // Check if there's a booking for this time slot
      final booking = _getBookingForCourtAndTime(courtId, timeSlot);
      final hasBooking = booking != null;
      final isPast = hasBooking && _isPastSlot(selectedDate, timeSlot);
      final isOpenBookingSlot = hour == openBookingHour;
      
      Color backgroundColor;
      Color textColor;
      IconData icon;
      
      if (forceClosed || !isPlayingTime) {
        // ปิดให้บริการ = สีเทาอ่อน
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[500]!;
        icon = Icons.schedule_rounded;
      } else if (hasBooking) {
        // ตรวจสอบสถานะและประเภทการจอง (ปกติ/กิจกรรม)
        final status = booking['status']?.toString() ?? 'available';
        final String bookingType = booking['bookingType']?.toString() ?? '';
        final String activityName = (booking['activityName'] ?? booking['activity'] ?? '').toString();
        final bool isActivity = bookingType == 'activity' || activityName.trim().isNotEmpty;

        if (isPast || status == 'completed') {
          // เสร็จสิ้น = สีน้ำเงินอ่อน
          backgroundColor = Colors.blue[100]!;
          textColor = Colors.blue[800]!;
          icon = Icons.check_circle;
        } else if (isActivity) {
          // กิจกรรม = สีเหลืองอ่อน
          backgroundColor = Colors.yellow[200]!;
          textColor = Colors.brown[800]!;
          icon = Icons.emoji_events;
        } else {
          // จองปกติ = สีแดงอ่อน
          backgroundColor = Colors.red[100]!;
          textColor = Colors.red[800]!;
          icon = Icons.event_busy;
        }
      } else {
        // ว่าง = สีเขียวอ่อน
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        icon = Icons.schedule;
      }
      
      slots.add(
        Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            color: isEven ? backgroundColor : backgroundColor.withValues(alpha: 0.8),
            border: Border(
              right: BorderSide(color: Colors.grey[300]!, width: 1),
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: (!forceClosed && isPlayingTime) ? () {
                  _showTimeSlotDetails(courtData, courtId, timeSlot, hasBooking);
                } : null,
                child: Container(
                  padding: EdgeInsets.all(4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: textColor,
                      ),
                      SizedBox(height: 2),
                      Text(
                        forceClosed
                            ? 'ปิด'
                            : (isPlayingTime
                                ? (hasBooking
                                    ? (isPast ? 'เสร็จสิ้น' : 'จอง')
                                    : 'ว่าง')
                                : 'ปิด'),
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isOpenBookingSlot)
                Positioned(
                  top: 2,
                  left: 2,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal[600],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.campaign, color: Colors.white, size: 10),
                        SizedBox(width: 3),
                        Text('เปิดจอง', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    
    return slots;
  }

  Widget _buildLegendSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.teal[700], size: 20),
              SizedBox(width: 8),
              Text(
                'คำอธิบายสีและสถานะ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Legend items
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              // ว่าง = สีเขียวอ่อน
              _buildLegendItem('ว่าง', Colors.green[100]!, Icons.schedule, Colors.green[800]!),
              _buildLegendItem('จองปกติ', Colors.red[100]!, Icons.event_busy, Colors.red[800]!),
              _buildLegendItem('กิจกรรม (ทั้งวัน/ช่วงเวลา)', Colors.yellow[200]!, Icons.emoji_events, Colors.brown[800]!),
              _buildLegendItem('เสร็จสิ้น', Colors.blue[100]!, Icons.check_circle, Colors.blue[800]!),
              _buildLegendItem('ปิดให้บริการ', Colors.grey[200]!, Icons.schedule_rounded, Colors.grey[500]!),
            ],
          ),
          // Admin-editable explanatory text (placed under statuses)
          if (((_dailyLegendText ?? '').trim()).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _dailyLegendText!.trim(),
                style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.35),
              ),
            ),
          ],
          
          SizedBox(height: 16),
          Divider(),
          SizedBox(height: 12),
    
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _loadCourts();
    _loadDailyLegend();
  }

  Future<void> _loadDailyLegend() async {
    try {
      final v = await ContentService.getContent('daily_legend_text');
      if (mounted) setState(() { _dailyLegendText = v; });
    } catch (_) {}
  }

  Future<void> _loadBookings() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // เรียกใช้ API เพื่อดึงข้อมูลการจองทั้งหมด
      final result = await BookingService.getAllBookings();
      if (result['success'] == true || result.containsKey('bookings')) {
        final String selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

        // กรองข้อมูลการจองในวันที่เลือก และไม่แสดงการจองที่ยกเลิก
        final filteredBookings = (result['bookings'] as List?)
                ?.where((booking) {
                  String? bookingDateStr = booking['date']?.toString();
                  if (bookingDateStr == null) return false;
                  if (bookingDateStr.contains('T')) {
                    bookingDateStr = bookingDateStr.split('T')[0];
                  }
                  // ไม่แสดงเฉพาะการจองที่ยกเลิก
                  final status = booking['status']?.toString();
                  final isValidStatus = status != BookingStatus.cancelled;
                  return bookingDateStr == selectedDateStr && isValidStatus;
                })
                .toList() ?? [];

        setState(() {
          bookings = filteredBookings;
          isLoading = false;
        });
      } else {
        throw Exception(result['error'] ?? 'ไม่สามารถโหลดข้อมูลการจองได้');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadCourts() async {
    try {
      final res = await BookingService.getCourts();
      if (res.containsKey('courts')) {
        setState(() {
          courts = Map<String, dynamic>.from(res['courts'] as Map);
        });
      }
    } catch (e) {
      // ignore errors
    }
  }

  Map<String, dynamic>? _getBookingForCourtAndTime(String? courtId, String timeSlot) {
    if (bookings.isEmpty || courtId == null) return null;
    
    try {
      final booking = bookings.firstWhere(
        (booking) {
          // ตรวจสอบว่าการจองนี้ตรงกับสนามและช่วงเวลาที่ต้องการ
          final isMatchingCourt = booking['courtId']?.toString() == courtId;
          final timeSlotsList = booking['timeSlots'] as List?;
          final isMatchingTime = timeSlotsList?.contains(timeSlot) == true;
          
          // ไม่แสดงการจองที่ยกเลิกหรือถูกลดคะแนน
          final status = booking['status']?.toString();
          final isValidStatus = status != BookingStatus.cancelled && 
                               status != BookingStatus.penalized;
          
          return isMatchingCourt && isMatchingTime && isValidStatus;
        },
      );
      return booking as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 16),
            Text('กำลังโหลดข้อมูล...', style: TextStyle(color: Colors.teal[700])),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('เกิดข้อผิดพลาด: $error'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBookings,
              child: Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Date Picker Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.teal[600]!, Colors.teal[400]!],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'เลือกวันที่: ',
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2025, 1, 1),
                      lastDate: DateTime(2025, 12, 31),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.teal,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null && picked != selectedDate) {
                      setState(() {
                        selectedDate = picked;
                      });
                      _loadBookings();
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.teal[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.edit_calendar, color: Colors.teal[700], size: 18),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: _loadBookings,
                  icon: Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'รีเฟรชข้อมูล',
                ),
              ),
            ],
          ),
        ),
        
        // Main Content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Court Schedule Table
                Container(
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Table Header
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.sports, color: Colors.teal[700], size: 20),
                            SizedBox(width: 8),
                            Text(
                              'ตารางการจองสนาม ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Table Content
                      Container(
                        padding: EdgeInsets.all(16),
                        child: _buildImprovedTable(),
                      ),
                    ],
                  ),
                ),
                
                // Legends and Info
                _buildLegendSection(),
                
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon, Color textColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getCourtTimeInfo(dynamic court) {
    // Handle court data from different sources
    if (court is Map) {
      final playStart = court['playStartTime']?.toString();
      final playEnd = court['playEndTime']?.toString();
      // Derive open booking time by rule-of-thumb per sport type if available
      final name = (court['name'] ?? '').toString().toLowerCase();
      String openBooking = court['openBookingTime']?.toString() ?? '';
      if (openBooking.isEmpty) {
        // Heuristic: racket sports open 12:00, others 09:00
        if (name.contains('เทนนิส') || name.contains('แบด') || name.contains('bad') || name.contains('tennis')) {
          openBooking = '12:00';
        } else {
          openBooking = '09:00';
        }
      }
      if (playStart != null && playEnd != null) {
        return 'เปิดให้จอง $openBooking | เล่นได้ $playStart-$playEnd';
      }
      final openingTime = court['openingTime'] ?? openBooking;
      final playingTime = court['playingTime'] ?? (playStart != null && playEnd != null ? '$playStart-$playEnd' : '12:00-22:00');
      return 'เปิดให้จอง $openingTime | เล่นได้ $playingTime';
    }
    
    // Default court info
    return 'เปิดให้จอง 09:00 | เล่นได้ 12:00-22:00';
  }

  void _showTimeSlotDetails(Map<String, dynamic> court, String courtId, String timeSlot, bool hasBooking) {
    final String courtName = (court['name'] ?? 'ไม่ระบุ').toString();
    final booking = _getBookingForCourtAndTime(courtId, timeSlot);
    // Treat as activity if bookingType == 'activity' OR an activity name exists
    final bool isActivity = booking != null && (
      (booking['bookingType']?.toString() == 'activity') ||
      ((((booking['activityName'] ?? booking['activity'])?.toString()) ?? '').trim().isNotEmpty)
    );
    final String activityLabel = (((booking?['activityName'] ?? booking?['activity'])?.toString()) ?? '').trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.teal[700]),
            SizedBox(width: 8),
            Text(
              'รายละเอียดช่วงเวลา',
              style: TextStyle(color: Colors.teal[700]),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('สนาม:', courtName),
            _buildDetailRow('เวลา:', timeSlot),
            _buildDetailRow('สถานะ:', hasBooking ? (isActivity ? 'กิจกรรม' : 'จองปกติ') : 'ว่าง'),
            if (hasBooking) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActivity ? Colors.yellow[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (isActivity ? Colors.brown[200] : Colors.orange[200])!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(isActivity ? Icons.emoji_events : Icons.event_busy, size: 16, color: isActivity ? Colors.brown[700] : Colors.orange[700]),
                        SizedBox(width: 6),
                        Text(
                          isActivity ? 'ช่วงเวลานี้ถูกใช้สำหรับกิจกรรม' : 'ช่วงเวลานี้มีการจองปกติ',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        ),
                      ],
                    ),
                    if (isActivity && activityLabel.isNotEmpty) ...[
                      SizedBox(height: 6),
                      Text('กิจกรรม: $activityLabel'),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ปิด'),
          ),
          if (!hasBooking)
            ElevatedButton(
              onPressed: () async {
                // Domain policy guard: block non-university users when disabled
                try {
                  final me = await AuthService.getCurrentUser();
                  final meta = await ContentService.getContentWithMeta('allow_non_university_booking');
                  final allowStr = (meta['value'] ?? '1').toString().toLowerCase();
                  final allow = allowStr == '1' || allowStr == 'true';
                  final isAdmin = (me?['role'] ?? '') == 'admin';
                  final email = (me?['email'] ?? '').toString();
                  bool isUni = false;
                  if (email.isNotEmpty) {
                    final e = email.toLowerCase().trim();
                    isUni = e.endsWith('@silpakorn.edu') || e.endsWith('@su.ac.th');
                  }
                  final blocked = !allow && !isAdmin && !isUni;
                  if (blocked) {
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
                          'ขณะนี้ระบบจำกัดการจองเฉพาะผู้ใช้อีเมลของมหาวิทยาลัยเท่านั้น\nผู้ใช้ที่ไม่ใช่อีเมลของทางมหาวิทยาลัยไม่สามารถทำการจองได้ชั่วคราว',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
                        ],
                      ),
                    );
                    return;
                  }
                } catch (_) {}
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NewAdvancedBookingPage(
                      initialBookingType: 'regular',
                      initialCourtId: courtId,
                      initialCourtName: courtName,
                      initialDate: selectedDate,
                      initialTimeSlots: [timeSlot],
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
              ),
              child: Text('จองเลย', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}

String formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

// ====================== ตารางรายเดือน ======================
class MonthlyScheduleCalendar extends StatefulWidget {
  @override
  _MonthlyScheduleCalendarState createState() => _MonthlyScheduleCalendarState();
}

class _MonthlyScheduleCalendarState extends State<MonthlyScheduleCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<dynamic> allBookings = [];
  bool isLoading = true;
  String? error;
  String? _monthlyLegendText;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _loadMonthlyLegend();
  }

  Future<void> _loadMonthlyLegend() async {
    try {
      final v = await ContentService.getContent('monthly_legend_text');
      if (mounted) setState(() { _monthlyLegendText = v; });
    } catch (_) {}
  }

  Future<void> _loadBookings() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await BookingService.getAllBookings(); // เปลี่ยนเป็น getAllBookings
      if (result['success']) {
        // กรองข้อมูลการจองและไม่แสดงการจองที่ยกเลิก
        final filteredBookings = (result['bookings'] as List).where((booking) {
          final status = booking['status'];
          return status != BookingStatus.cancelled;
        }).toList();
        
        setState(() {
          allBookings = filteredBookings;
          isLoading = false;
        });
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final dayStr = DateFormat('yyyy-MM-dd').format(day);
    
  return allBookings.where((booking) {
      String? bookingDateStr = booking['date']?.toString();
      if (bookingDateStr == null) return false;
      
      if (bookingDateStr.contains('T')) {
        bookingDateStr = bookingDateStr.split('T')[0];
      }
      
      // ไม่แสดงการจองที่ยกเลิก
      final status = booking['status']?.toString();
      final isValidStatus = status != BookingStatus.cancelled;
      
      return bookingDateStr == dayStr && isValidStatus;
    }).map((booking) {
      // Mark past days as completed for display
      final now = DateTime.now();
      final dayDate = DateTime(day.year, day.month, day.day);
      final todayDate = DateTime(now.year, now.month, now.day);
      final originalStatus = (booking['status'] ?? '').toString();
      final displayStatus = dayDate.isBefore(todayDate)
          ? BookingStatus.completed
          : originalStatus;
      return {
        'id': booking['id'] ?? '',
        'field': booking['courtName'] ?? '',
        'activityName': booking['activityName'] ?? booking['activity'] ?? '',
        'bookingType': booking['bookingType'] ?? '',
        // Privacy: don't include user identity in schedule views
        'timeSlots': booking['timeSlots'] ?? [],
        'status': displayStatus,
        'note': booking['note'] ?? '',
        'createdAt': booking['createdAt'] ?? '',
      };
    }).toList().cast<Map<String, dynamic>>();
  }

  String _getStatusText(String status) {
    switch (status) {
      case BookingStatus.pending:
        return 'รอยืนยัน';
      case BookingStatus.confirmed:
        return 'ยืนยันแล้ว';
      case BookingStatus.checkedIn:
        return 'กำลังใช้';
      case BookingStatus.completed:
        return 'เสร็จสิ้น';
      case BookingStatus.cancelled:
        return 'ยกเลิก';
      case BookingStatus.expired:
        return 'หมดเวลา';
      case BookingStatus.noShow:
        return 'ไม่มา';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange.shade100;
      case BookingStatus.confirmed:
        return Colors.blue.shade100;
      case BookingStatus.checkedIn:
        return Colors.purple.shade100;
      case BookingStatus.completed:
        return Colors.green.shade100;
      case BookingStatus.cancelled:
        return Colors.grey.shade100;
      case BookingStatus.expired:
      case BookingStatus.noShow:
        return Colors.red.shade100;
      default:
        return Colors.teal.shade100;
    }
  }

  void _showEventPopup(DateTime day, List<Map<String, dynamic>> bookings) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'รายละเอียดการจอง\nวันที่ ${DateFormat('dd/MM/yyyy').format(day)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.teal.shade800,
                  ),
                ),
                SizedBox(height: 16),
                ...bookings.map((booking) => Container(
                  margin: EdgeInsets.symmetric(vertical: 6),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking['status']),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(builder: (context){
                        final isActivity = (booking['bookingType']?.toString() == 'activity') || ((booking['activityName'] ?? '').toString().trim().isNotEmpty);
                        final topTitle = isActivity ? (booking['activityName']?.toString() ?? '').trim() : (booking['field']?.toString() ?? '').trim();
                        final subTitle = isActivity ? 'สนาม: ${(booking['field']?.toString() ?? '').trim()}' : 'มีผู้จองแล้ว';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topTitle,
                              style: TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              subTitle,
                              style: TextStyle(color: Colors.grey[800]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      }),
                      // Privacy: don't show user identity in schedule
                      // Just show that the slot is booked
                      Text('สถานะ: ${_getStatusText(booking['status'])}'),
                      Builder(builder: (context) {
                        final isActivity = (booking['bookingType']?.toString() == 'activity') || ((booking['activityName'] ?? '').toString().trim().isNotEmpty);
                        if (isActivity) {
                          return const Text('เวลา: ตลอดทั้งวัน');
                        }
                        final ts = (booking['timeSlots'] is List)
                            ? (booking['timeSlots'] as List)
                            : (booking['timeSlots'] != null ? [booking['timeSlots']] : const []);
                        return Text('เวลา: ${ts.join(', ')}');
                      }),
                      // note if available
                      if (booking['note'].isNotEmpty)
                        Text('หมายเหตุ: ${booking['note']}'),
                    ],
                  ),
                )),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ปิด'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('เกิดข้อผิดพลาด: $error'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBookings,
              child: Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Header with refresh button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ปฏิทินการจองสนาม',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[700],
                        ),
                      ),
                      IconButton(
                        onPressed: _loadBookings,
                        icon: Icon(Icons.refresh, color: Colors.teal[700]),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // Calendar
                  TableCalendar(
                    firstDay: DateTime.utc(2025, 1, 1),
                    lastDay: DateTime.utc(2025, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });

                      final bookings = _getEventsForDay(selectedDay);
                      if (bookings.isNotEmpty) {
                        _showEventPopup(selectedDay, bookings);
                      }
                    },
                    eventLoader: (day) => _getEventsForDay(day),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 3,
                      markerSize: 6.0,
                    ),
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                      leftChevronIcon: Icon(Icons.chevron_left, color: Colors.teal[700]),
                      rightChevronIcon: Icon(Icons.chevron_right, color: Colors.teal[700]),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Open-booking info (admin editable with fallback)
                  Row(
                    children: [
                      Icon(Icons.campaign, size: 14, color: Colors.teal[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (_monthlyLegendText ?? '').trim().isNotEmpty
                              ? _monthlyLegendText!.trim()
                              : 'เวลาที่เปิดให้จอง (ทั่วไป): 09:00 | เทนนิส/แบดมินตัน: 12:00',
                          style: TextStyle(color: Colors.teal[800], fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Selected day info
                  if (_selectedDay != null)
                    Column(
                      children: [
                        SizedBox(height: 16),
                        Center(
                          child: Text(
                            'รายการจองวันที่ ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.teal[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 8),
                        
                        Builder(
                          builder: (context) {
                            final dayBookings = _getEventsForDay(_selectedDay!);
                            if (dayBookings.isEmpty) {
                              return Center(
                                child: Text(
                                  'ไม่มีการจองในวันดังกล่าว',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            
                            return ListView(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              children: dayBookings.map((booking) => Container(
                                margin: EdgeInsets.symmetric(vertical: 4),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(booking['status']),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.teal.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Builder(builder: (context){
                                            final isActivity = (booking['bookingType']?.toString() == 'activity') || ((booking['activityName'] ?? '').toString().trim().isNotEmpty);
                                            final topTitle = isActivity ? (booking['activityName']?.toString() ?? '') : (booking['field']?.toString() ?? '');
                                            final subTitle = isActivity ? (booking['field']?.toString() ?? '') : 'มีผู้จองเเล้ว';
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  topTitle,
                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  subTitle,
                                                  style: TextStyle(color: Colors.grey[800]),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            );
                                          }),
                                          SizedBox(height: 2),
                                          Builder(builder: (context) {
                                            final isActivity = (booking['bookingType']?.toString() == 'activity') || ((booking['activityName'] ?? '').toString().trim().isNotEmpty);
                                            if (isActivity) return const Text('เวลา: ตลอดทั้งวัน');
                                            final ts = (booking['timeSlots'] is List)
                                                ? (booking['timeSlots'] as List)
                                                : (booking['timeSlots'] != null ? [booking['timeSlots']] : const []);
                                            return Text('เวลา: ${ts.join(', ')}');
                                          }),
                                          Text('สถานะ: ${_getStatusText(booking['status'])}')
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            );
                          },
                        ),
                      ],
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
}

