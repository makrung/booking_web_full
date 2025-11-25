import 'package:flutter/material.dart';
import 'services/settings_service.dart';
import 'services/location_service.dart';
import 'services/auth_service.dart';
import 'services/content_service.dart';
import 'Login.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class AdminSettingsPage extends StatefulWidget {
  @override
  _AdminSettingsPageState createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  bool isLocationTestEnabled = false;
  bool isAdminBookingEnabled = true; // Always enabled by role now
  bool isTestModeEnabled = false; // โหมดทดสอบสำหรับทุกคน
  bool isLoading = true;

  // Admin-editable content fields
  final TextEditingController _dailyLegendCtl = TextEditingController();
  final TextEditingController _monthlyLegendCtl = TextEditingController();
  final TextEditingController _contactInfoCtl = TextEditingController();
  // Booking selection descriptions
  final TextEditingController _bookingRegularCtl = TextEditingController();
  final TextEditingController _bookingActivityCtl = TextEditingController();
  final TextEditingController _bookingRegularFeaturesCtl = TextEditingController();
  final TextEditingController _bookingActivityFeaturesCtl = TextEditingController();
  final TextEditingController _bookingRulesCtl = TextEditingController();
  // Rich-text controller for Booking Rules (Quill)
  late quill.QuillController _rulesQuillController;
  int _rulesFontSize = 16;
  // System numeric settings
  final TextEditingController _penaltyRegularCtl = TextEditingController();
  final TextEditingController _courtRadiusCtl = TextEditingController();
  // removed activity penalty editor per requirement
  final TextEditingController _resetBoundaryHourCtl = TextEditingController();
  final TextEditingController _dailyRightsCtl = TextEditingController();
  final TextEditingController _bonusCompletedCtl = TextEditingController();
  final TextEditingController _cancelFreeHoursCtl = TextEditingController();
  final TextEditingController _penaltyLateCancelCtl = TextEditingController();
  final TextEditingController _checkinGraceMinutesCtl = TextEditingController();
  bool _requireQR = true;
  bool _requireLocation = true;
  bool _allowNonUniBooking = true;
  bool _allowNonUniRegistration = true;
  bool _contentLoading = true;
  // Current values for comparison and restore
  String _dailyLegendCurrent = '';
  String _monthlyLegendCurrent = '';
  String _contactInfoCurrent = '';
  String _bookingRegularCurrent = '';
  String _bookingActivityCurrent = '';
  String _bookingRegularFeaturesCurrent = '';
  String _bookingActivityFeaturesCurrent = '';
  String _bookingRulesCurrent = '';
  String _bookingRulesRawExisting = '';
  String? _dailyLegendUpdatedAt;
  String? _monthlyLegendUpdatedAt;
  String? _contactInfoUpdatedAt;
  String? _bookingRegularUpdatedAt;
  String? _bookingActivityUpdatedAt;
  String? _bookingRegularFeaturesUpdatedAt;
  String? _bookingActivityFeaturesUpdatedAt;
  String? _bookingRulesUpdatedAt;
  String? _penaltyRegularUpdatedAt;
  String? _courtRadiusUpdatedAt;
  String? _resetBoundaryHourUpdatedAt;
  String? _dailyRightsUpdatedAt;
  String? _bonusCompletedUpdatedAt;
  String? _cancelFreeHoursUpdatedAt;
  String? _allowNonUniBookingUpdatedAt;
  String? _allowNonUniRegistrationUpdatedAt;

  @override
  void initState() {
    super.initState();
  _rulesQuillController = quill.QuillController.basic();
    _loadSettings();
    _loadEditableContent();
  }

  @override
  void dispose() {
    try { _rulesQuillController.dispose(); } catch (_) {}
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
  // Admin booking mode toggle removed; admins always have privileges
      final globalTestMode = await SettingsService.isTestModeEnabled();
      setState(() {
  isAdminBookingEnabled = true;
        isTestModeEnabled = globalTestMode;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('เกิดข้อผิดพลาดในการโหลดการตั้งค่า: $e');
    }
  }

  Future<void> _loadEditableContent() async {
    try {
      setState(() { _contentLoading = true; });
      final daily = await ContentService.getContentWithMeta('daily_legend_text');
      final monthly = await ContentService.getContentWithMeta('monthly_legend_text');
      final contact = await ContentService.getContentWithMeta('contact_info_text');
      final regDesc = await ContentService.getContentWithMeta('booking_regular_description');
      final actDesc = await ContentService.getContentWithMeta('booking_activity_description');
  final regFeat = await ContentService.getContentWithMeta('booking_regular_features');
  final actFeat = await ContentService.getContentWithMeta('booking_activity_features');
  final rules = await ContentService.getContentWithMeta('booking_rules_content');
  final penaltyReg = await ContentService.getContentWithMeta('penalty_no_checkin_auto_cancel');
  final resetHour = await ContentService.getContentWithMeta('reset_boundary_hour');
  final dailyRights = await ContentService.getContentWithMeta('daily_rights_per_user');
  final bonusCompleted = await ContentService.getContentWithMeta('bonus_completed_booking');
  final cancelFree = await ContentService.getContentWithMeta('cancel_free_hours');
  final penaltyLateCancel = await ContentService.getContentWithMeta('penalty_late_cancel');
  final checkinGrace = await ContentService.getContentWithMeta('checkin_grace_minutes');
  final requireQR = await ContentService.getContentWithMeta('require_qr_verification');
  final requireLoc = await ContentService.getContentWithMeta('require_location_verification');
  final allowNonUniBooking = await ContentService.getContentWithMeta('allow_non_university_booking');
  final allowNonUniRegistration = await ContentService.getContentWithMeta('allow_non_university_registration');
    _dailyLegendCurrent = (daily['value'] ?? '')?.toString() ?? '';
    _monthlyLegendCurrent = (monthly['value'] ?? '')?.toString() ?? '';
    _contactInfoCurrent = (contact['value'] ?? '')?.toString() ?? '';
    // Prefill with effective values: if backend is empty, use sensible defaults so inputs are not blank
    final regDescVal = ((regDesc['value'] ?? '')?.toString() ?? '').trim();
    final actDescVal = ((actDesc['value'] ?? '')?.toString() ?? '').trim();
    _bookingRegularCurrent = regDescVal.isEmpty ? _defaultBookingRegularTemplate() : regDescVal;
    _bookingActivityCurrent = actDescVal.isEmpty ? _defaultBookingActivityTemplate() : actDescVal;
  final regFeatVal = ((regFeat['value'] ?? '')?.toString() ?? '').trim();
  final actFeatVal = ((actFeat['value'] ?? '')?.toString() ?? '').trim();
  _bookingRegularFeaturesCurrent = regFeatVal.isEmpty ? _defaultBookingRegularFeaturesTemplate() : regFeatVal;
  _bookingActivityFeaturesCurrent = actFeatVal.isEmpty ? _defaultBookingActivityFeaturesTemplate() : actFeatVal;
  // Rules page content: if empty, show a helpful default template so admin sees actual effective text
  final rulesVal = ((rules['value'] ?? '')?.toString() ?? '').trim();
  _bookingRulesRawExisting = rulesVal;
  // If current content is empty or looks too short, prefill with detailed default
  if (rulesVal.isEmpty || rulesVal.length < 500) {
    _bookingRulesCurrent = _defaultBookingRulesTemplate();
  } else {
    _bookingRulesCurrent = rulesVal;
  }
  // Initialize rich editor with current content (strip HTML to plain for editing baseline)
  final initialPlain = _htmlToPlainText(_bookingRulesCurrent);
  try {
    _rulesQuillController = quill.QuillController(
      document: quill.Document()..insert(0, initialPlain),
      selection: const TextSelection.collapsed(offset: 0),
    );
  } catch (_) {
    _rulesQuillController = quill.QuillController.basic();
  }
  final penaltyRegVal = (penaltyReg['value'] ?? 50).toString();
  final resetHourVal = (resetHour['value'] ?? 6).toString();
  final dailyRightsVal = (dailyRights['value'] ?? 1).toString();
  final bonusCompletedVal = (bonusCompleted['value'] ?? 5).toString();
  final cancelFreeVal = (cancelFree['value'] ?? 1).toString();
  final penaltyLateCancelVal = (penaltyLateCancel['value'] ?? 0).toString();
  final checkinGraceVal = (checkinGrace['value'] ?? 15).toString();
  final courtRadiusVal = (await ContentService.getContentWithMeta('court_verification_radius_meters'))['value']?.toString() ?? '60';
    _dailyLegendCtl.text = _dailyLegendCurrent;
    _monthlyLegendCtl.text = _monthlyLegendCurrent;
    _contactInfoCtl.text = _contactInfoCurrent;
    _bookingRegularCtl.text = _bookingRegularCurrent;
    _bookingActivityCtl.text = _bookingActivityCurrent;
  _bookingRegularFeaturesCtl.text = _bookingRegularFeaturesCurrent;
  _bookingActivityFeaturesCtl.text = _bookingActivityFeaturesCurrent;
  _bookingRulesCtl.text = _bookingRulesCurrent;
  _penaltyRegularCtl.text = penaltyRegVal;
  _courtRadiusCtl.text = courtRadiusVal;
  _resetBoundaryHourCtl.text = resetHourVal;
  _dailyRightsCtl.text = dailyRightsVal;
  _bonusCompletedCtl.text = bonusCompletedVal;
  _cancelFreeHoursCtl.text = cancelFreeVal;
  _penaltyLateCancelCtl.text = penaltyLateCancelVal;
  _checkinGraceMinutesCtl.text = checkinGraceVal;
  
  // Parse boolean settings from backend
  print('🔧 Loading settings from backend:');
  print('   require_qr_verification: ${requireQR['value']}');
  print('   require_location_verification: ${requireLoc['value']}');
  
  final parsedRequireQR = ((requireQR['value'] ?? '1').toString() == '1' || 
                           (requireQR['value'] ?? 'true').toString().toLowerCase() == 'true');
  final parsedRequireLocation = ((requireLoc['value'] ?? '1').toString() == '1' || 
                                 (requireLoc['value'] ?? 'true').toString().toLowerCase() == 'true');
  final parsedAllowNonUniBooking = ((allowNonUniBooking['value'] ?? '1').toString() == '1' || 
                                    (allowNonUniBooking['value'] ?? 'true').toString().toLowerCase() == 'true');
  final parsedAllowNonUniRegistration = ((allowNonUniRegistration['value'] ?? '1').toString() == '1' || 
                                         (allowNonUniRegistration['value'] ?? 'true').toString().toLowerCase() == 'true');
  
  print('   Parsed QR: $parsedRequireQR');
  print('   Parsed Location: $parsedRequireLocation');
  
    _dailyLegendUpdatedAt = _formatUpdatedAt(daily['updatedAt']);
    _monthlyLegendUpdatedAt = _formatUpdatedAt(monthly['updatedAt']);
    _contactInfoUpdatedAt = _formatUpdatedAt(contact['updatedAt']);
    _bookingRegularUpdatedAt = _formatUpdatedAt(regDesc['updatedAt']);
    _bookingActivityUpdatedAt = _formatUpdatedAt(actDesc['updatedAt']);
  _bookingRegularFeaturesUpdatedAt = _formatUpdatedAt(regFeat['updatedAt']);
  _bookingActivityFeaturesUpdatedAt = _formatUpdatedAt(actFeat['updatedAt']);
  _bookingRulesUpdatedAt = _formatUpdatedAt(rules['updatedAt']);
  _penaltyRegularUpdatedAt = _formatUpdatedAt(penaltyReg['updatedAt']);
  _courtRadiusUpdatedAt = _formatUpdatedAt(((await ContentService.getContentWithMeta('court_verification_radius_meters'))['updatedAt']));
  _resetBoundaryHourUpdatedAt = _formatUpdatedAt(resetHour['updatedAt']);
  _dailyRightsUpdatedAt = _formatUpdatedAt(dailyRights['updatedAt']);
  _bonusCompletedUpdatedAt = _formatUpdatedAt(bonusCompleted['updatedAt']);
  _cancelFreeHoursUpdatedAt = _formatUpdatedAt(cancelFree['updatedAt']);
  _allowNonUniBookingUpdatedAt = _formatUpdatedAt(allowNonUniBooking['updatedAt']);
  _allowNonUniRegistrationUpdatedAt = _formatUpdatedAt(allowNonUniRegistration['updatedAt']);
  
      // Apply parsed boolean values to state
      setState(() {
        _requireQR = parsedRequireQR;
        _requireLocation = parsedRequireLocation;
        _allowNonUniBooking = parsedAllowNonUniBooking;
        _allowNonUniRegistration = parsedAllowNonUniRegistration;
      });
    } catch (e) {
      print('Error loading editable content: $e');
      // ignore; shown in UI when saving if needed
    } finally {
      if (mounted) setState(() { _contentLoading = false; });
    }
  }

  Future<void> _saveContent(String key, TextEditingController ctl) async {
    final ok = await ContentService.setContent(key, ctl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'บันทึกสำเร็จ' : 'บันทึกไม่สำเร็จ'),
        backgroundColor: ok ? Colors.teal : Colors.red,
      ),
    );
    if (ok) {
      // Refresh current values and metadata
      await _loadEditableContent();
    }
  }

  // Save Booking Rules from Quill editor as basic HTML
  Future<void> _saveRulesRich() async {
    final delta = _rulesQuillController.document.toDelta();
    final html = _quillDeltaToBasicHtml(delta);
    final ok = await ContentService.setContent('booking_rules_content', html);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'บันทึกกฎการจองสำเร็จ' : 'บันทึกกฎการจองไม่สำเร็จ'),
        backgroundColor: ok ? Colors.teal : Colors.red,
      ),
    );
    if (ok) await _loadEditableContent();
  }

  // Minimal Quill Delta -> HTML (bold/italic/underline + line breaks)
  String _quillDeltaToBasicHtml(dynamic delta) {
    final buffer = StringBuffer();
    final List ops = (delta.toJson() as List);
    for (final op in ops) {
      final data = op['insert'];
      final attrs = op['attributes'] ?? {};
      if (data is String) {
        String text = data
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        if ((attrs['bold'] ?? false) == true) text = '<b>$text</b>';
        if ((attrs['italic'] ?? false) == true) text = '<i>$text</i>';
        if ((attrs['underline'] ?? false) == true) text = '<u>$text</u>';
        // Replace all newlines inside text with <br/>
        text = text.replaceAll('\n', '<br/>');
        buffer.write(text);
      }
    }
    return buffer.toString();
  }

  // Simple HTML to plain text for initializing the editor
  String _htmlToPlainText(String html) {
    if (html.trim().isEmpty) return '';
  var s = html
    // line breaks
    .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
    // paragraphs/headings end -> double newline for spacing
    .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n\n')
    .replaceAll(RegExp(r'</\s*h[1-6]\s*>', caseSensitive: false), '\n\n')
    // list items
    .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '• ')
    .replaceAll(RegExp(r'</\s*li\s*>', caseSensitive: false), '\n')
    // strip remaining tags
    .replaceAll(RegExp(r'<[^>]+>'), '');
    s = s.replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>');
    // normalize multiple newlines/spaces
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  Widget _buildNumberSetting({
    required String label,
    required TextEditingController controller,
    required String settingKey,
    String? hint,
    String? updatedAt,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: hint ?? '',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _saveContent(settingKey, controller),
              icon: const Icon(Icons.save),
              label: const Text('บันทึก'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[600], foregroundColor: Colors.white),
            ),
          ],
        ),
        if ((updatedAt ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('อัปเดตล่าสุด: $updatedAt', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ],
    );
  }



  // โหมดจอง Admin ไม่ต้องตั้งค่าแล้ว — ใช้สิทธิ์จากบทบาทผู้ใช้โดยตรง

  Future<void> _toggleTestMode(bool value) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Persist to server and local settings explicitly so all clients see the change
      try {
        // Write server-side key so clients reading ContentService.getContent see it
        await ContentService.setContent('test_mode_enabled', value ? '1' : '0');
        // Also set location-specific test mode key used by location services
        await ContentService.setContent('location_test_mode', value ? '1' : '0');
      } catch (e) {
        // best-effort
        print('Error persisting test mode to server: $e');
      }

      // Update local SettingsService and LocationService to keep notifier/state consistent
      try { await SettingsService.setTestMode(value); } catch (_) {}
      try { await LocationService.setTestMode(value); } catch (_) {}
      
      setState(() {
        isTestModeEnabled = value;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value 
              ? 'เปิดโหมดทดสอบแล้ว (ทุกคนจองได้ทุกเวลา/วันที่)'
              : 'ปิดโหมดทดสอบแล้ว (กลับสู่โหมดปกติ)',
          ),
          backgroundColor: value ? Colors.red : Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('เกิดข้อผิดพลาดในการบันทึกการตั้งค่า: $e');
    }
  }



  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการออกจากระบบ'),
        content: Text('คุณต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('ออกจากระบบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthService.logout();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการออกจากระบบ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F8FF),
      appBar: AppBar(
        backgroundColor: Colors.teal[700],
        title: Text(
          'ตั้งค่าระบบ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'การตั้งค่าการจองสนาม',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                  SizedBox(height: 20),




                  SizedBox(height: 16),

                  // System behavior settings
                  // Grouped penalty/bonus settings
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.score, color: Colors.teal[700]),
                              SizedBox(width: 8),
                              Text('คะแนน: ตัด/บวก', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildNumberSetting(
                            label: 'ตัดคะแนนอัตโนมัติเมื่อไม่เช็คอิน (เช่น 50)',
                            controller: _penaltyRegularCtl,
                            settingKey: 'penalty_no_checkin_auto_cancel',
                            hint: 'ค่าแนะนำ: 50',
                            updatedAt: _penaltyRegularUpdatedAt,
                          ),
                          SizedBox(height: 12),
                          _buildNumberSetting(
                            label: 'ระยะยืนยันตำแหน่ง (เมตร)',
                            controller: _courtRadiusCtl,
                            settingKey: 'court_verification_radius_meters',
                            hint: 'เช่น 60',
                            updatedAt: _courtRadiusUpdatedAt,
                          ),
                          SizedBox(height: 12),
                          _buildNumberSetting(
                            label: 'บวกคะแนนเมื่อใช้งานเสร็จ (completed)',
                            controller: _bonusCompletedCtl,
                            settingKey: 'bonus_completed_booking',
                            hint: 'ค่าเริ่มต้น: 5',
                            updatedAt: _bonusCompletedUpdatedAt,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // System numeric settings
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.settings, color: Colors.teal[700]),
                              SizedBox(width: 8),
                              Text('การตั้งค่าระบบ (ตัวเลข)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildNumberSetting(
                            label: 'ชั่วโมงตัดรอบสิทธิ (0-23)',
                            controller: _resetBoundaryHourCtl,
                            settingKey: 'reset_boundary_hour',
                            hint: 'เช่น 6',
                            updatedAt: _resetBoundaryHourUpdatedAt,
                          ),
                          SizedBox(height: 12),
                          _buildNumberSetting(
                            label: 'จำนวนสิทธิการจอง/วัน/คน',
                            controller: _dailyRightsCtl,
                            settingKey: 'daily_rights_per_user',
                            hint: 'เช่น 1',
                            updatedAt: _dailyRightsUpdatedAt,
                          ),
                          SizedBox(height: 12),
                          _buildNumberSetting(
                            label: 'ต้องยกเลิกก่อน (ชั่วโมง) เพื่อไม่ถูกหักคะแนน',
                            controller: _cancelFreeHoursCtl,
                            settingKey: 'cancel_free_hours',
                            hint: 'ค่าเริ่มต้น: 1',
                            updatedAt: _cancelFreeHoursUpdatedAt,
                          ),
                          SizedBox(height: 12),
                          _buildNumberSetting(
                            label: 'คะแนนปรับ (ยกเลิกสาย) - ถ้าตั้งเป็น 0 จะไม่หักคะแนน',
                            controller: _penaltyLateCancelCtl,
                            settingKey: 'penalty_late_cancel',
                            hint: 'ค่าเริ่มต้น: 0 (ไม่หักคะแนน)',
                            updatedAt: null,
                          ),
                          SizedBox(height: 12),
                          _buildNumberSetting(
                            label: 'กรอบเวลาเช็คอินหลังเริ่ม (นาที) ก่อนตัดคะแนน',
                            controller: _checkinGraceMinutesCtl,
                            settingKey: 'checkin_grace_minutes',
                            hint: 'ค่าเริ่มต้น: 15',
                            updatedAt: null,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Verification toggles
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_user, color: Colors.teal[700]),
                              SizedBox(width: 8),
                              Text('ข้อกำหนดยืนยันตัวตน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          SizedBox(height: 8),
                          SwitchListTile(
                            value: _requireQR,
                            onChanged: (v) async {
                              print('🔄 Toggling QR verification: $v');
                              setState(() { _requireQR = v; });
                              final result = await ContentService.setContent('require_qr_verification', v ? '1' : '0');
                              print('   API result: $result');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(result ? '✅ บันทึกสำเร็จ' : '❌ บันทึกไม่สำเร็จ'),
                                    backgroundColor: result ? Colors.green : Colors.red,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            title: Text('ต้องแสกน QR Code'),
                            subtitle: Text('ถ้าปิด: ไม่บังคับ QR ในการเช็คอิน'),
                          ),
                          SwitchListTile(
                            value: _requireLocation,
                            onChanged: (v) async {
                              print('🔄 Toggling Location verification: $v');
                              setState(() { _requireLocation = v; });
                              final result = await ContentService.setContent('require_location_verification', v ? '1' : '0');
                              print('   API result: $result');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(result ? '✅ บันทึกสำเร็จ' : '❌ บันทึกไม่สำเร็จ'),
                                    backgroundColor: result ? Colors.green : Colors.red,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            title: Text('ต้องยืนยันตำแหน่งที่ตั้ง'),
                            subtitle: Text('ถ้าปิด: ไม่ตรวจตำแหน่งในการเช็คอิน'),
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Icon(Icons.alternate_email, color: Colors.teal[700]),
                              SizedBox(width: 8),
                              Text('อีเมลที่ไม่ใช่ของมหาวิทยาลัย', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          SizedBox(height: 8),
                          SwitchListTile(
                            value: _allowNonUniRegistration,
                            onChanged: (v) async {
                              setState(() { _allowNonUniRegistration = v; });
                              await ContentService.setContent('allow_non_university_registration', v ? '1' : '0');
                            },
                            title: Text('อนุญาตให้สมัครด้วยเมลธรรมดา'),
                            subtitle: Text('ถ้าปิด: สมัครได้เฉพาะ @silpakorn.edu และ @su.ac.th'),
                          ),
                          if ((_allowNonUniRegistrationUpdatedAt ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 16, bottom: 8),
                              child: Text('อัปเดตล่าสุด: ${_allowNonUniRegistrationUpdatedAt}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ),
                          SwitchListTile(
                            value: _allowNonUniBooking,
                            onChanged: (v) async {
                              setState(() { _allowNonUniBooking = v; });
                              await ContentService.setContent('allow_non_university_booking', v ? '1' : '0');
                            },
                            title: Text('อนุญาตให้จองด้วยเมลธรรมดา'),
                            subtitle: Text('ถ้าปิด: ผู้ใช้เมลธรรมดาจะไม่สามารถทำการจองได้'),
                          ),
                          if ((_allowNonUniBookingUpdatedAt ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text('อัปเดตล่าสุด: ${_allowNonUniBookingUpdatedAt}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ),
                        ],
                      ),
                    ),
                  ),


                  SizedBox(height: 16),

                  // Test Mode (Global) - สำคัญที่สุด
                  Card(
                    elevation: 3,
                    color: isTestModeEnabled ? Colors.red[50] : Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.science,
                                color: isTestModeEnabled
                                    ? Colors.red
                                    : Colors.grey,
                                size: 28,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'โหมดทดสอบระบบ',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isTestModeEnabled 
                                        ? Colors.red[700] 
                                        : Colors.grey[700],
                                  ),
                                ),
                              ),
                              Switch(
                                value: isTestModeEnabled,
                                onChanged: _toggleTestMode,
                                activeColor: Colors.red,
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isTestModeEnabled 
                                  ? Colors.red[100] 
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'สถานะ: ${isTestModeEnabled ? "เปิดใช้งาน" : "ปิดใช้งาน"}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isTestModeEnabled 
                                        ? Colors.red[700] 
                                        : Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  isTestModeEnabled
                                      ? 'ทุกคน (รวม User) สามารถจองได้ทุกเวลา/วันที่ โดยไม่มีข้อจำกัด'
                                      : 'User จองได้เฉพาะตามเวลาและวันที่ที่กำหนด',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isTestModeEnabled 
                                        ? Colors.red[600] 
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Admin Booking Info (no toggle)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.orange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'สิทธิ์การจองของแอดมิน',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'แอดมินสามารถจองได้ทุกวัน/เวลาในอนาคต โดยไม่ต้องใช้รหัสผู้ใช้, ไม่ต้องสแกน QR หรือเช็คอิน และไม่ต้องยืนยันตำแหน่ง',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // ===== Editable Texts =====
                  Text(
                    'แก้ไขข้อความคำอธิบาย (แอดมิน)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_contentLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ))
                  else ...[
                    _buildEditableCard(
                      title: 'การเลือกการจอง - คำอธิบายแบบทั่วไป',
                      hint: 'ข้อความใต้บัตร "จองใช้งานทั่วไป" ในหน้าการเลือกการจอง',
                      controller: _bookingRegularCtl,
                      currentValue: _bookingRegularCurrent,
                      updatedAt: _bookingRegularUpdatedAt,
                      onSave: () => _saveContent('booking_regular_description', _bookingRegularCtl),
                      onRestore: () { setState(() { _bookingRegularCtl.text = _bookingRegularCurrent; }); },
                      onUseDefault: () { setState(() { _bookingRegularCtl.text = _defaultBookingRegularTemplate(); }); },
                      onCopyCurrent: () { _copyToClipboard(_bookingRegularCurrent); },
                      templates: _bookingRegularTemplates(),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    _buildEditableCard(
                      title: 'การเลือกการจอง - รายการคุณสมบัติ (ทั่วไป)',
                      hint: 'ใส่ทีละบรรทัด เช่น\nจองได้เฉพาะในวันเดียวเท่านั้น\nเปิดรับจองตั้งแต่ 09:00-22:00 น.',
                      controller: _bookingRegularFeaturesCtl,
                      currentValue: _bookingRegularFeaturesCurrent,
                      updatedAt: _bookingRegularFeaturesUpdatedAt,
                      onSave: () => _saveContent('booking_regular_features', _bookingRegularFeaturesCtl),
                      onRestore: () { setState(() { _bookingRegularFeaturesCtl.text = _bookingRegularFeaturesCurrent; }); },
                      onUseDefault: () { setState(() { _bookingRegularFeaturesCtl.text = _defaultBookingRegularFeaturesTemplate(); }); },
                      onCopyCurrent: () { _copyToClipboard(_bookingRegularFeaturesCurrent); },
                      maxLines: 6,
                    ),
                    const SizedBox(height: 12),
                    _buildEditableCard(
                      title: 'การเลือกการจอง - คำอธิบายสำหรับกิจกรรม',
                      hint: 'ข้อความใต้บัตร "จองเพื่อกิจกรรม" ในหน้าการเลือกการจอง',
                      controller: _bookingActivityCtl,
                      currentValue: _bookingActivityCurrent,
                      updatedAt: _bookingActivityUpdatedAt,
                      onSave: () => _saveContent('booking_activity_description', _bookingActivityCtl),
                      onRestore: () { setState(() { _bookingActivityCtl.text = _bookingActivityCurrent; }); },
                      onUseDefault: () { setState(() { _bookingActivityCtl.text = _defaultBookingActivityTemplate(); }); },
                      onCopyCurrent: () { _copyToClipboard(_bookingActivityCurrent); },
                      templates: _bookingActivityTemplates(),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    _buildEditableCard(
                      title: 'การเลือกการจอง - รายการคุณสมบัติ (กิจกรรม)',
                      hint: 'ใส่ทีละบรรทัด เช่น\nจองล่วงหน้าได้ 1-2 เดือน\nไม่ต้องแสกน QR Code',
                      controller: _bookingActivityFeaturesCtl,
                      currentValue: _bookingActivityFeaturesCurrent,
                      updatedAt: _bookingActivityFeaturesUpdatedAt,
                      onSave: () => _saveContent('booking_activity_features', _bookingActivityFeaturesCtl),
                      onRestore: () { setState(() { _bookingActivityFeaturesCtl.text = _bookingActivityFeaturesCurrent; }); },
                      onUseDefault: () { setState(() { _bookingActivityFeaturesCtl.text = _defaultBookingActivityFeaturesTemplate(); }); },
                      onCopyCurrent: () { _copyToClipboard(_bookingActivityFeaturesCurrent); },
                      maxLines: 6,
                    ),
                    const SizedBox(height: 12),
                    // Rich-text editor for Booking Rules
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.rule, color: Colors.teal),
                                const SizedBox(width: 8),
                                const Text('หน้ากฎการจอง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                if (_bookingRulesUpdatedAt != null)
                                  Text('อัปเดตล่าสุด: ${_bookingRulesUpdatedAt!}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Toolbar
                            quill.QuillSimpleToolbar(
                              controller: _rulesQuillController,
                              config: const quill.QuillSimpleToolbarConfig(
                                showAlignmentButtons: false,
                                showHeaderStyle: false,
                                showCodeBlock: false,
                                showInlineCode: false,
                                showSearchButton: false,
                                showDividers: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Font size control
                            Row(
                              children: [
                                const Text('ขนาดตัวอักษร: '),
                                const SizedBox(width: 8),
                                DropdownButton<int>(
                                  value: _rulesFontSize,
                                  items: List.generate(40, (i) => i + 1)
                                      .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() { _rulesFontSize = v ?? _rulesFontSize; });
                                    if (v != null) {
                                      _rulesQuillController.formatSelection(
                                        quill.Attribute.fromKeyValue('size', '$v'),
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.restore),
                                  label: const Text('คัดลอกจากที่ใช้อยู่'),
                                  onPressed: () {
                                    final source = (_bookingRulesRawExisting.trim().isNotEmpty)
                                        ? _bookingRulesRawExisting
                                        : _bookingRulesCurrent;
                                    final plain = _htmlToPlainText(source);
                                    setState(() {
                                      _rulesQuillController = quill.QuillController(
                                        document: quill.Document()..insert(0, plain),
                                        selection: const TextSelection.collapsed(offset: 0),
                                      );
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.playlist_add),
                                  label: const Text('เติมกฎฉบับละเอียด'),
                                  onPressed: () {
                                    final plain = _htmlToPlainText(_defaultBookingRulesTemplate());
                                    setState(() {
                                      _rulesQuillController = quill.QuillController(
                                        document: quill.Document()..insert(0, plain),
                                        selection: const TextSelection.collapsed(offset: 0),
                                      );
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.article),
                                  label: const Text('ใช้ข้อความเริ่มต้น'),
                                  onPressed: () {
                                    final plain = _htmlToPlainText(_defaultBookingRulesTemplate());
                                    setState(() {
                                      _rulesQuillController = quill.QuillController(
                                        document: quill.Document()..insert(0, plain),
                                        selection: const TextSelection.collapsed(offset: 0),
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints: const BoxConstraints(minHeight: 220),
                              padding: const EdgeInsets.all(8),
                              child: quill.QuillEditor.basic(
                                controller: _rulesQuillController,
                                config: const quill.QuillEditorConfig(
                                  padding: EdgeInsets.zero,
                                  autoFocus: false,
                                  expands: false,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.visibility, color: Colors.teal),
                                const SizedBox(width: 8),
                                const Text('ตัวอย่างการแสดงผล', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            AnimatedBuilder(
                              animation: _rulesQuillController,
                              builder: (context, _) {
                                final html = _quillDeltaToBasicHtml(_rulesQuillController.document.toDelta());
                                final show = html.trim().isNotEmpty ? html : '<i>ยังไม่มีเนื้อหา</i>';
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: HtmlWidget(
                                    show,
                                    enableCaching: false,
                                    textStyle: const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.save),
                                label: const Text('บันทึกกฎการจอง'),
                                onPressed: _saveRulesRich,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildEditableCard(
                      title: 'ตารางรายวัน - ข้อความอธิบายใต้สถานะ',
                      hint: 'เพิ่มคำอธิบาย/หมายเหตุด้านล่างตำนานสีและสถานะ เช่น เวลาการเปิดจอง, คำแนะนำการใช้งาน',
                      controller: _dailyLegendCtl,
                      currentValue: _dailyLegendCurrent,
                      updatedAt: _dailyLegendUpdatedAt,
                      onSave: () => _saveContent('daily_legend_text', _dailyLegendCtl),
                      onRestore: () { setState(() { _dailyLegendCtl.text = _dailyLegendCurrent; }); },
                      onUseDefault: () { setState(() { _dailyLegendCtl.text = _defaultDailyLegendTemplate(); }); },
                      onCopyCurrent: () { _copyToClipboard(_dailyLegendCurrent); },
                      templates: _dailyLegendTemplates(),
                    ),
                    const SizedBox(height: 12),
                    _buildEditableCard(
                      title: 'ตารางรายเดือน - ข้อความกำกับ',
                      hint: 'ตัวอย่าง: แสดงจุดสีแดงในวันที่เปิดจอง เวลาเปิดจองทั่วไป 09:00 และ เทนนิส/แบด 12:00',
                      controller: _monthlyLegendCtl,
                      currentValue: _monthlyLegendCurrent,
                      updatedAt: _monthlyLegendUpdatedAt,
                      onSave: () => _saveContent('monthly_legend_text', _monthlyLegendCtl),
                      onRestore: () { setState(() { _monthlyLegendCtl.text = _monthlyLegendCurrent; }); },
                      onUseDefault: () { setState(() { _monthlyLegendCtl.text = _defaultMonthlyLegendTemplate(); }); },
                      onCopyCurrent: () { _copyToClipboard(_monthlyLegendCurrent); },
                      templates: _monthlyLegendTemplates(),
                    ),
                    const SizedBox(height: 12),
                    _buildEditableCard(
                      title: 'ข้อมูลติดต่อ',
                      hint: 'ที่ตั้ง/โทรศัพท์/อีเมล/เวลาทำการ\nตัวอย่าง: ม.ศิลปากร ... โทร 034-xxx-xxx',
                      controller: _contactInfoCtl,
                      maxLines: 6,
                      currentValue: _contactInfoCurrent,
                      updatedAt: _contactInfoUpdatedAt,
                      onSave: () => _saveContent('contact_info_text', _contactInfoCtl),
                      onRestore: () { setState(() { _contactInfoCtl.text = _contactInfoCurrent; }); },
                      onUseDefault: () { setState(() { _contactInfoCtl.text = _defaultContactTemplate(); }); },
                      onCopyCurrent: () { _copyToClipboard(_contactInfoCurrent); },
                      templates: _contactTemplates(),
                    ),
                  ],

                  Text(
                    'คำแนะนำ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                  SizedBox(height: 12),


                  
                  _buildTip(
                    'โหมดทดสอบตำแหน่ง',
                    'เปิดใช้เมื่อต้องการทดสอบระบบโดยไม่ต้องอยู่ในบริเวณมหาวิทยาลัย ระบบจะใช้ตำแหน่งจำลอง',
                  ),

                  _buildTip(
                    'การใช้งานจริง',
                    'ในการใช้งานจริง ควรปิดทั้งสองโหมดทดสอบ เพื่อให้ระบบทำงานตามปกติและมีความปลอดภัยสูงสุด',
                  ),

                  SizedBox(height: 24),

                  // Logout Button
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: Icon(Icons.logout, color: Colors.white),
                      label: Text(
                        'ออกจากระบบ',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Templates for booking selection descriptions
  String _defaultBookingRegularTemplate() {
    return 'สำหรับการใช้งานทั่วไป เช่น เล่นเดี่ยว/ทีม ไม่ใช้พื้นที่ทั้งวัน\n'
        'จำกัดเวลาจองต่อครั้งตามประกาศ และต้องยืนยันตัวตนที่หน้าสนามก่อนใช้งาน';
  }

  List<Map<String, String>> _bookingRegularTemplates() {
    return [
      {
        'label': 'ค่าเริ่มต้น',
        'value': _defaultBookingRegularTemplate(),
      },
      {
        'label': 'ระบุเวลาจอง',
        'value': 'จองได้ครั้งละไม่เกิน 1 ชั่วโมง ต่อสนาม ต่อวัน สำหรับผู้ใช้ทั่วไป',
      },
    ];
  }

  String _defaultBookingActivityTemplate() {
    return 'สำหรับกิจกรรมพิเศษ/หน่วยงาน ใช้พื้นที่หลายช่วงเวลา\n'
        'ต้องส่งคำขอพร้อมเอกสาร และรอการอนุมัติจากผู้ดูแลระบบ';
  }

  List<Map<String, String>> _bookingActivityTemplates() {
    return [
      {
        'label': 'ค่าเริ่มต้น',
        'value': _defaultBookingActivityTemplate(),
      },
      {
        'label': 'ย้ำเอกสาร',
        'value': 'โปรดแนบเอกสารจากหน่วยงาน/สโมสรที่เกี่ยวข้องเพื่อประกอบการพิจารณา',
      },
    ];
  }

  // Default feature lists (newline separated)
  String _defaultBookingRegularFeaturesTemplate() {
    return [
      'จองได้เฉพาะในวันเดียวเท่านั้น',
      'เปิดรับจองตั้งแต่ 09:00-22:00 น.',
      'ต้องแสกน QR Code ที่สนาม',
      'ต้องยืนยันตำแหน่งที่ตั้ง',
      'จำกัด 1 สนามต่อประเภทต่อวัน',
    ].join('\n');
  }

  String _defaultBookingActivityFeaturesTemplate() {
    return [
      'จองล่วงหน้าได้ 1-2 เดือน',
      'ไม่ต้องแสกน QR Code',
      'ต้องมีเอกสารอนุญาตจากหน่วยงาน',
      'จองได้ทั้งวัน (ไม่จำกัดเวลา)',
      'รออนุมัติจากเจ้าหน้าที่',
    ].join('\n');
  }

  // Default HTML/text for Booking Rules page
  String _defaultBookingRulesTemplate() {
    return [
      '<h2>กฎและเงื่อนไขการจองสนามกีฬา</h2>',
      '<p>โปรดอ่านกฎอย่างละเอียดเพื่อให้ทุกคนสามารถใช้งานสนามได้อย่างเป็นธรรม และเพื่อป้องกันการเสียสิทธิ์/ตัดคะแนนจากการใช้งานที่ผิดเงื่อนไข</p>',
      '<h3>1) ประเภทสนามที่รองรับ</h3>',
      '<ul>',
      '<li>กลางแจ้ง: ฟุตบอล, ฟุตซอล, บาสเกตบอล, วอลเลย์บอล, ตะกร้อ, ลานอเนกประสงค์ (เปิดเฉพาะกิจกรรมที่ได้รับอนุมัติ)</li>',
      '<li>ในร่ม/คอร์ท: เทนนิส, แบดมินตัน</li>',
      '</ul>',
      '<h3>2) เวลาเปิดให้จอง</h3>',
      '<ul>',
      '<li>ทั่วไป (ฟุตบอล/ฟุตซอล/บาส/วอลเลย์/ตะกร้อ ฯลฯ): <b>เปิด 09:00</b></li>',
      '<li>เทนนิส/แบดมินตัน: <b>เปิด 12:00</b></li>',
      '</ul>',
      '<p>หมายเหตุ: เวลาเปิดจองอาจมีการปรับตามประกาศพิเศษ</p>',
      '<h3>3) เวลาใช้งานสนาม</h3>',
      '<ul>',
      '<li>ช่วงเวลาใช้งานปกติ: <b>12:00 – 22:00</b> (ยกเว้นมีประกาศพิเศษ)</li>',
      '<li>กิจกรรมพิเศษอาจได้รับอนุญาตให้ใช้ทั้งวัน ขึ้นกับการอนุมัติจากผู้ดูแล</li>',
      '</ul>',
      '<h3>4) สิทธิ์การจอง/วัน และระยะเวลาการจอง</h3>',
      '<ul>',
      '<li>ผู้ใช้ทั่วไป: จำกัดจำนวนครั้ง/วัน ตามการตั้งค่าระบบ (เช่น 1 สนาม/ประเภท/วัน)</li>',
      '<li>ต่อครั้งไม่เกิน <b>1 ชั่วโมง</b> (ยกเว้นประกาศเป็นอย่างอื่น)</li>',
      '<li>สิทธิ์จะรีเซ็ตทุกวันเวลา <b>06:00</b></li>',
      '</ul>',
      '<h3>5) เงื่อนไขการยืนยันการใช้งาน (เช็คอิน)</h3>',
      '<ul>',
      '<li>ต้องเช็คอินโดยการ <b>สแกน QR</b> ที่สนาม</li>',
      '<li>ต้องเปิด <b>ตำแหน่งที่ตั้ง</b> และอยู่ในบริเวณที่กำหนด</li>',
      '<li>ควรเช็คอิน <b>ภายในเวลาผ่อนผัน</b> หลังเวลาเริ่ม หากไม่เช็คอินทันเวลา ระบบอาจยกเลิกอัตโนมัติและตัดคะแนน</li>',
      '</ul>',
      '<h3>6) การจองสำหรับกิจกรรม</h3>',
      '<ul>',
      '<li>ใช้สำหรับหน่วยงาน/สโมสร/กิจกรรมพิเศษ สามารถจองหลายช่วงเวลา/ทั้งวัน</li>',
      '<li>ต้องยื่นคำขอพร้อมเอกสารประกอบ และรอการอนุมัติจากผู้ดูแล</li>',
      '<li>โดยปกติ <b>ไม่ต้องสแกน QR</b> สำหรับกิจกรรมที่ได้รับอนุมัติ</li>',
      '</ul>',
      '<h3>7) การยกเลิกและการไม่มาใช้งาน (No-Show)</h3>',
      '<ul>',
      '<li>ยกเลิกก่อนเวลาเริ่มล่วงหน้าอย่างน้อย <b>X ชั่วโมง</b> (ตามการตั้งค่า) เพื่อไม่กระทบสิทธิ์</li>',
      '<li>กรณีไม่มาเช็คอินภายในเวลาที่กำหนด ระบบจะยกเลิกการจองอัตโนมัติและอาจ <b>ตัดคะแนน</b></li>',
      '</ul>',
      '<h3>8) บทลงโทษ/การตัดคะแนน</h3>',
      '<ul>',
      '<li>No-Show หรือยกเลิกผิดเงื่อนไข: ถูกตัดคะแนนตามเกณฑ์ที่ระบบกำหนด</li>',
      '<li>สะสมคะแนนลบถึงเกณฑ์: อาจถูกระงับสิทธิ์ชั่วคราว</li>',
      '</ul>',
      '<h3>9) เงื่อนไขเฉพาะสนาม/ประเภทกีฬา</h3>',
      '<ul>',
      '<li>เทนนิส/แบดมินตัน: เปิดจอง 12:00, ใช้คอร์ทตามหมายเลข, ต้องแต่งกายและใช้อุปกรณ์ให้เหมาะสม</li>',
      '<li>ลานอเนกประสงค์: เปิดเฉพาะกิจกรรมที่ได้รับอนุมัติจากผู้ดูแล</li>',
      '</ul>',
      '<h3>10) คำแนะนำผู้ใช้</h3>',
      '<ul>',
      '<li>ตรวจสอบวัน/เวลา/สนามให้ถูกต้องก่อนยืนยันการจอง</li>',
      '<li>มาถึงก่อนเวลาเล็กน้อยเพื่อเช็คอินให้ทัน</li>',
      '<li>หากติดปัญหา ให้ยกเลิกให้ทันเวลาหรือแจ้งผู้ดูแล</li>',
      '</ul>',
      '<h3>11) ข้อกำหนดอื่นๆ</h3>',
      '<ul>',
      '<li>กฎอาจมีการปรับปรุงตามประกาศของมหาวิทยาลัย โปรดติดตามหน้า “ข่าว”</li>',
      '<li>ผู้ดูแลมีสิทธิ์ปรับแก้/ยกเลิกการจองที่ผิดเงื่อนไข</li>',
      '</ul>',
      '<h3>12) ช่องทางติดต่อ</h3>',
      '<p>ศูนย์กีฬา ม.ศิลปากร โทร 034-xxx-xxx อีเมล sport@su.ac.th (ตัวอย่าง แก้ไขในหน้าการตั้งค่า)</p>',
    ].join('');
  }

  Widget _buildTip(String title, String description) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildEditableCard({
    required String title,
    required String hint,
    required TextEditingController controller,
    required VoidCallback onSave,
    String currentValue = '',
    String? updatedAt,
    VoidCallback? onRestore,
    VoidCallback? onUseDefault,
    VoidCallback? onCopyCurrent,
    List<Map<String, String>> templates = const [],
    int maxLines = 4,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
                // Templates dropdown (optional)
                if (templates.isNotEmpty) ...[
                  PopupMenuButton<Map<String, String>>(
                    tooltip: 'แทรกเทมเพลต',
                    icon: const Icon(Icons.playlist_add, color: Colors.teal),
                    onSelected: (tpl) {
                      final v = tpl['value'] ?? '';
                      controller.text = v;
                    },
                    itemBuilder: (context) => templates
                        .map((t) => PopupMenuItem<Map<String, String>>(
                              value: t,
                              child: Text(t['label'] ?? 'เทมเพลต'),
                            ))
                        .toList(),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('บันทึก', style: TextStyle(color: Colors.white)),
                )
              ],
            ),
            if ((updatedAt ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text('อัปเดตล่าสุด: $updatedAt', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            // Action row: restore/use default/copy
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (onRestore != null)
                  OutlinedButton.icon(
                    onPressed: onRestore,
                    icon: const Icon(Icons.undo),
                    label: const Text('คืนค่าเดิม'),
                  ),
                if (onUseDefault != null)
                  OutlinedButton.icon(
                    onPressed: onUseDefault,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('ใช้ค่าเริ่มต้น'),
                  ),
                if (onCopyCurrent != null)
                  OutlinedButton.icon(
                    onPressed: onCopyCurrent,
                    icon: const Icon(Icons.copy_all),
                    label: const Text('คัดลอกค่าเดิม'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Change summary
            _buildChangeSummary(currentValue, controller.text),
            const SizedBox(height: 12),
            // Previews
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _previewBox(
                    title: 'ค่าปัจจุบันในระบบ',
                    text: (currentValue).trim().isEmpty ? '—' : currentValue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _previewBox(
                    title: 'ตัวอย่างการแสดงผล (ค่าที่กำลังแก้ไข)',
                    text: controller.text.trim().isEmpty ? '—' : controller.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewBox({required String title, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal[800])),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildChangeSummary(String before, String after) {
    final changed = before != after;
    final beforeLen = before.length;
    final afterLen = after.length;
    return Row(
      children: [
        Icon(changed ? Icons.info : Icons.check_circle, size: 16, color: changed ? Colors.orange : Colors.green),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            changed
                ? 'มีการเปลี่ยนแปลง: ความยาวจาก $beforeLen → $afterLen อักขระ'
                : 'ไม่มีการเปลี่ยนแปลงจากค่าปัจจุบัน',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกค่าเดิมแล้ว')),
    );
  }

  // Default templates and choices
  String _defaultDailyLegendTemplate() {
    return 'คำอธิบายสีและสถานะ\n\n'
        '- ว่าง = สีเขียวอ่อน\n'
        '- จองปกติ = สีแดงอ่อน\n'
        '- กิจกรรม = สีเหลืองอ่อน\n'
        '- เสร็จสิ้น = สีน้ำเงินอ่อน\n'
        '- ปิดให้บริการ = สีเทาอ่อน\n\n'
        'หมายเหตุ: เทนนิส/แบดมินตัน เปิดจอง 12:00 | เล่นได้ 17:00–22:00\nกีฬาอื่น เปิดจอง 09:00 | เล่นได้ 12:00–22:00';
  }

  List<Map<String, String>> _dailyLegendTemplates() {
    return [
      {
        'label': 'รูปแบบย่อ',
        'value': 'ว่าง=เขียว | จอง=แดง | กิจกรรม=เหลือง | เสร็จสิ้น=น้ำเงิน | ปิด=เทา',
      },
      {
        'label': 'ระบุเวลาเปิดจอง',
        'value': 'เปิดจองทั่วไป 09:00 | เทนนิส/แบด 12:00\nกดช่วงเวลาเพื่อดูรายละเอียด',
      },
    ];
  }

  String _defaultMonthlyLegendTemplate() {
    return 'บนปฏิทินจะแสดงจุดและสีเพื่อสื่อสถานะการจอง\n'
        'เวลาเปิดจองทั่วไป 09:00 | เทนนิส/แบดมินตัน 12:00';
  }

  List<Map<String, String>> _monthlyLegendTemplates() {
    return [
      {
        'label': 'ตัวอย่างทั่วไป',
        'value': _defaultMonthlyLegendTemplate(),
      },
      {
        'label': 'เน้นวันกิจกรรม',
        'value': 'วันกิจกรรมอาจปิดบางช่วงเวลา โปรดตรวจสอบรายละเอียดในแต่ละวัน',
      },
    ];
  }

  String _defaultContactTemplate() {
    return 'ที่ตั้ง: มหาวิทยาลัยศิลปากร วิทยาเขตพระราชวังสนามจันทร์\n'
        'โทรศัพท์: 034-255-800\n'
        'อีเมล: stadium@su.ac.th\n'
        'เวลาทำการ: จันทร์–ศุกร์ 08:00–20:00 | เสาร์–อาทิตย์ 08:00–18:00';
  }

  List<Map<String, String>> _contactTemplates() {
    return [
      {
        'label': 'ค่าเริ่มต้น',
        'value': _defaultContactTemplate(),
      },
      {
        'label': 'มีลิงก์ติดต่อ',
        'value': 'ติดต่อเพิ่มเติม: https://sport.su.ac.th/contact\nFacebook: fb.com/su.sport',
      },
    ];
  }
}

  // Normalize backend `updatedAt` which may be a Firestore timestamp-like map
  String? _formatUpdatedAt(dynamic raw) {
    try {
      if (raw == null) return null;
      // If already a string, return trimmed
      if (raw is String) {
        final s = raw.trim();
        if (s.isEmpty) return null;
        return s;
      }
      // Firestore-like map { _seconds, _nanoseconds }
      if (raw is Map) {
        if (raw.containsKey('_seconds')) {
          final secs = raw['_seconds'];
          final nanos = raw['_nanoseconds'] ?? 0;
          if (secs is int || secs is double) {
            final ms = (secs is int ? secs : (secs as double).toInt()) * 1000 + (nanos ~/ 1000000);
            final dt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
            return '${dt.toLocal().toIso8601String().replaceFirst('T', ' ').split('.').first}';
          }
        }
        // Other map shapes: try epoch millis
        if (raw.containsKey('seconds')) {
          final secs = raw['seconds'];
          final nanos = raw['nanoseconds'] ?? 0;
          if (secs is int || secs is double) {
            final ms = (secs is int ? secs : (secs as double).toInt()) * 1000 + (nanos ~/ 1000000);
            final dt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
            return '${dt.toLocal().toIso8601String().replaceFirst('T', ' ').split('.').first}';
          }
        }
      }
      // Numeric epoch (seconds or milliseconds)
      if (raw is int) {
        // Heuristic: if > 10^12 treat as ms else seconds
        if (raw > 1000000000000) {
          final dt = DateTime.fromMillisecondsSinceEpoch(raw);
          return '${dt.toLocal().toIso8601String().replaceFirst('T', ' ').split('.').first}';
        } else {
          final dt = DateTime.fromMillisecondsSinceEpoch(raw * 1000);
          return '${dt.toLocal().toIso8601String().replaceFirst('T', ' ').split('.').first}';
        }
      }
      if (raw is double) {
        final asInt = raw.toInt();
        if (asInt > 1000000000000) {
          final dt = DateTime.fromMillisecondsSinceEpoch(asInt);
          return '${dt.toLocal().toIso8601String().replaceFirst('T', ' ').split('.').first}';
        } else {
          final dt = DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
          return '${dt.toLocal().toIso8601String().replaceFirst('T', ' ').split('.').first}';
        }
      }
    } catch (e) {
      // Fall through
    }
    return raw?.toString();
  }
