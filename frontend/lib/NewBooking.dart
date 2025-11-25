import 'package:flutter/material.dart';
import 'NewBookingHistory.dart';
import 'services/booking_service.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'package:intl/intl.dart';
import 'BookingSuccessPage.dart';

class BookingPage extends StatefulWidget {
  final String? initialCourtId;
  final String? initialCourtName;
  final DateTime? initialDate;
  final List<String>? initialTimeSlots;

  const BookingPage({Key? key, this.initialCourtId, this.initialCourtName, this.initialDate, this.initialTimeSlots}) : super(key: key);

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? selectedCourtId;
  String? selectedCourtName;
  DateTime? selectedDate;
  List<String> selectedTimeSlots = []; // เปลี่ยนเป็น List เพื่อรองรับหลายช่วงเวลา
  String? selectedActivity;
  String noteController = '';
  int userPoints = 100; // คะแนนผู้ใช้

  Map<String, dynamic> courts = {};
  List<String> bookedSlots = [];
  bool isLoadingCourts = true;
  bool isLoadingSchedule = false;
  bool isLoadingPoints = true;
  Map<String, dynamic>? _codeStatus;
  bool _loadingCodeStatus = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _animationController.forward();
    // Prefill from initial values if provided
    if (widget.initialCourtId != null) {
      selectedCourtId = widget.initialCourtId;
      selectedCourtName = widget.initialCourtName;
    }
    if (widget.initialDate != null) {
      selectedDate = widget.initialDate;
    }
    if (widget.initialTimeSlots != null && widget.initialTimeSlots!.isNotEmpty) {
      selectedTimeSlots = List<String>.from(widget.initialTimeSlots!);
    }

    _loadCourts();
    _loadUserPoints();
    _checkTestMode(); // เช็คโหมดทดสอบตอน init
    _loadCodeStatus();
    // Listen to test-mode changes so UI updates immediately when admin toggles
    SettingsService.testModeNotifier.addListener(_onTestModeChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    SettingsService.testModeNotifier.removeListener(_onTestModeChanged);
    super.dispose();
  }

  void _onTestModeChanged() async {
    final testMode = SettingsService.testModeNotifier.value;
    if (mounted) setState(() { _isTestModeEnabled = testMode; });
  }

  Future<void> _loadCodeStatus() async {
    try {
      final status = await BookingService.getCodeStatus();
      setState(() {
        _codeStatus = status;
        _loadingCodeStatus = false;
      });
    } catch (e) {
      setState(() { _loadingCodeStatus = false; });
    }
  }

  Future<void> _loadCourts() async {
    setState(() {
      isLoadingCourts = true;
    });

    try {
      print('📍 Loading courts...');
      final result = await BookingService.getCourts();
      print('📍 getCourts result keys: ${result.keys}');
      
      // API /courts ส่งกลับมาแค่ { "courts": {...} } ไม่มี success
      if (result.containsKey('courts')) {
        setState(() {
          courts = result['courts'] as Map<String, dynamic>;
          isLoadingCourts = false;
        });
        print('📍 Loaded ${courts.length} courts successfully');
        // If we have initial preselection, load schedule and keep time selection
        if (selectedCourtId != null && selectedDate != null) {
          _loadCourtSchedule();
        }
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('❌ Error loading courts: $e');
      setState(() {
        isLoadingCourts = false;
      });
      _showErrorDialog('เกิดข้อผิดพลาดในการโหลดข้อมูลสนาม: $e');
    }
  }

  Future<void> _loadCourtSchedule() async {
    if (selectedCourtId == null || selectedDate == null) return;

    setState(() {
      isLoadingSchedule = true;
      bookedSlots = [];
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
      final result = await BookingService.getCourtSchedule(selectedCourtId!, dateStr);
      
      if (result['success']) {
        setState(() {
          bookedSlots = List<String>.from(result['bookedSlots']);
          isLoadingSchedule = false;
        });
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      setState(() {
        isLoadingSchedule = false;
      });
      _showErrorDialog('เกิดข้อผิดพลาดในการโหลดตารางเวลา: $e');
    }
  }

  // เช็คโหมดทดสอบ (เรียกแค่ครั้งเดียวตอน init)
  bool _isTestModeEnabled = false;

  Future<void> _checkTestMode() async {
    final testMode = await SettingsService.isTestModeEnabled();
    setState(() {
      _isTestModeEnabled = testMode;
    });
  }

  bool _isTimeSlotPastWithTestMode(String timeSlot) {
    // ถ้าเปิดโหมดทดสอบ อนุญาตทุกเวลา
    final immediateTestMode = SettingsService.testModeNotifier.value;
    if (immediateTestMode || _isTestModeEnabled) {
      return false;
    }
    
    // Logic เดิมสำหรับโหมดปกติ
    if (selectedDate == null) return false;
    
    final now = DateTime.now();
    final selectedDateOnly = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
    final today = DateTime(now.year, now.month, now.day);
    
    // ถ้าเป็นวันในอนาคต ไม่ต้องตรวจสอบเวลา
    if (selectedDateOnly.isAfter(today)) {
      return false;
    }
    
    // ถ้าเป็นวันในอดีต ห้ามจองทั้งหมด
    if (selectedDateOnly.isBefore(today)) {
      return true;
    }
    
    // ถ้าเป็นวันปัจจุบัน ตรวจสอบเวลา
    final timeEnd = timeSlot.split('-')[1];
    final timeParts = timeEnd.split(':');
    final endHour = int.parse(timeParts[0]);
    final endMinute = int.parse(timeParts[1]);
    
    final currentHour = now.hour;
    final currentMinute = now.minute;
    
    // ถ้าเวลาปัจจุบันเลยเวลาสิ้นสุดของช่วงการจองแล้ว
    if (currentHour > endHour || (currentHour == endHour && currentMinute >= endMinute)) {
      return true;
    }
    
    return false;
  }

  // Helper to convert time slots to Map format
  List<Map<String, String>> _getTimeSlotsAsMap() {
    final timeSlots = selectedCourtId != null
        ? BookingService.buildTimeSlotsFromCourt(courts[selectedCourtId])
        : <String>[];
    return timeSlots.map((slot) => {
      'value': slot,
      'display': slot,
    }).toList();
  }

  // ฟังก์ชันสำหรับการเลือก/ยกเลิกช่วงเวลา
  void _toggleTimeSlot(String timeSlot) {
    final timeSlots = _getTimeSlotsAsMap();
    final selectedIndex = timeSlots.indexWhere((slot) => slot['value'] == timeSlot);
    
    if (selectedTimeSlots.contains(timeSlot)) {
      // ถ้าเลือกไว้แล้ว ให้ยกเลิก
      selectedTimeSlots.remove(timeSlot);
    } else {
      // ตรวจสอบว่าสามารถเลือกเวลานี้ได้หรือไม่
      if (selectedTimeSlots.isEmpty) {
        // ถ้าไม่มีเวลาที่เลือกไว้ ให้เลือกได้เลย
        selectedTimeSlots.add(timeSlot);
      } else {
        // ตรวจสอบว่าเวลาที่เลือกติดต่อกันหรือไม่
        final currentIndices = selectedTimeSlots.map((slot) =>
          timeSlots.indexWhere((s) => s['value'] == slot)).toList()..sort();
        
        final minIndex = currentIndices.first;
        final maxIndex = currentIndices.last;
        
        // ตรวจสอบว่าเวลาใหม่อยู่ติดกับช่วงเวลาที่เลือกไว้หรือไม่
        if (selectedIndex == minIndex - 1 || selectedIndex == maxIndex + 1) {
          selectedTimeSlots.add(timeSlot);
        } else {
          // แสดง dialog แจ้งเตือน
          _showTimeSlotWarning();
        }
      }
    }
  }

  void _showTimeSlotWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('ไม่สามารถจองได้'),
          ],
        ),
        content: Text(
          'คุณสามารถจองเฉพาะช่วงเวลาที่ติดต่อกันเท่านั้น\n'
          'หากต้องการจองช่วงเวลาที่ไม่ติดต่อกัน กรุณากรอกฟอร์มใหม่อีกครั้ง',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('เข้าใจแล้ว'),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันโหลดคะแนนผู้ใช้
  Future<void> _loadUserPoints() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        setState(() {
          userPoints = user['points'] ?? 100;
          isLoadingPoints = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingPoints = false;
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
              'จองสนามกีฬา',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BookingHistoryPage()),
              );
            },
          ),
        ],
      ),
      body: isLoadingCourts
          ? Center(child: CircularProgressIndicator())
          : SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Test mode banner (visible when enabled)
                        ValueListenableBuilder<bool>(
                          valueListenable: SettingsService.testModeNotifier,
                          builder: (context, isTestOn, _) {
                            if (!isTestOn) return SizedBox.shrink();
                            return Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                border: Border.all(color: Colors.red.shade200),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.science, color: Colors.red.shade700),
                                  SizedBox(width: 12),
                                  Expanded(child: Text('โหมดทดสอบ: เปิด — ผู้ใช้สามารถจองได้ทุกวัน/เวลา', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            );
                          },
                        ),
                        _buildUserPointsCard(),
                        SizedBox(height: 12),
                        _buildUserCodeCard(),
                        SizedBox(height: 20),
                        buildCourtSelector(),
                        SizedBox(height: 20),
                        buildDatePicker(),
                        SizedBox(height: 20),
                        buildTimeSlotSelector(),
                        SizedBox(height: 20),
                        buildParticipantCodesSection(),
                        SizedBox(height: 20),
                        buildActivitySelector(),
                        SizedBox(height: 20),
                        buildNoteField(),
                        SizedBox(height: 30),
                        buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildUserCodeCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.qr_code_2, color: Colors.teal[700], size: 28),
            SizedBox(width: 12),
            Expanded(
              child: _loadingCodeStatus
                  ? Row(children: [SizedBox(height:16,width:16,child: CircularProgressIndicator(strokeWidth:2)), SizedBox(width:8), Text('กำลังโหลดรหัสของคุณ...')])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('รหัสของคุณ', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        SelectableText(_codeStatus?['userCode'] ?? '-', style: TextStyle(fontSize: 16, letterSpacing: 1.5)),
                        SizedBox(height: 8),
                        if (_codeStatus != null) ...[
                          Row(
                            children: [
                              Icon(_codeStatus!['usedToday'] == true ? Icons.lock_clock : Icons.lock_open, size: 16, color: _codeStatus!['usedToday'] == true ? Colors.red : Colors.green),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _codeStatus!['usedToday'] == true
                                      ? 'วันนี้ใช้รหัสไปแล้ว • ใช้ได้อีกครั้งใน ${( (_codeStatus!['secondsUntilReset'] ?? 0) ~/ 3600)} ชม.'
                                      : 'พร้อมใช้งานสำหรับการจองวันนี้',
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
            SizedBox(width: 8),
            if (!_loadingCodeStatus)
              IconButton(
                tooltip: 'คัดลอกรหัส',
                onPressed: () {
                  final code = _codeStatus?['userCode']?.toString() ?? '';
                  if (code.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('คัดลอกรหัสแล้ว: $code')),
                    );
                  }
                },
                icon: Icon(Icons.copy),
              )
          ],
        ),
      ),
    );
  }

  // เก็บรหัสผู้เข้าร่วม (ไม่รวมผู้จอง)
  final List<TextEditingController> _participantControllers = [];
  int _requiredParticipants = 0;

  Widget buildParticipantCodesSection() {
    // คำนวณจำนวนผู้เข้าร่วมที่ต้องกรอกจากข้อมูลสนามใน Firestore
    int requiredPlayers = 2;
    if (selectedCourtId != null) {
      final court = courts[selectedCourtId];
      final category = court['category']?.toString() ?? '';
      final defaultRequiredByCategory = {
        'badminton': 2,
        'tennis': 2,
        'futsal': 10,
        'football': 22,
        'basketball': 10,
        'volleyball': 10,
        'multipurpose': 10,
      };
      requiredPlayers = (court['requiredPlayers'] ?? defaultRequiredByCategory[category] ?? 2) as int;
    }
    _requiredParticipants = (requiredPlayers - 1).clamp(0, 100);

    // สร้าง controller ให้ครบตามจำนวนที่ต้องกรอก
    while (_participantControllers.length < _requiredParticipants) {
      _participantControllers.add(TextEditingController());
    }
    while (_participantControllers.length > _requiredParticipants) {
      _participantControllers.removeLast();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('👥 รหัสผู้เข้าร่วม', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('ผู้จองไม่ต้องกรอกรหัสของตัวเอง ระบบจะนับรวมให้อัตโนมัติ', style: TextStyle(color: Colors.black54, fontSize: 12)),
            SizedBox(height: 12),
            if (_requiredParticipants == 0)
              Text('สนามนี้ไม่จำเป็นต้องกรอกรหัสผู้เข้าร่วมเพิ่มเติม', style: TextStyle(color: Colors.black54))
            else
              Column(
                children: List.generate(_requiredParticipants, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextFormField(
                      controller: _participantControllers[i],
                      decoration: InputDecoration(
                        labelText: 'รหัสผู้เข้าร่วม #${i + 1}',
                        hintText: 'เช่น ABCD1234',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) {
                          return 'กรุณากรอกรหัสให้ครบ';
                        }
                        return null;
                      },
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildCourtSelector() {
    final fieldOptions = [
      {'name': 'สนามฟุตบอล', 'icon': '⚽', 'color': Colors.green},
      {'name': 'สนามฟุตซอล', 'icon': '🥅', 'color': Colors.blue},
      {'name': 'สนามบาสเกตบอล', 'icon': '🏀', 'color': Colors.orange},
      {'name': 'สนามวอลเลย์บอล', 'icon': '🏐', 'color': Colors.red},
      {'name': 'สนามเทนนิส', 'icon': '🎾', 'color': Colors.yellow},
      {'name': 'สนามแบดมินตัน', 'icon': '🏸', 'color': Colors.purple},
    ];

    // Filter only available courts
    final availableCourtKeys = courts.entries
        .where((e) => (e.value['isAvailable'] ?? true) == true)
        .map((e) => e.key)
        .toList();

    // If the currently selected court is unavailable, clear selection
    if (selectedCourtId != null) {
      final selected = courts[selectedCourtId];
      final selectedAvailable = selected != null && (selected['isAvailable'] ?? true) == true;
      if (!selectedAvailable) {
        selectedCourtId = null;
        selectedCourtName = null;
        selectedTimeSlots.clear();
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏟️ เลือกสนาม',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            if (availableCourtKeys.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text('ขณะนี้ยังไม่มีสนามที่เปิดให้จอง', style: TextStyle(color: Colors.orange[800])),
              ),
              const SizedBox(height: 8),
            ]
            else Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(availableCourtKeys.length, (index) {
                final courtId = availableCourtKeys.elementAt(index);
                final court = courts[courtId];
                final isSelected = selectedCourtId == courtId;
                
                // หาไอคอนที่ตรงกัน
                final matchedField = fieldOptions.firstWhere(
                  (field) {
                    final courtName = court['name']?.toString() ?? '';
                    final fieldName = (field['name'] as String? ?? '').replaceAll('สนาม', '');
                    return courtName.contains(fieldName);
                  },
                  orElse: () => fieldOptions[0],
                );
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCourtId = courtId;
                      selectedCourtName = court['name'];
                      selectedTimeSlots.clear(); // รีเซ็ตเวลาเมื่อเปลี่ยนสนาม
                    });
                    if (selectedDate != null) {
                      _loadCourtSchedule();
                    }
                  },
                  child: Container(
                    width: 160,
                    height: 100,
                    decoration: BoxDecoration(
                      color: isSelected ? (matchedField['color'] as Color) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? (matchedField['color'] as Color) : Colors.grey[300]!,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: (matchedField['color'] as Color).withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ] : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          matchedField['icon'] as String,
                          style: TextStyle(fontSize: 32),
                        ),
                        SizedBox(height: 4),
                        Text(
                          court['name'] ?? 'ไม่ทราบชื่อ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDatePicker() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📅 เลือกวันที่',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                // Determine range: never allow dates before today. Test mode only widens maxDate.
                final storedTestMode = await SettingsService.isTestModeEnabled();
                final isTestMode = SettingsService.testModeNotifier.value || storedTestMode;

                final now = DateTime.now();
                final todayOnly = DateTime(now.year, now.month, now.day);
                DateTime firstDate = todayOnly; // always at least today
                DateTime lastDate;
                if (isTestMode) {
                  // Test mode: allow far-future dates but still disallow past
                  lastDate = DateTime(2030, 12, 31);
                } else {
                  // Normal mode: limit to 30 days ahead
                  lastDate = todayOnly.add(Duration(days: 30));
                }
                
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? todayOnly,
                  firstDate: firstDate,
                  lastDate: lastDate,
                );
                if (pickedDate != null) {
                  setState(() {
                    selectedDate = pickedDate;
                    selectedTimeSlots.clear(); // รีเซ็ตเวลาเมื่อเปลี่ยนวัน
                  });
                  if (selectedCourtId != null) {
                    _loadCourtSchedule();
                  }
                }
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selectedDate != null
                      ? DateFormat('d MMM yyyy').format(selectedDate!)
                      : 'เลือกวันที่',
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedDate != null ? Colors.black : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTimeSlotSelector() {
    final timeSlots = _getTimeSlotsAsMap();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⏰ เลือกเวลา',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            if (selectedCourtId == null || selectedDate == null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'กรุณาเลือกสนามและวันที่ก่อน',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              )
            else if (isLoadingSchedule)
              Center(child: CircularProgressIndicator())
            else
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: timeSlots.length,
                itemBuilder: (context, index) {
                  final slot = timeSlots[index];
                  final slotValue = slot['value']!;
                  final isBooked = bookedSlots.contains(slotValue);
                  final isSelected = selectedTimeSlots.contains(slotValue);
                  final isPastTime = _isTimeSlotPastWithTestMode(slotValue);
                  final isDisabled = isBooked || isPastTime;
                  
                  return GestureDetector(
                    onTap: isDisabled ? null : () {
                      setState(() {
                        _toggleTimeSlot(slotValue);
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isPastTime
                            ? Colors.grey[300]
                            : isBooked 
                                ? Colors.red[100] 
                                : isSelected 
                                    ? Colors.teal[100] 
                                    : Colors.grey[100],
                        border: Border.all(
                          color: isPastTime
                              ? Colors.grey
                              : isBooked 
                                  ? Colors.red 
                                  : isSelected 
                                      ? Colors.teal 
                                      : Colors.grey[300]!,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            slot['display']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isPastTime 
                                  ? Colors.grey[600]
                                  : isBooked 
                                      ? Colors.red[700] 
                                      : isSelected 
                                          ? Colors.teal[700] 
                                          : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (isPastTime)
                            Text(
                              'หมดเวลา',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else if (isBooked)
                            Text(
                              'จองแล้ว',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget buildActivitySelector() {
    final activities = BookingService.getActivityTypes();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏃 ประเภทกิจกรรม',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedActivity,
              hint: Text('เลือกประเภทกิจกรรม'),
              onChanged: (value) {
                setState(() {
                  selectedActivity = value;
                });
              },
              items: activities.map((activity) {
                return DropdownMenuItem(
                  value: activity,
                  child: Text(activity),
                );
              }).toList(),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNoteField() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📝 หมายเหตุ (ไม่บังคับ)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            TextFormField(
              maxLines: 3,
              onChanged: (value) {
                noteController = value;
              },
              decoration: InputDecoration(
                hintText: 'ระบุรายละเอียดเพิ่มเติม...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSubmitButton() {
    final isFormValid = selectedCourtId != null && 
                       selectedDate != null && 
                       selectedTimeSlots.isNotEmpty && 
                       selectedActivity != null;
    
  final usedToday = _codeStatus?['usedToday'] == true;
  final canSubmit = isFormValid && userPoints > 0 && !usedToday;
                       
    return Column(
      children: [
        if (userPoints == 0) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.block, color: Colors.red.shade700, size: 32),
                SizedBox(height: 8),
                Text(
                  'ไม่สามารถจองได้',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'คะแนนของคุณหมดแล้ว กรุณาติดต่อแอดมินเพื่อเพิ่มคะแนน',
                  style: TextStyle(
                    color: Colors.red.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        if (usedToday) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_clock, color: Colors.red.shade700),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'วันนี้คุณใช้รหัสสำหรับการจองไปแล้ว\nสามารถใช้ได้อีกครั้งใน ${( (_codeStatus?['secondsUntilReset'] ?? 0) ~/ 3600)} ชั่วโมง',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                )
              ],
            ),
          ),
          SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canSubmit ? handleSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? Colors.teal[700] : Colors.grey[400],
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              canSubmit ? 'สร้างคิวอาร์โค้ด' : 'กรอกข้อมูลให้ครบถ้วน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (userPoints > 0 && userPoints <= 10) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'คำเตือน: หากไม่ได้ใช้สนามตามเวลาที่จอง แอดมินจะหักคะแนนของคุณ',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }  void handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // เตรียมข้อมูลการจองสำหรับส่งไปหน้า QR Confirmation
    final bookingData = {
      'courtId': selectedCourtId!,
      'courtName': selectedCourtName!,
      'date': DateFormat('yyyy-MM-dd').format(selectedDate!),
      'timeSlots': selectedTimeSlots, // เปลี่ยนเป็น array
      'timeSlotDisplay': selectedTimeSlots.join(', '), // สำหรับแสดงผล
      'activity': selectedActivity!,
      'note': noteController.isNotEmpty ? noteController : null,
      'participantCodes': _participantControllers.map((c) => c.text.trim().toUpperCase()).where((s) => s.isNotEmpty).toList(),
    };

    // นำทางไปหน้า QR Confirmation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingSuccessPage(bookingData: bookingData),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('เกิดข้อผิดพลาด'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPointsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: userPoints > 0 ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              userPoints > 0 ? Icons.stars : Icons.warning,
              color: userPoints > 0 ? Colors.green.shade700 : Colors.red.shade700,
              size: 32,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'คะแนนการจอง',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: userPoints > 0 ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                  SizedBox(height: 4),
                  if (isLoadingPoints)
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    Text(
                      '$userPoints คะแนน',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: userPoints > 0 ? Colors.green.shade600 : Colors.red.shade600,
                      ),
                    ),
                    if (userPoints <= 10) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Text(
                          userPoints == 0 
                            ? '❌ ไม่สามารถจองได้ - คะแนนหมด' 
                            : '⚠️ คะแนนเหลือน้อย',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (!isLoadingPoints && userPoints > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'พร้อมจอง',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
