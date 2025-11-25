import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/booking_service.dart';
import 'services/settings_service.dart';
import 'services/auth_service.dart';
import 'services/content_service.dart';
import 'BookingSuccessPage.dart';

class NewAdvancedBookingPage extends StatefulWidget {
  final String? initialBookingType;
  final String? initialCourtId;
  final String? initialCourtName;
  final DateTime? initialDate;
  final List<String>? initialTimeSlots;

  const NewAdvancedBookingPage({
    Key? key,
    this.initialBookingType,
    this.initialCourtId,
    this.initialCourtName,
    this.initialDate,
    this.initialTimeSlots,
  }) : super(key: key);

  @override
  _NewAdvancedBookingPageState createState() => _NewAdvancedBookingPageState();
}

class _NewAdvancedBookingPageState extends State<NewAdvancedBookingPage> with WidgetsBindingObserver {
  int currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  
  // Add refresh key for FutureBuilder
  int _refreshKey = 0;

  // Form data
  String? selectedBookingType;
  String? selectedCourtId;
  String? selectedCourtName;
  String? selectedCourtType;
  DateTime? selectedDate;
  List<String> selectedTimeSlots = [];
  String? selectedActivity;
  String noteController = '';

  // Controllers for activity booking
  final TextEditingController _responsibleNameController = TextEditingController();
  final TextEditingController _responsibleIdController = TextEditingController();
  final TextEditingController _responsiblePhoneController = TextEditingController();
  final TextEditingController _responsibleEmailController = TextEditingController();
  final TextEditingController _activityNameController = TextEditingController();
  final TextEditingController _activityDescriptionController = TextEditingController();

  Map<String, dynamic> courts = {};
  List<dynamic> availableTimeSlots = [];
  bool isLoading = false;
  // Code status and participant codes
  Map<String, dynamic>? _codeStatus;
  bool _loadingCodeStatus = true;
  final List<TextEditingController> _participantControllers = [];
  int _requiredParticipants = 0;
  bool _blockedByDomainPolicy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // เพิ่ม observer
    // Listen to global test mode changes so the UI refreshes immediately
    SettingsService.testModeNotifier.addListener(_onTestModeChanged);
    // Set initial booking type if provided
    if (widget.initialBookingType != null) {
      selectedBookingType = widget.initialBookingType;
      // Skip the booking type selection step - start with court selection
      currentStep = 0; // Changed from 1 to 0 to start with court selection
    }
    // Apply initial pre-selections if provided
    if (widget.initialCourtId != null) {
      selectedCourtId = widget.initialCourtId;
      selectedCourtName = widget.initialCourtName;
    }
    if (widget.initialDate != null) {
      selectedDate = widget.initialDate;
    }
    if ((widget.initialTimeSlots ?? const []).isNotEmpty) {
      selectedTimeSlots = List<String>.from(widget.initialTimeSlots!);
    }
    _loadCourts();
    
    // Auto-select appropriate date based on booking type
    _setInitialDate();
    _loadCodeStatus();
    _loadDomainPolicy();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // รีเฟรชข้อมูลเมื่อกลับมาที่แอป
      setState(() {
        _refreshKey++; // บังคับให้ rebuild FutureBuilder
      });
    }
  }

  Future<void> _loadCodeStatus() async {
    try {
      final status = await BookingService.getCodeStatus();
      if (mounted) setState(() { _codeStatus = status; _loadingCodeStatus = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingCodeStatus = false; });
    }
  }

  bool _isUniversityEmail(String email) {
    final e = email.toLowerCase().trim();
    return e.endsWith('@silpakorn.edu') || e.endsWith('@su.ac.th');
  }

  Future<void> _loadDomainPolicy() async {
    try {
      final me = await AuthService.getCurrentUser();
      final meta = await ContentService.getContentWithMeta('allow_non_university_booking');
      final allowStr = (meta['value'] ?? '1').toString().toLowerCase();
      final allow = allowStr == '1' || allowStr == 'true';
      final isAdmin = (me?['role'] ?? '') == 'admin';
      final email = (me?['email'] ?? '').toString();
      final isUni = email.isNotEmpty && _isUniversityEmail(email);
      if (mounted) setState(() { _blockedByDomainPolicy = !allow && !isAdmin && !isUni; });
    } catch (_) {
      if (mounted) setState(() { _blockedByDomainPolicy = false; });
    }
  }

  Future<bool> _ensureAllowedOrExplain() async {
    if (!_blockedByDomainPolicy) return true;
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
    return false;
  }

  int _computeRequiredParticipants() {
    int requiredPlayers = 2;
    if (selectedCourtId != null) {
      final court = courts[selectedCourtId];
      final category = court?['category']?.toString() ?? '';
      final defaultRequiredByCategory = {
        'badminton': 2,
        'tennis': 2,
        'futsal': 10,
        'football': 22,
        'basketball': 10,
        'volleyball': 10,
        'multipurpose': 10,
      };
      requiredPlayers = (court?['requiredPlayers'] ?? defaultRequiredByCategory[category] ?? 2) as int;
    }
    return (requiredPlayers - 1).clamp(0, 100);
  }

  void _syncParticipantControllers() {
    _requiredParticipants = _computeRequiredParticipants();
    while (_participantControllers.length < _requiredParticipants) {
      _participantControllers.add(TextEditingController());
    }
    while (_participantControllers.length > _requiredParticipants) {
      _participantControllers.removeLast();
    }
  }

  void _setInitialDate() {
    if (selectedBookingType == 'activity') {
      // For activity booking: start from 1 month ahead
      selectedDate = DateTime.now().add(Duration(days: 30));
    } else {
      // For regular booking: today
      selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ลบ observer
    SettingsService.testModeNotifier.removeListener(_onTestModeChanged);
    _responsibleNameController.dispose();
    _responsibleIdController.dispose();
    _responsiblePhoneController.dispose();
    _responsibleEmailController.dispose();
    _activityNameController.dispose();
    _activityDescriptionController.dispose();
    super.dispose();
  }

  void _onTestModeChanged() {
    // Force rebuild so the FutureBuilder which reads test mode re-evaluates
    if (mounted) setState(() { _refreshKey++; });
  }

  Future<void> _loadCourts() async {
    setState(() {
      isLoading = true;
    });

    try {
      print('📍 [Advanced] Loading courts...');
      final response = await BookingService.getCourts();
      print('📍 [Advanced] getCourts response keys: ${response.keys}');
      
      // API /courts ส่งกลับมาแค่ { "courts": {...} } ไม่มี success
      if (response.containsKey('courts')) {
        setState(() {
          courts = response['courts'] ?? {};
        });
        print('📍 [Advanced] Loaded ${courts.length} courts successfully');
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('❌ [Advanced] Error loading courts: $e');
      _showError('ไม่สามารถโหลดข้อมูลสนามได้: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F8FF),
      appBar: AppBar(
        backgroundColor: Colors.teal[700],
        title: Text(
          'จองสนาม',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildStepperContent(),
    );
  }

  Widget _buildStepperContent() {
    // Calculate total steps based on booking type
    int totalSteps = selectedBookingType == null ? 4 : 3; // Reduced steps (no time selection for activity)

    // Define steps dynamically
    List<Step> steps = [];

    // Only add booking type step if not pre-selected
    if (selectedBookingType == null) {
      steps.add(Step(
        title: Text('ประเภทการจอง'),
        content: _buildBookingTypeSelection(),
        isActive: currentStep == 0,
        state: currentStep == 0 ? StepState.editing : (selectedBookingType != null ? StepState.complete : StepState.indexed),
      ));
    }

    // Adjust step indices based on whether type selection is skipped
    int baseStepIndex = selectedBookingType == null ? 1 : 0;

    steps.addAll([
      Step(
        title: Text('เลือกสนาม'),
        content: _buildCourtSelection(),
        isActive: currentStep == baseStepIndex,
        state: currentStep == baseStepIndex ? StepState.editing : (selectedCourtId != null ? StepState.complete : StepState.indexed),
      ),
      Step(
        title: Text('เลือกวันที่'),
        content: _buildDatePicker(),
        isActive: currentStep == baseStepIndex + 1,
        state: currentStep == baseStepIndex + 1 ? StepState.editing : (selectedDate != null ? StepState.complete : StepState.indexed),
      ),
    ]);

    // Only add time selection step for regular booking
    if (selectedBookingType == 'regular') {
      steps.add(Step(
        title: Text('เลือกเวลา'),
        content: _buildTimeSlotSelection(),
        isActive: currentStep == baseStepIndex + 2,
        state: currentStep == baseStepIndex + 2 ? StepState.editing : (selectedTimeSlots.isNotEmpty ? StepState.complete : StepState.indexed),
      ));
    }

    steps.add(Step(
      title: Text('ยืนยันการจอง'),
      content: _buildConfirmation(),
      isActive: currentStep == totalSteps - 1,
      state: currentStep == totalSteps - 1 ? StepState.editing : StepState.indexed,
    ));

    return Stepper(
      currentStep: currentStep,
      onStepTapped: (step) {
        setState(() {
          currentStep = step;
        });
      },
      steps: steps,
      controlsBuilder: (context, details) {
        return Row(
          children: [
            if (details.stepIndex > 0 || (details.stepIndex == 0 && selectedBookingType == null))
              TextButton(
                onPressed: details.onStepCancel,
                child: Text('ย้อนกลับ'),
              ),
            SizedBox(width: 12),
            ElevatedButton(
              onPressed: details.onStepContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
              ),
              child: Text(
                details.stepIndex == totalSteps - 1 ? 'ยืนยันการจอง' : 'ถัดไป',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
      onStepContinue: () {
        if (_validateCurrentStep()) {
          if (currentStep < totalSteps - 1) {
            setState(() {
              currentStep++;
            });
          } else {
            _submitBooking();
          }
        }
      },
      onStepCancel: () {
        if (currentStep > 0) {
          setState(() {
            currentStep--;
          });
        } else if (selectedBookingType != null && currentStep == 0) {
          // If we're at step 0 but type is pre-selected, we shouldn't be able to go back
          // This case shouldn't occur with the current logic
        }
      },
    );
  }

  Widget _buildBookingTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_blockedByDomainPolicy)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.block, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ขณะนี้ผู้ใช้ที่ไม่ใช่อีเมลของทางมหาวิทยาลัยไม่สามารถทำการจองได้ชั่วคราว',
                    style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        Text(
          'เลือกประเภทการจอง',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        RadioListTile<String>(
          title: Text('การจองใช้งานทั่วไป'),
          subtitle: Text('จองสนามเพื่อเล่นกีฬาส่วนตัว (จองได้เฉพาะในวันเดียว)'),
          value: 'regular',
          groupValue: selectedBookingType,
          onChanged: (value) {
            setState(() {
              selectedBookingType = value;
              _setInitialDate(); // Update date when booking type changes
            });
          },
        ),
        RadioListTile<String>(
          title: Text('การจองสำหรับกิจกรรม'),
          subtitle: Text('ขออนุญาตจัดกิจกรรมพิเศษ (จองล่วงหน้าได้ 1-2 เดือน)'),
          value: 'activity',
          groupValue: selectedBookingType,
          onChanged: (value) {
            setState(() {
              selectedBookingType = value;
              _setInitialDate(); // Update date when booking type changes
            });
          },
        ),
      ],
    );
  }

  Widget _buildCourtSelection() {
    if (courts.isEmpty) {
      return Center(child: Text('ไม่พบข้อมูลสนาม'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'เลือกสนาม',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        ...courts.entries.map((entry) {
          final courtId = entry.key;
          final courtData = entry.value;
          final courtName = courtData['name'] ?? 'ไม่ระบุชื่อ';
          final courtType = courtData['type'] ?? 'ไม่ระบุประเภท';
          final isActivityOnly = courtData['isActivityOnly'] ?? false;
          final isAvailable = (courtData['isAvailable'] ?? true) == true;
          final category = (courtData['category'] ?? '').toString().toLowerCase();

          // Icon and color mapping
          Map<String, dynamic> _iconConfigFor(String name, String category) {
            final low = (name + ' ' + category).toLowerCase();
            if (low.contains('แบด') || low.contains('badminton')) {
              return {'emoji': '🏸', 'color': Colors.purple.shade100};
            } else if (low.contains('เทนนิส') || low.contains('tennis')) {
              return {'emoji': '🎾', 'color': Colors.yellow.shade100};
            } else if (low.contains('ฟุตซอล') || low.contains('futsal')) {
              return {'emoji': '🥅', 'color': Colors.blue.shade100};
            } else if (low.contains('ฟุตบอล') || low.contains('football')) {
              return {'emoji': '⚽', 'color': Colors.green.shade100};
            } else if (low.contains('บาส') || low.contains('basketball')) {
              return {'emoji': '🏀', 'color': Colors.orange.shade100};
            } else if (low.contains('วอลเลย์') || low.contains('volleyball')) {
              return {'emoji': '🏐', 'color': Colors.red.shade100};
            } else if (low.contains('อเนกประสงค์') || low.contains('multipurpose')) {
              return {'emoji': '🎯', 'color': Colors.teal.shade100};
            }
            return {'emoji': '🎽', 'color': Colors.grey.shade200}; // อื่นๆ
          }
          final iconCfg = _iconConfigFor(courtName.toString(), category);
          
          // Hide courts that are not available
          if (!isAvailable) {
            if (selectedCourtId == courtId) {
              // Clear selected court if it has become unavailable
              selectedCourtId = null;
              selectedCourtName = null;
            }
            return SizedBox.shrink();
          }
          // Filter courts based on booking type
          if (selectedBookingType == 'regular' && isActivityOnly) {
            return SizedBox.shrink(); // Hide activity-only courts for regular booking
          }
          if (selectedBookingType == 'activity' && !isActivityOnly) {
            // For activity booking, show all courts but note which ones are activity-only
          }

          return Card(
            child: RadioListTile<String>(
              value: courtId,
              groupValue: selectedCourtId,
              onChanged: (value) {
                setState(() {
                  selectedCourtId = value;
                  selectedCourtName = courtName;
                  selectedCourtType = courtType;
                  _syncParticipantControllers();
                });
              },
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: (iconCfg['color'] as Color?) ?? Colors.grey.shade200,
                    child: Text(
                      (iconCfg['emoji'] as String?) ?? '🎽',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(courtName, style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(
                          isActivityOnly ? 'ประเภท: $courtType (เฉพาะกิจกรรม)' : 'ประเภท: $courtType',
                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'เลือกวันที่',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        // Show selected date prominently
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal[300]!),
          ),
          child: Column(
            children: [
              Icon(Icons.calendar_today, color: Colors.teal[700], size: 32),
              SizedBox(height: 8),
              Text(
                'วันที่เลือก',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.teal[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                selectedDate != null 
                  ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                  : 'ยังไม่ได้เลือก',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        FutureBuilder<List<bool>>(
          future: Future.wait([
            SettingsService.isTestModeEnabled(),
            AuthService.isAdmin(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            final values = snapshot.data ?? [false, false];
            final isTestMode = values[0];
            final isAdmin = values[1];
            DateTime minDate, maxDate;
            
            final today = DateTime.now();
            final todayOnlyDate = DateTime(today.year, today.month, today.day);
            // Never allow selecting dates before today. Test mode only widens maxDate.
            if (isTestMode) {
              minDate = todayOnlyDate;
              maxDate = DateTime(2030, 12, 31);
            } else {
              if (isAdmin) {
                // Admin: any future date (from today)
                minDate = todayOnlyDate;
                maxDate = DateTime(today.year + 10, 12, 31);
              } else if (selectedBookingType == 'regular') {
                // Regular users: only today
                minDate = todayOnlyDate;
                maxDate = todayOnlyDate;
              } else {
                // Activity booking: 30-60 days ahead
                minDate = todayOnlyDate.add(Duration(days: 30));
                maxDate = todayOnlyDate.add(Duration(days: 60));
              }
            }
            
            return CalendarDatePicker(
              initialDate: selectedDate ?? minDate,
              firstDate: minDate,
              lastDate: maxDate,
              onDateChanged: (date) {
                setState(() {
                  selectedDate = date;
                  selectedTimeSlots.clear(); // Clear time slots when date changes
                });
              },
            );
          },
        ),
        if (selectedBookingType == 'activity') 
          Padding(
            padding: EdgeInsets.only(top: 16),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'การจองกิจกรรม: จองได้ทั้งวัน ไม่ต้องเลือกเวลา',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimeSlotSelection() {
    return FutureBuilder<bool>(
      key: ValueKey(_refreshKey), // เพิ่ม key เพื่อบังคับ rebuild
      future: _isBookingTimeAllowed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        bool isAllowed = snapshot.data ?? false;
        
        // Check if booking is allowed at current time
        if (!isAllowed) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'เลือกช่วงเวลา',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.access_time_filled, color: Colors.red[700], size: 48),
                    SizedBox(height: 12),
                    Text(
                      'หมดเวลาการจอง',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      _getBookingTimeMessage(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        List<String> timeSlots = _generateTimeSlots();

        // ดึงข้อมูลช่วงเวลาที่จองแล้วและเช็คเวลาที่เลยมาแล้ว
        return FutureBuilder<Map<String, dynamic>>(
          future: _getAvailableTimeSlots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final bookedSlots = snapshot.data?['bookedSlots'] ?? <String>[];
            print('🔍 Debug: bookedSlots from server: $bookedSlots');
            
            final now = DateTime.now();
            final isToday = selectedDate != null && 
              selectedDate!.year == now.year &&
              selectedDate!.month == now.month &&
              selectedDate!.day == now.day;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เลือกช่วงเวลา',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: timeSlots.map<Widget>((timeSlot) {
                    final isSelected = selectedTimeSlots.contains(timeSlot);
                    
                    // ปรับปรุงการตรวจสอบการจอง - แก้ไขปัญหาการจับคู่ที่ผิดพลาด
                    bool isBooked = false;
                    
                    // ตรวจสอบแบบ exact match เท่านั้น - ไม่ใช้ contains
                    for (String bookedSlot in bookedSlots) {
                      String normalizedBookedSlot = bookedSlot.trim();
                      
                      // ตรวจสอบความตรงกันแบบแม่นยำ
                      if (timeSlot == normalizedBookedSlot) {
                        isBooked = true;
                        print('🚫 Debug: Exact match found - $timeSlot is booked');
                        break;
                      }
                    }
                    
                    // แสดง debug ข้อมูลสำหรับตรวจสอบ  
                    print('🔍 Debug: timeSlot=$timeSlot, isBooked=$isBooked, bookedSlots=$bookedSlots');
                    if (isBooked) {
                      print('🚫 Debug: Slot $timeSlot is BOOKED - should be RED and DISABLED');
                    }
                    
                    // เช็คว่าเวลาเลยมาแล้วหรือไม่
                    bool isPastTime = false;
                    if (isToday) {
                      final timeSlotParts = timeSlot.split('-');
                      final startTimeStr = timeSlotParts[0];
                      final timeParts = startTimeStr.split(':');
                      final startHour = int.parse(timeParts[0]);
                      final startMinute = int.parse(timeParts[1]);
                      
                      final currentTime = now.hour * 60 + now.minute;
                      final timeSlotStart = startHour * 60 + startMinute;
                      
                      isPastTime = currentTime >= timeSlotStart;
                    }
                    
                    // บังคับไม่ให้เลือกช่วงเวลาที่จองแล้ว
                    bool isDisabled = isBooked || isPastTime;
                    
                    return Container(
                      margin: EdgeInsets.all(2),
                      child: FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isBooked) ...[
                              Icon(
                                Icons.block,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                            ] else if (isPastTime) ...[
                              Icon(
                                Icons.access_time_filled,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 4),
                            ],
                            Text(
                              timeSlot,
                              style: TextStyle(
                                color: isBooked 
                                  ? Colors.white  // ข้อความสีขาวบนพื้นหลังแดง
                                  : isPastTime 
                                    ? Colors.grey[600]
                                    : isSelected 
                                      ? Colors.white 
                                      : Colors.black87,
                                fontWeight: isBooked ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        // บังคับให้ไม่เลือก timeSlot ที่จองแล้ว
                        selected: isSelected && !isDisabled,
                        // ปิดการทำงานของ onSelected สำหรับ timeSlot ที่ปิดใช้งาน
                        onSelected: isDisabled ? null : (selected) {
                          setState(() {
                            if (selectedBookingType == 'regular') {
                              // Regular booking: only one time slot
                              selectedTimeSlots.clear();
                              if (selected) {
                                selectedTimeSlots.add(timeSlot);
                              }
                            } else {
                              // Activity booking: multiple time slots
                              if (selected) {
                                selectedTimeSlots.add(timeSlot);
                              } else {
                                selectedTimeSlots.remove(timeSlot);
                              }
                            }
                          });
                        },
                        // กำหนดสีพื้นหลัง
                        backgroundColor: isBooked 
                          ? Colors.red[600]!  // สีแดงเข้มสำหรับช่วงเวลาที่จองแล้ว
                          : isPastTime 
                            ? Colors.grey[300]
                            : Colors.white,
                        // กำหนดสีเมื่อถูกเลือก (แต่ควรไม่เกิดขึ้นสำหรับ timeSlot ที่ปิดใช้งาน)
                        selectedColor: isBooked 
                          ? Colors.red[600]!  
                          : isPastTime 
                            ? Colors.grey[300]
                            : Colors.teal,
                        // กำหนดสีเมื่อปิดใช้งาน
                        disabledColor: isBooked 
                          ? Colors.red[600]!
                          : Colors.grey[300],
                        // กำหนดเส้นขอบ
                        side: isBooked 
                          ? BorderSide(color: Colors.red[800]!, width: 2)
                          : isPastTime
                            ? BorderSide(color: Colors.grey[500]!, width: 1)
                            : null,
                        // แสดง tooltip เมื่อ hover
                        tooltip: isBooked 
                          ? '🚫 เวลานี้มีการจองแล้ว - ไม่สามารถเลือกได้'
                          : isPastTime 
                            ? '⏰ เวลานี้ผ่านไปแล้ว'
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                if (selectedTimeSlots.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'เวลาที่เลือก: ${selectedTimeSlots.join(", ")}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.teal[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                
                // คำอธิบายสถานะการจอง
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      // สถานะว่าง
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          SizedBox(width: 4),
                          Text('ว่าง', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                      SizedBox(width: 16),
                      // สถานะจองแล้ว
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red[300],
                              border: Border.all(color: Colors.red[600]!),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Icon(Icons.block, size: 8, color: Colors.red[800]),
                          ),
                          SizedBox(width: 4),
                          Text('จองแล้ว', style: TextStyle(fontSize: 12, color: Colors.red[600])),
                        ],
                      ),
                      SizedBox(width: 16),
                      // สถานะผ่านไปแล้ว
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              border: Border.all(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          SizedBox(width: 4),
                          Text('ผ่านไปแล้ว', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                if (selectedBookingType == 'regular') ...[
                  SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: FutureBuilder<bool>(
                        future: AuthService.isAdmin(),
                        builder: (context, snap) {
                          final isAdmin = snap.data == true;
                          if (isAdmin) {
                            return Text('แอดมินไม่ต้องกรอกรหัสผู้เข้าร่วม', style: TextStyle(color: Colors.black54));
                          }
                          return _buildParticipantCodesSection();
                        },
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  List<String> _generateTimeSlots() {
    if (selectedCourtId == null) return [];
    
    final courtData = courts[selectedCourtId];
    if (courtData == null) return [];
    
    final playStartTime = courtData['playStartTime'] ?? '12:00';
    final playEndTime = courtData['playEndTime'] ?? '22:00';
    
    final startHour = int.parse(playStartTime.split(':')[0]);
    final endHour = int.parse(playEndTime.split(':')[0]);
    
    List<String> slots = [];
    for (int hour = startHour; hour < endHour; hour++) {
      slots.add('${hour.toString().padLeft(2, '0')}:00-${(hour + 1).toString().padLeft(2, '0')}:00');
    }
    return slots;
  }

  // ฟังก์ชันตรวจสอบการซ้อนทับของช่วงเวลา
  bool isTimeInRange(String checkStart, String checkEnd, String bookedStart, String bookedEnd) {
    // แปลงเวลาเป็นตัวเลขเพื่อเปรียบเทียบ (เช่น "18:00" -> 1800)
    int checkStartNum = _timeToNumber(checkStart);
    int checkEndNum = _timeToNumber(checkEnd);
    int bookedStartNum = _timeToNumber(bookedStart);
    int bookedEndNum = _timeToNumber(bookedEnd);
    
    // ตรวจสอบการซ้อนทับ:
    // 1. ช่วงเวลาซ้อนทับเมื่อจุดเริ่มต้นของหนึ่งช่วงอยู่ก่อนจุดสิ้นสุดของอีกช่วงหนึ่ง
    // 2. และจุดสิ้นสุดของช่วงแรกอยู่หลังจุดเริ่มต้นของช่วงที่สอง
    bool overlaps = (checkStartNum < bookedEndNum) && (checkEndNum > bookedStartNum);
    
    print('🔍 Time overlap check: $checkStart-$checkEnd vs $bookedStart-$bookedEnd = $overlaps');
    return overlaps;
  }

  // แปลงเวลาเป็นตัวเลข เช่น "18:00" -> 1800
  int _timeToNumber(String time) {
    List<String> parts = time.split(':');
    if (parts.length == 2) {
      int hour = int.tryParse(parts[0]) ?? 0;
      int minute = int.tryParse(parts[1]) ?? 0;
      return hour * 100 + minute;
    }
    return 0;
  }

  Future<bool> _isBookingTimeAllowed() async {
    if (selectedCourtId == null) return false;
    
    // Check if global test mode is enabled (ทุกคนจองได้ทุกเวลา)
    final isTestMode = await SettingsService.isTestModeEnabled();
    print('🧪 Debug: Test Mode = $isTestMode'); // Debug log
    if (isTestMode) {
      print('✅ Debug: Test mode enabled - allowing all booking times'); // Debug log
      return true; // ทุกคนจองได้ทุกเวลาเมื่อเปิดโหมดทดสอบ
    }
    
    // Check if admin booking mode is enabled (เฉพาะ admin)
    final isAdmin = await AuthService.isAdmin();
    
    if (isAdmin) {
      print('✅ Debug: Admin mode enabled - allowing all booking times'); // Debug log
      return true; // Admin จองได้ทุกเวลาเมื่อเปิดโหมด admin
    }
    
    // ปกติ: ตรวจสอบเวลาการจองตามปกติ
    final courtData = courts[selectedCourtId];
    if (courtData == null) return false;
    
    final openBookingTime = courtData['openBookingTime'] ?? '09:00';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final openTimeParts = openBookingTime.split(':');
    final openHour = int.parse(openTimeParts[0]);
    final openMinute = int.parse(openTimeParts[1]);
    final openDateTime = DateTime(today.year, today.month, today.day, openHour, openMinute);
    
    final isAllowed = now.isAfter(openDateTime) || now.isAtSameMomentAs(openDateTime);
    print('⏰ Debug: Current time check - allowed: $isAllowed'); // Debug log
    return isAllowed;
  }

  // ดึงข้อมูลช่วงเวลาที่พร้อมใช้งาน
  Future<Map<String, dynamic>> _getAvailableTimeSlots() async {
    if (selectedCourtId == null || selectedDate == null) {
      return {'bookedSlots': <String>[]};
    }
    
    final dateStr = selectedDate!.toIso8601String().split('T')[0];
    final result = await BookingService.getCourtSchedule(selectedCourtId!, dateStr);
    
    if (result['success']) {
      return {'bookedSlots': result['bookedSlots'] ?? <String>[]};
    } else {
      print('Error getting court schedule: ${result['error']}');
      return {'bookedSlots': <String>[]};
    }
  }

  String _getBookingTimeMessage() {
    if (selectedCourtId == null) return 'กรุณาเลือกสนามก่อน';
    
    final courtData = courts[selectedCourtId];
    if (courtData == null) return 'ไม่พบข้อมูลสนาม';
    
    final openBookingTime = courtData['openBookingTime'] ?? '09:00';
    final courtName = courtData['name'] ?? 'สนาม';
    
    return 'สนาม $courtName เปิดรับจองเวลา $openBookingTime น.\nกรุณาเข้ามาจองใหม่ในเวลาที่กำหนด';
  }

  Widget _buildConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ยืนยันการจอง',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        _buildUserCodeCard(),
        SizedBox(height: 12),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConfirmationRow('ประเภทการจอง:', _getBookingTypeText()),
                _buildConfirmationRow('สนาม:', selectedCourtName ?? ''),
                _buildConfirmationRow('วันที่:', selectedDate != null ? DateFormat('dd/MM/yyyy').format(selectedDate!) : ''),
                _buildConfirmationRow('เวลา:', selectedTimeSlots.join(', ')),
                if (selectedBookingType == 'regular') ...[
                  SizedBox(height: 16),
                  _buildParticipantCodesSection(),
                ],
                if (selectedBookingType == 'activity') ...[
                  SizedBox(height: 16),
                  Text(
                    'ข้อมูลผู้รับผิดชอบ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  _buildActivityForm(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCodeCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.qr_code_2, color: Colors.teal[700]),
            SizedBox(width: 8),
            Expanded(
              child: _loadingCodeStatus
                  ? Row(children: [SizedBox(height:16,width:16,child: CircularProgressIndicator(strokeWidth:2)), SizedBox(width:8), Text('กำลังโหลดรหัสของคุณ...')])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('รหัสของคุณ', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        SelectableText(_codeStatus?['userCode'] ?? '-', style: TextStyle(fontSize: 16, letterSpacing: 1.5)),
                        if (_codeStatus != null) ...[
                          SizedBox(height: 6),
                          Row(children: [
                            Icon(_codeStatus!['usedToday'] == true ? Icons.lock_clock : Icons.lock_open, size: 16, color: _codeStatus!['usedToday'] == true ? Colors.red : Colors.green),
                            SizedBox(width: 6),
                            Expanded(child: Text(_codeStatus!['usedToday'] == true ? 'วันนี้ใช้รหัสไปแล้ว' : 'พร้อมใช้งานสำหรับวันนี้', style: TextStyle(fontSize: 12, color: Colors.black54)))
                          ])
                        ]
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantCodesSection() {
    _syncParticipantControllers();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('👥 รหัสผู้เข้าร่วม', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              );
            }),
          ),
      ],
    );
  }

  String _getBookingTypeText() {
    switch (selectedBookingType) {
      case 'regular':
        return 'การจองใช้งานทั่วไป';
      case 'activity':
        return 'การจองสำหรับกิจกรรม';
      default:
        return '';
    }
  }

  Widget _buildActivityForm() {
    return Column(
      children: [
        TextFormField(
          controller: _responsibleNameController,
          decoration: InputDecoration(
            labelText: 'ชื่อผู้รับผิดชอบ *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกชื่อผู้รับผิดชอบ';
            }
            return null;
          },
        ),
        SizedBox(height: 12),
        TextFormField(
          controller: _responsibleIdController,
          decoration: InputDecoration(
            labelText: 'รหัสประจำตัว *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.badge),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกรหัสประจำตัว';
            }
            return null;
          },
        ),
        SizedBox(height: 12),
        TextFormField(
          controller: _responsiblePhoneController,
          decoration: InputDecoration(
            labelText: 'เบอร์โทรศัพท์ *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกเบอร์โทรศัพท์';
            }
            if (value.length < 10) {
              return 'เบอร์โทรศัพท์ต้องมีอย่างน้อย 10 หลัก';
            }
            return null;
          },
        ),
        SizedBox(height: 12),
        TextFormField(
          controller: _responsibleEmailController,
          decoration: InputDecoration(
            labelText: 'อีเมล *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกอีเมล';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'รูปแบบอีเมลไม่ถูกต้อง';
            }
            return null;
          },
        ),
        SizedBox(height: 12),
        TextFormField(
          controller: _activityNameController,
          decoration: InputDecoration(
            labelText: 'ชื่อกิจกรรม *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.event),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกชื่อกิจกรรม';
            }
            return null;
          },
        ),
        SizedBox(height: 12),
        TextFormField(
          controller: _activityDescriptionController,
          decoration: InputDecoration(
            labelText: 'รายละเอียดกิจกรรม *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description),
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกรายละเอียดกิจกรรม';
            }
            return null;
          },
        ),
      ],
    );
  }

  bool _validateCurrentStep() {
    // Get the actual step index based on whether booking type is pre-selected
    int actualStepIndex = currentStep;
    if (selectedBookingType != null) {
      // If booking type is pre-selected, adjust the step index
      actualStepIndex = currentStep;
    }

    switch (actualStepIndex) {
      case 0:
        if (selectedBookingType == null && widget.initialBookingType == null) {
          _showError('กรุณาเลือกประเภทการจอง');
          return false;
        }
        if (selectedBookingType != null && selectedCourtId == null) {
          _showError('กรุณาเลือกสนามที่ต้องการจอง');
          return false;
        }
        return true;
      case 1:
        if (selectedBookingType == null) {
          // This is court selection step when type is not pre-selected
          if (selectedCourtId == null) {
            _showError('กรุณาเลือกสนามที่ต้องการจอง');
            return false;
          }
        } else {
          // This is date selection step when type is pre-selected
          if (selectedDate == null) {
            _showError('กรุณาเลือกวันที่ต้องการจอง');
            return false;
          }
        }
        return true;
      case 2:
        if (selectedBookingType == null) {
          // This is date selection step when type is not pre-selected
          if (selectedDate == null) {
            _showError('กรุณาเลือกวันที่ต้องการจอง');
            return false;
          }
        } else {
          // This is time selection step when type is pre-selected (only for regular booking)
          if (selectedBookingType == 'regular') {
            if (selectedTimeSlots.isEmpty) {
              _showError('กรุณาเลือกช่วงเวลาที่ต้องการจอง');
              return false;
            }
            // Note: Booking time validation is done in the UI with FutureBuilder
          }
          // For activity booking, auto-set full day
          if (selectedBookingType == 'activity') {
            selectedTimeSlots = ['ทั้งวัน'];
          }
        }
        return true;
      case 3:
        // This could be time selection (if type not pre-selected) or confirmation
        if (selectedBookingType == null) {
          // Time selection step
          if (selectedTimeSlots.isEmpty) {
            _showError('กรุณาเลือกช่วงเวลาที่ต้องการจอง');
            return false;
          }
          // Note: Booking time validation is done in the UI with FutureBuilder
        } else {
          // Confirmation step
          if (selectedBookingType == 'activity') {
            if (!_formKey.currentState!.validate()) {
              _showError('กรุณากรอกข้อมูลให้ครบถ้วนและถูกต้อง');
              return false;
            }
          }
        }
        return true;
      case 4:
        // Final confirmation step (when type not pre-selected)
        if (selectedBookingType == 'activity') {
          if (!_formKey.currentState!.validate()) {
            _showError('กรุณากรอกข้อมูลให้ครบถ้วนและถูกต้อง');
            return false;
          }
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _submitBooking() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Block immediately if domain policy disallows booking for this user
      final allowedNow = await _ensureAllowedOrExplain();
      if (!allowedNow) {
        setState(() { isLoading = false; });
        return;
      }
      if (selectedBookingType == 'activity') {
        // สำหรับการจองกิจกรรม ส่งคำขออนุมัติ
        final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
        
        final response = await BookingService.createActivityRequest(
          responsiblePersonName: _responsibleNameController.text,
          responsiblePersonId: _responsibleIdController.text,
          responsiblePersonPhone: _responsiblePhoneController.text,
          responsiblePersonEmail: _responsibleEmailController.text,
          activityName: _activityNameController.text,
          activityDescription: _activityDescriptionController.text,
          activityDate: dateStr,
          timeSlot: '08:00-17:00', // Full day activity
          courtId: selectedCourtId!,
          organizationDocument: 'pending_upload',
        );

        if (response['success']) {
          _showSuccess('ส่งคำขอจัดกิจกรรมเรียบร้อยแล้ว\nรอการอนุมัติจากแอดมิน');
        } else {
          _showError(response['error'] ?? 'เกิดข้อผิดพลาดในการส่งคำขอ');
        }
      } else {
        // สำหรับการจองปกติ
        if (selectedTimeSlots.isEmpty) {
          _showError('กรุณาเลือกช่วงเวลา');
          return;
        }

        // ตรวจสอบรหัสผู้เข้าร่วมครบถ้วน (ยกเว้นแอดมิน)
        final isAdmin = await AuthService.isAdmin();
        _syncParticipantControllers();
        if (!isAdmin && _requiredParticipants > 0) {
          final missing = _participantControllers.any((c) => c.text.trim().isEmpty);
          if (missing) {
            _showError('กรุณากรอกรหัสผู้เข้าร่วมให้ครบ');
            setState(() { isLoading = false; });
            return;
          }
        }

    final participantCodes = isAdmin
      ? <String>[]
      : _participantControllers
        .take(_requiredParticipants)
        .map((c) => c.text.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();

        final response = await BookingService.createBooking(
          courtId: selectedCourtId!,
          courtName: selectedCourtName ?? 'ไม่ระบุ',
          date: selectedDate!.toIso8601String(),
          timeSlots: selectedTimeSlots,
          bookingType: selectedBookingType!,
          participantCodes: participantCodes,
        );

        if (response['success']) {
          // ไปหน้า QR Code confirmation แทนการแสดงข้อความ
          final bookingData = {
            'bookingId': response['bookingId']?.toString(), // แปลงเป็น String
            'courtId': selectedCourtId!,
            'courtName': selectedCourtName ?? 'ไม่ระบุ',
            'date': selectedDate!.toIso8601String(),
            'timeSlots': selectedTimeSlots,
            'bookingType': selectedBookingType!,
            'activityType': selectedCourtName,
            'note': noteController.isNotEmpty ? noteController : null,
          };
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BookingSuccessPage(bookingData: bookingData),
            ),
          );
          return; // หยุดการทำงานที่นี่
        } else if (response['requiresConfirmation'] == true) {
          // แสดง confirmation dialog เมื่อต้องการยกเลิกการจองเดิม
          _showReplaceBookingDialog(response);
          return;
        } else {
          _showError(response['error'] ?? 'เกิดข้อผิดพลาดในการจอง');
        }
      }

      // กลับไปหน้าหลักหลังจากส่งคำขอสำเร็จ
      Navigator.pop(context);
      
    } catch (e) {
      _showError('เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // แสดง dialog สำหรับยืนยันการยกเลิกการจองเดิม
  void _showReplaceBookingDialog(Map<String, dynamic> response) {
    final existingBookings = response['existingBookings'] as List<dynamic>;
    final newBookingData = response['newBookingData'] as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('ยืนยันการยกเลิกการจอง'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                response['error'],
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'การจองที่มีอยู่:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ...existingBookings.map((booking) => Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏟️ ${booking['courtName'] ?? 'ไม่ระบุสนาม'}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('📅 ${booking['date'] ?? 'ไม่ระบุวันที่'}'),
                    Text('⏰ ${(booking['timeSlots'] as List?)?.join(', ') ?? 'ไม่ระบุเวลา'}'),
                    Text('📋 สถานะ: ${booking['status'] ?? 'ไม่ทราบ'}'),
                  ],
                ),
              )).toList(),
              SizedBox(height: 16),
              Text(
                'การจองใหม่:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏟️ ${newBookingData['courtName'] ?? 'ไม่ระบุสนาม'}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('📅 ${newBookingData['date'] ?? 'ไม่ระบุวันที่'}'),
                    Text('⏰ ${(newBookingData['timeSlots'] as List?)?.join(', ') ?? 'ไม่ระบุเวลา'}'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmReplaceBooking(existingBookings, newBookingData);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text('ยืนยันการยกเลิกและจองใหม่'),
            ),
          ],
        );
      },
    );
  }

  // ยืนยันการยกเลิกการจองเดิมและสร้างการจองใหม่
  Future<void> _confirmReplaceBooking(List<dynamic> existingBookings, Map<String, dynamic> newBookingData) async {
    setState(() {
      isLoading = true;
    });

    try {
      // ยกเลิกการจองเก่าทั้งหมด
      for (final booking in existingBookings) {
        await BookingService.cancelBooking(booking['id'] as String);
      }
      
      // สร้างการจองใหม่
      final response = await BookingService.confirmReplaceBooking(
        courtId: newBookingData['courtId'],
        date: newBookingData['date'],
        timeSlots: List<String>.from(newBookingData['timeSlots']),
        courtName: newBookingData['courtName'] ?? '',
        participantCodes: _participantControllers
            .take(_requiredParticipants)
            .map((c) => c.text.trim().toUpperCase())
            .where((s) => s.isNotEmpty)
            .toList(),
      );

      if (response['success']) {
        // ไปหน้า success page
        final bookingData = {
          'bookingId': response['bookingId']?.toString(), // แปลงเป็น String
          'courtId': newBookingData['courtId'],
          'courtName': newBookingData['courtName'],
          'date': newBookingData['date'],
          'timeSlots': newBookingData['timeSlots'],
          'bookingType': newBookingData['bookingType'],
          'activityType': newBookingData['activityType'],
          'note': newBookingData['note'],
        };
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingSuccessPage(bookingData: bookingData),
          ),
        );
      } else {
        _showError(response['error'] ?? 'เกิดข้อผิดพลาดในการยกเลิกและจองใหม่');
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}
