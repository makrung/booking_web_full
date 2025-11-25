import 'package:flutter/material.dart';
import 'NewAdvancedBookingPage.dart';
import 'ActivityBookingFormPage.dart';
import 'services/court_management_service_new.dart';
import 'services/content_service.dart';
import 'services/auth_service.dart';

class BookingSelectionPage extends StatefulWidget {
  @override
  State<BookingSelectionPage> createState() => _BookingSelectionPageState();
}

class _BookingSelectionPageState extends State<BookingSelectionPage> {
  bool _loadingCounts = true;
  String? _error;
  int _outdoorCount = 0;
  int _indoorCount = 0;
  Map<String, int> _categoryCounts = {};
  String? _regularDesc;
  String? _regularFootnotes; // optional future use
  String? _activityDesc;
  List<String> _regularFeatures = [];
  List<String> _activityFeatures = [];
  bool _blockedByDomainPolicy = false;
  Map<String, dynamic>? _me;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _loadEditableDescriptions();
    _loadDomainPolicy();
  }

  Future<void> _loadEditableDescriptions() async {
    try {
      final reg = await ContentService.getContent('booking_regular_description');
      final act = await ContentService.getContent('booking_activity_description');
      final regFeat = await ContentService.getContent('booking_regular_features');
      final actFeat = await ContentService.getContent('booking_activity_features');
      if (mounted) setState(() {
        _regularDesc = reg;
        _activityDesc = act;
        _regularFeatures = (regFeat ?? '')
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        _activityFeatures = (actFeat ?? '')
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _loadCounts() async {
    setState(() { _loadingCounts = true; _error = null; });
    try {
      final result = await CourtManagementService.getAllCourts();
      final courtsMap = (result['courts'] ?? {}) as Map<String, dynamic>;
      int outdoor = 0, indoor = 0; final Map<String, int> cat = {};
      courtsMap.forEach((id, data) {
        final type = (data['type'] ?? '').toString();
        final category = (data['category'] ?? '').toString();
        if (type == 'outdoor') outdoor++; else if (type == 'indoor') indoor++;
        cat[category] = (cat[category] ?? 0) + 1;
      });
      setState(() { _outdoorCount = outdoor; _indoorCount = indoor; _categoryCounts = cat; });
    } catch (e) {
      setState(() { _error = 'โหลดข้อมูลสนามล้มเหลว'; });
    } finally {
      setState(() { _loadingCounts = false; });
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
      final allowVal = (meta['value'] ?? '1').toString().toLowerCase();
      final allow = allowVal == '1' || allowVal == 'true';
      final isAdmin = (me?['role'] ?? '') == 'admin';
      final email = (me?['email'] ?? '').toString();
      final isUni = email.isNotEmpty && _isUniversityEmail(email);
      if (mounted) {
        setState(() {
          _me = me;
          _blockedByDomainPolicy = !allow && !isAdmin && !isUni;
        });
      }
    } catch (_) {
      // Fail open (do not block) if cannot determine
      if (mounted) setState(() { _blockedByDomainPolicy = false; });
    }
  }

  Future<void> _handleBookingTap(VoidCallback proceed) async {
    if (_blockedByDomainPolicy) {
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
            'ขณะนี้ระบบจำกัดการจองเฉพาะผู้ใช้อีเมลของมหาวิทยาลัยเท่านั้น\n'
            'ผู้ใช้ที่ไม่ใช่อีเมลของทางมหาวิทยาลัยไม่สามารถทำการจองได้ชั่วคราว',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
          ],
        ),
      );
      return;
    }
    proceed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F8FF),
      appBar: AppBar(
        backgroundColor: Colors.teal[700],
        title: Text(
          'เลือกวิธีการจอง',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_blockedByDomainPolicy)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
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
              'เลือกวิธีการจองที่เหมาะกับคุณ',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'ระบบใหม่มีหลายตัวเลือกให้เหมาะกับการใช้งาน',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 30),
            
            // ตัวเลือก 1: การจองปกติ
            _buildBookingOption(
              context: context,
              title: 'การจองใช้งานทั่วไป',
              subtitle: 'จองสนามเพื่อเล่นกีฬาส่วนตัว',
              description: (_regularDesc ?? '').trim().isNotEmpty
                  ? _regularDesc!.trim()
                  : 'เหมาะสำหรับการเล่นกีฬาประจำวัน ต้องแสกน QR Code และยืนยันตำแหน่ง',
              icon: Icons.sports_tennis,
              color: Colors.blue,
              features: _regularFeatures.isNotEmpty
                  ? _regularFeatures
                  : [
                      'จองได้เฉพาะในวันเดียวเท่านั้น',
                      'เปิดรับจองตั้งแต่ 09:00-22:00 น.',
                      'ต้องแสกน QR Code ที่สนาม',
                      'ต้องยืนยันตำแหน่งที่ตั้ง',
                      'จำกัด 1 สนามต่อประเภทต่อวัน',
                    ],
              onTap: () {
                _handleBookingTap(() {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewAdvancedBookingPage(
                        initialBookingType: 'regular',
                      ),
                    ),
                  );
                });
              },
            ),
            
            SizedBox(height: 20),
            
            // ตัวเลือก 2: การจองกิจกรรม
            _buildBookingOption(
              context: context,
              title: 'การจองสำหรับกิจกรรม',
              subtitle: 'ขออนุญาตจัดกิจกรรมพิเศษ',
              description: (_activityDesc ?? '').trim().isNotEmpty
                  ? _activityDesc!.trim()
                  : 'เหมาะสำหรับการจัดการแข่งขัน อบรม หรือกิจกรรมขนาดใหญ่',
              icon: Icons.event,
              color: Colors.green,
              features: _activityFeatures.isNotEmpty
                  ? _activityFeatures
                  : [
                      'จองล่วงหน้าได้ 1-2 เดือน',
                      'ไม่ต้องแสกน QR Code',
                      'ต้องมีเอกสารอนุญาตจากหน่วยงาน',
                      'จองได้ทั้งวัน (ไม่จำกัดเวลา)',
                      'รออนุมัติจากเจ้าหน้าที่',
                    ],
              onTap: () {
                _handleBookingTap(() {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ActivityBookingFormPage(),
                    ),
                  );
                });
              },
            ),
            
            SizedBox(height: 30),
            
            // ข้อมูลสนามทั้งหมด
            _buildCourtsInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> features,
    VoidCallback? onTap,
    bool isComingSoon = false,
  }) {
    return GestureDetector(
      onTap: isComingSoon ? null : onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isComingSoon)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'เร็วๆ นี้',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16),
              ...features.map((feature) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: color, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isComingSoon ? null : onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isComingSoon ? Colors.grey : color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isComingSoon ? 'เร็วๆ นี้' : 'เลือกการจองนี้',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourtsInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ข้อมูลสนามทั้งหมด',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.teal[700],
            ),
          ),
          SizedBox(height: 16),
          if (_loadingCounts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  TextButton(onPressed: _loadCounts, child: const Text('ลองใหม่')),
                ],
              ),
            )
          else ...[
            _buildCourtTypeSection(
              'สนามกลางแจ้ง (${_outdoorCount} สนาม)',
              _buildCategoryList(['tennis','basketball','futsal','multi','takraw','football']),
              Icons.wb_sunny,
              Colors.green,
            ),
            SizedBox(height: 20),
            _buildCourtTypeSection(
              'สนามในร่ม (${_indoorCount} สนาม)',
              _buildCategoryList(['badminton','basketball','volleyball']),
              Icons.home,
              Colors.purple,
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildCategoryList(List<String> keys) {
    IconData iconFor(String key) {
      switch (key) {
        case 'tennis': return Icons.sports_tennis;
        case 'basketball': return Icons.sports_basketball;
        case 'futsal': return Icons.sports_soccer;
        case 'multi': return Icons.sports_handball;
        case 'takraw': return Icons.sports_volleyball;
        case 'football': return Icons.sports_soccer;
        case 'badminton': return Icons.sports_tennis;
        case 'volleyball': return Icons.sports_volleyball;
        default: return Icons.sports;
      }
    }
    String thaiName(String key) {
      switch (key) {
        case 'tennis': return 'เทนนิส';
        case 'basketball': return 'บาสเกตบอล';
        case 'futsal': return 'ฟุตซอล';
        case 'multi': return 'ลานอเนกประสงค์';
        case 'takraw': return 'ตะกร้อ';
        case 'football': return 'ฟุตบอล';
        case 'badminton': return 'แบดมินตัน';
        case 'volleyball': return 'วอลเลย์บอล';
        default: return key;
      }
    }
    return keys.map((k) => {
      'name': thaiName(k),
      'count': _categoryCounts[k] ?? 0,
      'icon': iconFor(k),
      'note': k == 'multi' ? '(เฉพาะกิจกรรม)' : '',
    }).toList();
  }

  Widget _buildCourtTypeSection(String title, List<Map<String, dynamic>> courts, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...courts.map((court) => Padding(
          padding: EdgeInsets.only(left: 32, bottom: 8),
          child: Row(
            children: [
              Icon(court['icon'], color: Colors.grey[600], size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${court['name']} (${court['count']} สนาม)${court['note'] ?? ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }
}
