import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'services/court_management_service_new.dart';
import 'services/admin_auth_service.dart';
import 'widgets/map_location_picker.dart';
import 'widgets/simple_court_qr.dart';

class CourtManagementPage extends StatefulWidget {
  @override
  _CourtManagementPageState createState() => _CourtManagementPageState();
}

class _CourtManagementPageState extends State<CourtManagementPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  Map<String, dynamic> courts = {};
  bool isLoading = true;
  String? error;
  String? _editingCourtId; // ID ของสนามที่กำลังแก้ไข
  // สถานะตัวกรองรายการสนาม: all|active|inactive
  String _courtStatusFilter = 'all';
  
  // Controllers สำหรับ form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _openBookingTimeController = TextEditingController();
  final TextEditingController _playStartTimeController = TextEditingController();
  final TextEditingController _playEndTimeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _requiredPlayersController = TextEditingController();
  
  String _selectedType = 'outdoor';
  String _selectedCategory = 'tennis';
  final TextEditingController _customCategoryController = TextEditingController();
  bool _isActivityOnly = false;
  bool _isAvailable = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCourts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _numberController.dispose();
    _openBookingTimeController.dispose();
    _playStartTimeController.dispose();
    _playEndTimeController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _requiredPlayersController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCourts() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final result = await CourtManagementService.getAllCourts();
      print('Courts loaded: ${result['courts']?.length ?? 0} courts'); // Debug log
      
      setState(() {
        courts = result['courts'] ?? {};
        isLoading = false;
      });
    } catch (e) {
      print('Error loading courts: $e'); // Debug log
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _addCourt() async {
    if (!_validateForm()) return;

    try {
      print('🔄 Adding court with data:');
      
      // ตรวจสอบและสร้าง admin token ถ้าจำเป็น
      final authResult = await AdminAuthService.ensureAdminToken();
      if (authResult['success'] != true) {
        _showErrorDialog('ไม่สามารถสร้าง admin token ได้: ${authResult['error']}');
        return;
      }
      
      final String finalCategory = _selectedCategory == 'other'
          ? _customCategoryController.text.trim().toLowerCase()
          : _selectedCategory;

      final courtData = {
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'category': finalCategory.isNotEmpty ? finalCategory : _selectedCategory,
        'number': int.parse(_numberController.text),
        'isActivityOnly': _isActivityOnly,
        'openBookingTime': _openBookingTimeController.text.trim(),
        'playStartTime': _playStartTimeController.text.trim(),
        'playEndTime': _playEndTimeController.text.trim(),
        'isAvailable': _isAvailable,
        'requiredPlayers': _requiredPlayersController.text.isNotEmpty ? int.parse(_requiredPlayersController.text) : _getDefaultRequiredPlayers(_selectedCategory),
        'location': _latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty ? {
          'latitude': double.parse(_latitudeController.text),
          'longitude': double.parse(_longitudeController.text),
          'address': _addressController.text.trim(),
          'description': _descriptionController.text.trim(),
        } : null,
      };

      print('Court data: $courtData');
      
      final result = await CourtManagementService.addCourt(courtData);
      print('Add court result: $result');

      if (result['success'] == true) {
        _clearForm();
        await _loadCourts(); // รอให้โหลดเสร็จ
        _showSuccessDialog(result['message'] ?? 'เพิ่มสนามสำเร็จ');
        // กลับไปหน้า Court List
        _tabController.animateTo(0);
      } else {
        print('❌ Add court failed: ${result['error']}');
        _showErrorDialog(result['error'] ?? 'เกิดข้อผิดพลาดในการเพิ่มสนาม');
      }
    } catch (e) {
      print('❌ Add court exception: $e');
      _showErrorDialog('เกิดข้อผิดพลาด: $e');
    }
  }

  Future<void> _updateCourt() async {
    if (_editingCourtId == null || !_validateForm()) return;

    try {
      print('🔄 Updating court ${_editingCourtId} with data:');
      
      // ตรวจสอบและสร้าง admin token ถ้าจำเป็น
      final authResult = await AdminAuthService.ensureAdminToken();
      if (authResult['success'] != true) {
        _showErrorDialog('ไม่สามารถสร้าง admin token ได้: ${authResult['error']}');
        return;
      }
      
      final courtData = {
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'category': _selectedCategory,
        'number': int.parse(_numberController.text),
        'isActivityOnly': _isActivityOnly,
        'openBookingTime': _openBookingTimeController.text.trim(),
        'playStartTime': _playStartTimeController.text.trim(),
        'playEndTime': _playEndTimeController.text.trim(),
        'isAvailable': _isAvailable,
        'requiredPlayers': _requiredPlayersController.text.isNotEmpty ? int.parse(_requiredPlayersController.text) : _getDefaultRequiredPlayers(_selectedCategory),
        'location': _latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty ? {
          'latitude': double.parse(_latitudeController.text),
          'longitude': double.parse(_longitudeController.text),
          'address': _addressController.text.trim(),
          'description': _descriptionController.text.trim(),
        } : null,
      };

      print('Court data: $courtData');
      
      final result = await CourtManagementService.updateCourt(_editingCourtId!, courtData);
      print('Update court result: $result');

      if (result['success'] == true) {
        _clearForm();
        await _loadCourts(); // รอให้โหลดเสร็จ
        _showSuccessDialog(result['message'] ?? 'แก้ไขสนามสำเร็จ');
        // กลับไปหน้า Court List
        _tabController.animateTo(0);
      } else {
        print('❌ Update court failed: ${result['error']}');
        _showErrorDialog(result['error'] ?? 'เกิดข้อผิดพลาดในการแก้ไขสนาม');
      }
    } catch (e) {
      print('❌ Update court exception: $e');
      _showErrorDialog('เกิดข้อผิดพลาด: $e');
    }
  }

  Future<void> _deleteCourt(String courtId, String courtName) async {
    final confirmed = await _showConfirmDialog(
      'ยืนยันการลบ',
      'คุณต้องการลบสนาม "$courtName" หรือไม่?',
    );

    if (confirmed != true) return;

    try {
      final result = await CourtManagementService.deleteCourt(courtId);

      if (result['success']) {
        await _loadCourts(); // รอให้โหลดเสร็จ
        _showSuccessDialog(result['message'] ?? 'ลบสนามสำเร็จ');
      } else {
        _showErrorDialog(result['error'] ?? 'เกิดข้อผิดพลาด');
      }
    } catch (e) {
      _showErrorDialog('เกิดข้อผิดพลาด: $e');
    }
  }

  Future<void> _toggleCourtAvailability(String courtId, bool currentStatus) async {
    try {
      final result = await CourtManagementService.toggleCourtAvailability(courtId);

      if (result['success']) {
        _showSuccessDialog(result['message'] ?? (currentStatus ? 'ปิดการใช้งานสนามสำเร็จ' : 'เปิดการใช้งานสนามสำเร็จ'));
        _loadCourts();
      } else {
        _showErrorDialog(result['error'] ?? 'เกิดข้อผิดพลาด');
      }
    } catch (e) {
      _showErrorDialog('เกิดข้อผิดพลาด: $e');
    }
  }

  bool _validateForm() {
    if (_nameController.text.isEmpty ||
        _numberController.text.isEmpty ||
        _openBookingTimeController.text.isEmpty ||
        _playStartTimeController.text.isEmpty ||
        _playEndTimeController.text.isEmpty) {
      _showErrorDialog('กรุณากรอกข้อมูลให้ครบถ้วน');
      return false;
    }

    // ตรวจสอบรูปแบบเวลา
    final timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    if (!timeRegex.hasMatch(_openBookingTimeController.text) ||
        !timeRegex.hasMatch(_playStartTimeController.text) ||
        !timeRegex.hasMatch(_playEndTimeController.text)) {
      _showErrorDialog('รูปแบบเวลาไม่ถูกต้อง (ใช้รูปแบบ HH:MM)');
      return false;
    }

    try {
      int.parse(_numberController.text);
    } catch (e) {
      _showErrorDialog('หมายเลขสนามต้องเป็นตัวเลข');
      return false;
    }

    // ตรวจสอบจำนวนคน (ถ้ามีการใส่)
    if (_requiredPlayersController.text.isNotEmpty) {
      try {
        final players = int.parse(_requiredPlayersController.text);
        if (players < 1 || players > 50) {
          _showErrorDialog('จำนวนคนต้องอยู่ระหว่าง 1-50 คน');
          return false;
        }
      } catch (e) {
        _showErrorDialog('จำนวนคนต้องเป็นตัวเลข');
        return false;
      }
    }

    // ตรวจสอบพิกัด (ถ้ามี)
    if (_latitudeController.text.isNotEmpty || _longitudeController.text.isNotEmpty) {
      try {
        if (_latitudeController.text.isNotEmpty) double.parse(_latitudeController.text);
        if (_longitudeController.text.isNotEmpty) double.parse(_longitudeController.text);
      } catch (e) {
        _showErrorDialog('พิกัดต้องเป็นตัวเลข');
        return false;
      }
    }

    return true;
  }

  // กำหนดจำนวนคนเริ่มต้นตามประเภทสนาม
  int _getDefaultRequiredPlayers(String category) {
    switch (category) {
      case 'futsal':
        return 4; // ฟุตซอล 4 คน
      case 'basketball':
        return 5; // บาสเกตบอล 5 คน
      case 'football':
        return 11; // ฟุตบอล 11 คน
      case 'volleyball':
        return 6; // วอลเลย์บอล 6 คน
      case 'tennis':
        return 2; // เทนนิส 2 คน
      case 'badminton':
        return 2; // แบดมินตัน 2 คน
      case 'table_tennis':
        return 2; // เทเบิลเทนนิส 2 คน
      case 'takraw':
        return 3; // ตะกร้อ 3 คน
      case 'multipurpose':
        return 4; // อเนกประสงค์ 4 คน
      default:
        return 2; // ค่าเริ่มต้น 2 คน
    }
  }

  // เลือกตำแหน่งจากแผนที่
  Future<void> _selectLocationFromMap() async {
    try {
      // ตรวจสอบว่ามีตำแหน่งเดิมหรือไม่
      LatLng? initialLocation;
      if (_latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty) {
        try {
          initialLocation = LatLng(
            double.parse(_latitudeController.text),
            double.parse(_longitudeController.text),
          );
        } catch (e) {
          // ใช้ตำแหน่งเริ่มต้น - มหาวิทยาลัยศิลปากร วิทยาเขตสนามจันทร์
          initialLocation = LatLng(13.8199, 100.0433); // มหาวิทยาลัยศิลปากร สนามจันทร์
        }
      } else {
        initialLocation = LatLng(13.8199, 100.0433); // มหาวิทยาลัยศิลปากร สนามจันทร์
      }

      final LatLng? selectedLocation = await Navigator.push<LatLng>(
        context,
        MaterialPageRoute(
          builder: (context) => MapLocationPicker(
            initialLocation: initialLocation,
            title: 'เลือกตำแหน่งสนาม',
            onLocationSelected: (location) {
              // Callback เมื่อเลือกตำแหน่ง
            },
          ),
        ),
      );

      if (selectedLocation != null) {
        setState(() {
          _latitudeController.text = selectedLocation.latitude.toStringAsFixed(6);
          _longitudeController.text = selectedLocation.longitude.toStringAsFixed(6);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เลือกตำแหน่งสำเร็จ'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('เกิดข้อผิดพลาดในการเลือกตำแหน่ง: $e');
    }
  }

  // Time Picker Helper
  Future<void> _selectTime(BuildContext context, TextEditingController controller, String title) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      controller.text = formattedTime;
    }
  }

  // Quick Time Selection Helper
  Widget _buildQuickTimeButtons(TextEditingController controller) {
    final quickTimes = [
      '06:00', '07:00', '08:00', '09:00', '10:00',
      '17:00', '18:00', '19:00', '20:00', '21:00', '22:00'
    ];
    
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: quickTimes.map((time) => 
        ActionChip(
          label: Text(time, style: TextStyle(fontSize: 12)),
          onPressed: () {
            controller.text = time;
          },
          backgroundColor: Colors.grey[200],
        )
      ).toList(),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _numberController.clear();
    _openBookingTimeController.clear();
    _playStartTimeController.clear();
    _playEndTimeController.clear();
    _addressController.clear();
    _descriptionController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _requiredPlayersController.clear();
    _selectedType = 'outdoor';
    _selectedCategory = 'tennis';
    _isActivityOnly = false;
    _isAvailable = true;
    _editingCourtId = null;
    
    // ตั้งค่าเริ่มต้นจำนวนคนตามหมวดหมู่
    _requiredPlayersController.text = _getDefaultRequiredPlayers(_selectedCategory).toString();
    
    setState(() {});
  }

  void _fillFormWithCourtData(String courtId, Map<String, dynamic> court) {
    _editingCourtId = courtId;
    _nameController.text = court['name']?.toString() ?? '';
    _numberController.text = (court['number'] ?? 0).toString();
    _openBookingTimeController.text = court['openBookingTime']?.toString() ?? '';
    _playStartTimeController.text = court['playStartTime']?.toString() ?? '';
    _playEndTimeController.text = court['playEndTime']?.toString() ?? '';
    _selectedType = court['type']?.toString() ?? 'outdoor';
    _selectedCategory = court['category']?.toString() ?? 'tennis';
    // If category is not in predefined list, mark as other and fill custom
    const predefined = {
      'tennis','basketball','badminton','futsal','football','volleyball','takraw','table_tennis','multipurpose'
    };
    if (!predefined.contains(_selectedCategory)) {
      _customCategoryController.text = _selectedCategory;
      _selectedCategory = 'other';
    } else {
      _customCategoryController.clear();
    }
    _isActivityOnly = court['isActivityOnly'] == true;
    _isAvailable = court['isAvailable'] != false; // default to true
    // กำหนดค่าจำนวนคน - ใช้ค่าจาก Firebase หรือค่าเริ่มต้น
    final requiredPlayers = court['requiredPlayers'];
    if (requiredPlayers != null) {
      _requiredPlayersController.text = requiredPlayers.toString();
    } else {
      _requiredPlayersController.text = _getDefaultRequiredPlayers(_selectedCategory).toString();
    }
    
    // Clear location fields first
    _latitudeController.clear();
    _longitudeController.clear();
    _addressController.clear(); 
    _descriptionController.clear();
    
    if (court['location'] != null && court['location'] is Map) {
      final location = court['location'] as Map<String, dynamic>;
      _latitudeController.text = location['latitude']?.toString() ?? '';
      _longitudeController.text = location['longitude']?.toString() ?? '';
      _addressController.text = location['address']?.toString() ?? '';
      _descriptionController.text = location['description']?.toString() ?? '';
    }
    
    setState(() {});
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('สำเร็จ'),
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ข้อผิดพลาด'),
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

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('ยืนยัน'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการสนาม'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'รายการสนาม'),
            Tab(text: 'เพิ่ม/แก้ไขสนาม'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCourtsList(),
          _buildCourtForm(),
        ],
      ),
    );
  }

  Widget _buildCourtsList() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error!, style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCourts,
              child: Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (courts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_tennis, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('ไม่มีข้อมูลสนาม'),
            SizedBox(height: 8),
            Text('จำนวนข้อมูลที่โหลด: ${courts.length}', 
                 style: TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCourts,
              child: Text('รีเฟรช'),
            ),
          ],
        ),
      );
    }

    // จัดกลุ่มสนามตามประเภท
    final outdoorCourts = <String, dynamic>{};
    final indoorCourts = <String, dynamic>{};

    print('Total courts before grouping: ${courts.length}'); // Debug log
    
    courts.forEach((key, court) {
      print('Processing court: $key, type: ${court['type']}'); // Debug log
      if (court['type'] == 'outdoor') {
        outdoorCourts[key] = court;
      } else if (court['type'] == 'indoor') {
        indoorCourts[key] = court;
      }
    });
    
    print('Outdoor courts: ${outdoorCourts.length}'); // Debug log
    print('Indoor courts: ${indoorCourts.length}'); // Debug log

    return RefreshIndicator(
      onRefresh: _loadCourts,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // แถวตัวกรองสถานะสนาม
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, color: Colors.teal),
                  const SizedBox(width: 8),
                  const Text('กรองสถานะ: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _courtStatusFilter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                      DropdownMenuItem(value: 'active', child: Text('เปิดใช้งาน')),
                      DropdownMenuItem(value: 'inactive', child: Text('ปิดใช้งาน')),
                    ],
                    onChanged: (v){
                      if (v==null) return;
                      setState(()=> _courtStatusFilter = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (outdoorCourts.isNotEmpty) ...[
            _buildCourtSection('สนามกลางแจ้ง (${outdoorCourts.length} สนาม)', outdoorCourts, Colors.orange),
            SizedBox(height: 16),
          ],
          if (indoorCourts.isNotEmpty) ...[
            _buildCourtSection('สนามในร่ม (${indoorCourts.length} สนาม)', indoorCourts, Colors.blue),
          ],
        ],
      ),
    );
  }

  Widget _buildCourtSection(String title, Map<String, dynamic> courtList, Color color) {
    // กรองตามสถานะจาก _courtStatusFilter
    final filteredEntries = courtList.entries.where((e){
      final isAvailable = (e.value['isAvailable'] ?? true) == true;
      switch (_courtStatusFilter) {
        case 'active':
          return isAvailable;
        case 'inactive':
          return !isAvailable;
        default:
          return true;
      }
    }).toList();
    final countLabel = _courtStatusFilter == 'all'
        ? title
        : title.replaceFirst(RegExp(r'\(\d+\s*สนาม\)'), '(${filteredEntries.length}/${courtList.length} สนาม)');
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              countLabel,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 12),
            if (filteredEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('ไม่พบสนามตามตัวกรอง', style: TextStyle(color: Colors.grey[600])),
              )
            else
              ...filteredEntries.map((entry) => _buildCourtItem(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildCourtItem(String courtId, Map<String, dynamic> court) {
    final isAvailable = court['isAvailable'] ?? true;
    final isActivityOnly = court['isActivityOnly'] ?? false;
    final courtName = court['name'] ?? 'ไม่ระบุชื่อ';

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isAvailable ? Colors.green : Colors.red,
          child: Icon(
            _getCourtIcon(court['category']),
            color: Colors.white,
          ),
        ),
        title: Text(
          courtName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isAvailable ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ประเภท: ${_getTypeText(court['type'] ?? '')} | หมวด: ${_getCategoryText(court['category'] ?? '')} | สนามที่: ${court['number'] ?? 0}'),
            Text('เวลาเปิดจอง: ${court['openBookingTime'] ?? 'ไม่ระบุ'} | เล่นได้: ${court['playStartTime'] ?? 'ไม่ระบุ'}-${court['playEndTime'] ?? 'ไม่ระบุ'}'),
            Text('👥 จำนวนคนในการจอง: ${court['requiredPlayers'] ?? _getDefaultRequiredPlayers(court['category'] ?? 'tennis')} คน'),
            if (court['location'] != null && court['location'] is Map)
              Text('ตำแหน่ง: ${(court['location']['latitude'] as double?)?.toStringAsFixed(6) ?? 'ไม่ระบุ'}, ${(court['location']['longitude'] as double?)?.toStringAsFixed(6) ?? 'ไม่ระบุ'}'),
            if (isActivityOnly)
              Text('🏆 สำหรับกิจกรรมเท่านั้น', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
            if (!isAvailable)
              Text('⛔ ปิดการใช้งาน', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _fillFormWithCourtData(courtId, court);
                _tabController.animateTo(1);
                break;
              case 'toggle':
                _toggleCourtAvailability(courtId, isAvailable);
                break;
              case 'delete':
                _deleteCourt(courtId, court['name'] ?? 'ไม่ระบุชื่อ');
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('แก้ไข'))),
            PopupMenuItem(
              value: 'toggle',
              child: ListTile(
                leading: Icon(isAvailable ? Icons.visibility_off : Icons.visibility),
                title: Text(isAvailable ? 'ปิดการใช้งาน' : 'เปิดการใช้งาน'),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('ลบ')),
            ),
          ],
        ),
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ข้อมูลรายละเอียด
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'รายละเอียดเพิ่มเติม',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('📍 ที่อยู่: ${court['address'] ?? 'ไม่ระบุ'}'),
                      Text('📝 คำอธิบาย: ${court['description'] ?? 'ไม่ระบุ'}'),
                      Text('🕐 สร้างเมื่อ: ${_formatDateTime(court['createdAt'])}'),
                      Text('🔄 อัปเดตเมื่อ: ${_formatDateTime(court['updatedAt'])}'),
                      if (court['location'] != null && court['location'] is Map) ...[
                        SizedBox(height: 8),
                        Text('🗺️ พิกัด:'),
                        Text('  Lat: ${(court['location']['latitude'] as double?)?.toStringAsFixed(6) ?? 'ไม่ระบุ'}'),
                        Text('  Lng: ${(court['location']['longitude'] as double?)?.toStringAsFixed(6) ?? 'ไม่ระบุ'}'),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 16),
                // QR Code Section
                Expanded(
                  flex: 1,
                  child: SimpleCourtQRWidget(
                    courtName: courtName,
                    courtId: courtId,
                    size: 150,
                    showControls: true,
                    isPreview: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCourtIcon(String? category) {
    switch (category) {
      case 'tennis': return Icons.sports_tennis;
      case 'basketball': return Icons.sports_basketball;
      case 'badminton': return Icons.sports_tennis;
      case 'futsal': return Icons.sports_soccer;
      case 'football': return Icons.sports_soccer;
      case 'volleyball': return Icons.sports_volleyball;
      case 'takraw': return Icons.sports_tennis;
      case 'table_tennis': return Icons.table_restaurant;
      case 'multipurpose': return Icons.sports;
      default: return Icons.sports;
    }
  }

  String _getTypeText(String? type) {
    switch (type) {
      case 'outdoor': return 'กลางแจ้ง';
      case 'indoor': return 'ในร่ม';
      default: return type ?? 'ไม่ระบุ';
    }
  }

  String _getCategoryText(String? category) {
    switch (category) {
      case 'tennis': return 'เทนนิส';
      case 'basketball': return 'บาสเกตบอล';
      case 'badminton': return 'แบดมินตัน';
      case 'futsal': return 'ฟุตซอล';
      case 'football': return 'ฟุตบอล';
      case 'volleyball': return 'วอลเลย์บอล';
      case 'takraw': return 'ตะกร้อ';
      case 'table_tennis': return 'เทเบิลเทนนิส';
      case 'multipurpose': return 'อเนกประสงค์';
      default: return category ?? 'ไม่ระบุ';
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'ไม่ระบุ';
    
    try {
      DateTime dt;
      if (dateTime is String) {
        dt = DateTime.parse(dateTime);
      } else if (dateTime is DateTime) {
        dt = dateTime;
      } else {
        return 'ไม่ระบุ';
      }
      
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'ไม่ระบุ';
    }
  }

  Widget _buildCourtForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_editingCourtId != null)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'กำลังแก้ไขสนาม: ${_editingCourtId != null && courts.containsKey(_editingCourtId) ? (courts[_editingCourtId]?['name']?.toString() ?? 'ไม่ระบุชื่อ') : 'ไม่ระบุชื่อ'}',
                      style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearForm,
                    child: Text('ยกเลิก'),
                  ),
                ],
              ),
            ),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ข้อมูลพื้นฐาน',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'ชื่อสนาม *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.sports),
                          ),
                          onChanged: (value) => setState(() {}), // อัปเดต QR Preview
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Text(
                              'ตัวอย่าง QR Code',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            QRPreviewWidget(
                              courtName: _nameController.text,
                              size: 120,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: InputDecoration(
                            labelText: 'ประเภทสนาม *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          items: [
                            DropdownMenuItem(value: 'outdoor', child: Text('กลางแจ้ง')),
                            DropdownMenuItem(value: 'indoor', child: Text('ในร่ม')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value!;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'หมวดหมู่ *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: [
                            DropdownMenuItem(value: 'tennis', child: Text('เทนนิส')),
                            DropdownMenuItem(value: 'basketball', child: Text('บาสเกตบอล')),
                            DropdownMenuItem(value: 'badminton', child: Text('แบดมินตัน')),
                            DropdownMenuItem(value: 'futsal', child: Text('ฟุตซอล')),
                            DropdownMenuItem(value: 'football', child: Text('ฟุตบอล')),
                            DropdownMenuItem(value: 'volleyball', child: Text('วอลเลย์บอล')),
                            DropdownMenuItem(value: 'takraw', child: Text('ตะกร้อ')),
                            DropdownMenuItem(value: 'table_tennis', child: Text('เทเบิลเทนนิส')),
                            DropdownMenuItem(value: 'multipurpose', child: Text('อเนกประสงค์')),
                            DropdownMenuItem(value: 'other', child: Text('อื่นๆ (ระบุเอง)')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value!;
                              // อัปเดตค่าเริ่มต้นจำนวนคนเมื่อเปลี่ยนหมวดหมู่
                              if (_requiredPlayersController.text.isEmpty) {
                                _requiredPlayersController.text = _getDefaultRequiredPlayers(value).toString();
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  // Custom category input when selecting 'other'
                  if (_selectedCategory == 'other') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customCategoryController,
                      decoration: const InputDecoration(
                        labelText: 'ระบุหมวดหมู่เอง',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit),
                        helperText: 'ตัวอย่าง: pickleball, petanque, …',
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _numberController,
                          decoration: InputDecoration(
                            labelText: 'หมายเลขสนาม *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _requiredPlayersController,
                          decoration: InputDecoration(
                            labelText: 'จำนวนคนในการจอง',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.people),
                            hintText: 'ค่าเริ่มต้น: ${_getDefaultRequiredPlayers(_selectedCategory)} คน',
                            helperText: 'หากไม่ระบุ จะใช้ค่าเริ่มต้นตามประเภทสนาม',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('สำหรับกิจกรรมเท่านั้น'),
                    subtitle: Text('หากเปิดใช้งาน สนามนี้จะใช้สำหรับจองกิจกรรมเท่านั้น'),
                    value: _isActivityOnly,
                    onChanged: (value) {
                      setState(() {
                        _isActivityOnly = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text('เปิดใช้งาน'),
                    subtitle: Text('สถานะการเปิด/ปิดการใช้งานสนาม'),
                    value: _isAvailable,
                    onChanged: (value) {
                      setState(() {
                        _isAvailable = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เวลาการใช้งาน',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _openBookingTimeController,
                    decoration: InputDecoration(
                      labelText: 'เวลาเปิดรับจอง (HH:MM) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                      hintText: 'เช่น 09:00',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.schedule),
                        onPressed: () => _selectTime(context, _openBookingTimeController, 'เวลาเปิดรับจอง'),
                      ),
                    ),
                    readOnly: false,
                  ),
                  SizedBox(height: 8),
                  Text('เลือกเวลาด่วน:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  SizedBox(height: 4),
                  _buildQuickTimeButtons(_openBookingTimeController),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _playStartTimeController,
                              decoration: InputDecoration(
                                labelText: 'เวลาเริ่มเล่น (HH:MM) *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.play_arrow),
                                hintText: 'เช่น 17:00',
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.schedule),
                                  onPressed: () => _selectTime(context, _playStartTimeController, 'เวลาเริ่มเล่น'),
                                ),
                              ),
                              readOnly: false,
                            ),
                            SizedBox(height: 4),
                            _buildQuickTimeButtons(_playStartTimeController),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _playEndTimeController,
                              decoration: InputDecoration(
                                labelText: 'เวลาปิดสนาม (HH:MM) *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.stop),
                                hintText: 'เช่น 22:00',
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.schedule),
                                  onPressed: () => _selectTime(context, _playEndTimeController, 'เวลาปิดสนาม'),
                                ),
                              ),
                              readOnly: false,
                            ),
                            SizedBox(height: 4),
                            _buildQuickTimeButtons(_playEndTimeController),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ตำแหน่งและที่อยู่',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latitudeController,
                          decoration: InputDecoration(
                            labelText: 'ละติจูด (Latitude)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.map),
                            hintText: 'เช่น 13.8199',
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _longitudeController,
                          decoration: InputDecoration(
                            labelText: 'ลองจิจูด (Longitude)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.map),
                            hintText: 'เช่น 100.0438',
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // ปุ่มเลือกตำแหน่งจากแผนที่
                  ElevatedButton.icon(
                    onPressed: _selectLocationFromMap,
                    icon: Icon(Icons.map, color: Colors.white),
                    label: Text(
                      'เลือกตำแหน่งจากแผนที่',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  // แสดงแผนที่ตัวอย่างถ้ามีตำแหน่ง
                  if (_latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 12),
                      child: MapLocationViewer(
                        location: LatLng(
                          double.parse(_latitudeController.text),
                          double.parse(_longitudeController.text),
                        ),
                        title: 'ตำแหน่งสนาม',
                        height: 200,
                      ),
                    ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'ที่อยู่',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'คำอธิบายเพิ่มเติม',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _editingCourtId != null ? _updateCourt : _addCourt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _editingCourtId != null ? 'แก้ไขสนาม' : 'เพิ่มสนาม',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearForm,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('ล้างข้อมูล', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}