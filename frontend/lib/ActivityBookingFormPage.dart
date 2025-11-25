import 'package:flutter/material.dart';
import 'services/court_management_service_new.dart' as CourtAPI;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/base_service.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/content_service.dart';
import 'services/activity_requests_service.dart';

class ActivityBookingFormPage extends StatefulWidget {
  const ActivityBookingFormPage({super.key});

  @override
  State<ActivityBookingFormPage> createState() => _ActivityBookingFormPageState();
}

class _ActivityBookingFormPageState extends State<ActivityBookingFormPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _courts = {};
  String? _selectedCourtId;
  final Set<DateTime> _blockedDates = {};
  bool _loadingBlockedDates = false;
  String? _blockedDatesError;
  final _formKey = GlobalKey<FormState>();
  bool _blockedByDomainPolicy = false;

  // Responsible person
  final _respName = TextEditingController();
  final _respId = TextEditingController();
  final _respPhone = TextEditingController();
  final _respEmail = TextEditingController();

  // Activity info
  final _actName = TextEditingController();
  final _actDesc = TextEditingController();

  // Multi-date
  final Set<DateTime> _selectedDates = {};

  @override
  void initState() {
    super.initState();
    _loadCourts();
    _loadDomainPolicy();
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

  Future<void> _loadCourts() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await CourtAPI.CourtManagementService.getAllCourts();
      final courtsMap = (result['courts'] ?? {}) as Map<String, dynamic>;
      // Keep only available courts for selection
      final filtered = Map<String, dynamic>.fromEntries(
        courtsMap.entries.where((e) => (e.value['isAvailable'] ?? true) == true),
      );
      setState(() { 
        _courts = filtered; 
        // Clear selected court if it is unavailable now
        if (_selectedCourtId != null && !_courts.containsKey(_selectedCourtId)) {
          _selectedCourtId = null;
        }
        // If a court is selected, reload blocked dates for it
        if (_selectedCourtId != null) {
          _loadBlockedDatesForCourt(_selectedCourtId!);
        }
      });
    } catch (e) {
      setState(() { _error = 'โหลดข้อมูลสนามล้มเหลว'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _loadBlockedDatesForCourt(String courtId) async {
  if (courtId.isEmpty) return;
    setState(() { _loadingBlockedDates = true; _blockedDatesError = null; });
    try {
      final List<dynamic> reqs = await ActivityRequestsService.forCourt(courtId);
      final Set<DateTime> blocked = {};
      for (final r in reqs) {
        try {
          final rMap = r as Map<String, dynamic>;
          // Consider requests that target this court and are not rejected/cancelled
          final targetCourt = (rMap['courtId'] ?? rMap['court'] ?? '').toString();
          final status = (rMap['status'] ?? '').toString().toLowerCase();
          if (targetCourt != courtId) continue;
          if (status == 'rejected' || status == 'cancelled') continue;

          // activityDates may be a list or a single date
          if (rMap['activityDates'] is List) {
            for (final d in List.from(rMap['activityDates'])) {
              final ds = d.toString();
              final dt = DateTime.tryParse(ds);
              if (dt != null) blocked.add(DateTime(dt.year, dt.month, dt.day));
            }
          } else if (rMap['activityDate'] != null) {
            final ds = rMap['activityDate'].toString();
            final dt = DateTime.tryParse(ds);
            if (dt != null) blocked.add(DateTime(dt.year, dt.month, dt.day));
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _blockedDates.clear();
          _blockedDates.addAll(blocked);
          // Remove any selected dates that are now blocked
          widgetRemoveSelectedBlockedDates();
          _loadingBlockedDates = false;
          _blockedDatesError = null;
        });
      }
    } catch (e) {
      print('Error loading blocked dates for court $courtId: $e');
      if (mounted) setState(() {
        _blockedDates.clear();
        _loadingBlockedDates = false;
        _blockedDatesError = e.toString();
      });
    }
  }

  void widgetRemoveSelectedBlockedDates() {
    final toRemove = _selectedDates.where((d) => _blockedDates.contains(DateTime(d.year, d.month, d.day))).toList();
    if (toRemove.isNotEmpty) {
      for (final d in toRemove) _selectedDates.remove(d);
      // notify UI
      setState(() {});
    }
  }

  @override
  void dispose() {
    _respName.dispose();
    _respId.dispose();
    _respPhone.dispose();
    _respEmail.dispose();
    _actName.dispose();
    _actDesc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
            'ขณะนี้ระบบจำกัดการจองเฉพาะผู้ใช้อีเมลของมหาวิทยาลัยเท่านั้น\nผู้ใช้ที่ไม่ใช่อีเมลของทางมหาวิทยาลัยไม่สามารถทำการจองได้ชั่วคราว',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
          ],
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณาเลือกสนาม')),
      );
      return;
    }
    if (_selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณาเลือกวันที่อย่างน้อย 1 วัน')),
      );
      return;
    }

    final court = _courts[_selectedCourtId];
    final courtName = (court is Map && court['name'] != null) ? court['name'].toString() : 'ไม่ทราบชื่อสนาม';
    final dates = _selectedDates.toList()
      ..sort((a,b)=>a.compareTo(b));
    final isoDates = dates.map((d)=> DateFormat('yyyy-MM-dd').format(d)).toList();

    setState(() { _loading = true; });
    try {
      // Call the backend directly via http using BaseService through ActivityServiceRefactored is not strictly aligned
      // with current endpoints, so we'll call the points/messages after submit success only.
      final resp = await BaseActivityApi.submit(
        courtId: _selectedCourtId!,
        courtName: courtName,
        activityDates: isoDates,
        responsiblePerson: {
          'name': _respName.text.trim(),
          'id': _respId.text.trim(),
          'phone': _respPhone.text.trim(),
          'email': _respEmail.text.trim(),
        },
        activity: {
          'name': _actName.text.trim(),
          'description': _actDesc.text.trim(),
        },
      );
      if (resp['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งคำขอกิจกรรมเรียบร้อย')),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(resp['message'] ?? 'ส่งคำขอล้มเหลว');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ส่งคำขอล้มเหลว: $e')),
      );
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ขอจองกิจกรรม (ทั้งวัน)')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        if (_blockedByDomainPolicy)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
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
                        // Court selector
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCourtId,
                                items: _courts.entries
                                    .map((e) => DropdownMenuItem<String>(
                                          value: e.key,
                                          child: Text((e.value['name'] ?? e.key).toString()),
                                        ))
                                    .toList(),
                                onChanged: (v) async {
                                  setState(() => _selectedCourtId = v);
                                  if (v != null) await _loadBlockedDatesForCourt(v);
                                },
                                decoration: InputDecoration(labelText: 'สนามที่ต้องการจอง'),
                                validator: (v) => v == null ? 'กรุณาเลือกสนาม' : null,
                              ),
                            ),
                            SizedBox(width: 8),
                            if (_loadingBlockedDates)
                              SizedBox(width: 36, height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                            else
                              IconButton(
                                tooltip: 'Retry loading blocked dates',
                                icon: Icon(Icons.refresh),
                                onPressed: (_selectedCourtId == null) ? null : () => _loadBlockedDatesForCourt(_selectedCourtId!),
                              ),
                          ],
                        ),
                        if (_blockedDatesError != null)
                          Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red[100]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red[700]),
                                SizedBox(width: 8),
                                Expanded(child: Text('ไม่สามารถโหลดวันที่ที่ถูกจองได้: ${_blockedDatesError}', style: TextStyle(color: Colors.red[800]))),
                                TextButton(onPressed: () => _loadBlockedDatesForCourt(_selectedCourtId ?? ''), child: Text('ลองใหม่')),
                              ],
                            ),
                          ),
                        SizedBox(height: 12),
                        // Dates picker (multi)
                        _MultiDatePicker(
                          selected: _selectedDates,
                          onChanged: () => setState(() {}),
                          blockedDates: _blockedDates,
                        ),
                        Divider(height: 32),
                        Text('ข้อมูลผู้รับผิดชอบ', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextFormField(controller: _respName, decoration: InputDecoration(labelText: 'ชื่อ-นามสกุล'), validator: (v)=> (v==null||v.trim().isEmpty)?'กรอกชื่อผู้รับผิดชอบ':null),
                        TextFormField(controller: _respId, decoration: InputDecoration(labelText: 'รหัสนักศึกษา/เลขบัตร'), validator: (v)=> (v==null||v.trim().isEmpty)?'กรอกรหัสผู้รับผิดชอบ':null),
                        TextFormField(controller: _respPhone, decoration: InputDecoration(labelText: 'เบอร์ติดต่อ'), validator: (v)=> (v==null||v.trim().isEmpty)?'กรอกเบอร์โทร':null),
                        TextFormField(controller: _respEmail, decoration: InputDecoration(labelText: 'อีเมล'), validator: (v)=> (v==null||v.trim().isEmpty)?'กรอกอีเมล':null),
                        Divider(height: 32),
                        Text('รายละเอียดกิจกรรม', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextFormField(controller: _actName, decoration: InputDecoration(labelText: 'ชื่อกิจกรรม'), validator: (v)=> (v==null||v.trim().isEmpty)?'กรอกชื่อกิจกรรม':null),
                        TextFormField(controller: _actDesc, decoration: InputDecoration(labelText: 'รายละเอียดกิจกรรม'), maxLines: 3),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: Icon(Icons.send),
                          label: Text('ส่งฟอร์มคำขอกิจกรรม'),
                        )
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _MultiDatePicker extends StatefulWidget {
  final Set<DateTime> selected;
  final VoidCallback onChanged;
  final Set<DateTime>? blockedDates;
  const _MultiDatePicker({required this.selected, required this.onChanged, this.blockedDates});

  @override
  State<_MultiDatePicker> createState() => _MultiDatePickerState();
}

class _MultiDatePickerState extends State<_MultiDatePicker> {
  DateTime _focused = DateTime.now();

  void _pickDate() async {
    final now = DateTime.now();
    final blocked = widget.blockedDates ?? {};
    final picked = await showDatePicker(
      context: context,
      initialDate: _focused,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
      selectableDayPredicate: (day) {
        final only = DateTime(day.year, day.month, day.day);
        // disable blocked dates in the calendar UI
        return !blocked.contains(only);
      },
    );
    if (picked != null) {
      final only = DateTime(picked.year, picked.month, picked.day);
      // If this date is blocked, show dialog and do not add
      if (blocked.contains(only)) {
        // Shouldn't normally happen because selectableDayPredicate prevents it, but keep a guard
        showDialog(context: context, builder: (ctx) => AlertDialog(
          title: Row(children: [Icon(Icons.event_busy, color: Colors.orange), SizedBox(width: 8), Text('วันที่ถูกจองแล้ว')],),
          content: Text('วันที่ ${DateFormat('yyyy-MM-dd').format(only)} มีการจองกิจกรรมอยู่แล้ว และไม่สามารถเลือกได้'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('ตกลง'))],
        ));
      } else {
        if (widget.selected.contains(only)) {
          widget.selected.remove(only);
        } else {
          widget.selected.add(only);
        }
      }
      setState(() { _focused = only; });
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final list = widget.selected.toList()..sort((a,b)=>a.compareTo(b));
    final blocked = widget.blockedDates ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('วันที่ที่เลือก: ${list.isEmpty ? 'ยังไม่เลือก' : list.map(df.format).join(', ')}')),
            TextButton.icon(onPressed: _pickDate, icon: Icon(Icons.date_range), label: Text('เลือกวันที่')),
          ],
        ),
        if (list.isNotEmpty)
          Wrap(
            spacing: 8,
            children: list.map((d) => Chip(
              label: Text(df.format(d)),
              onDeleted: () {
                widget.selected.remove(d);
                setState(() {});
                widget.onChanged();
              },
            )).toList(),
          )
        ,
        if (blocked.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top:12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('วันที่ไม่สามารถเลือก (มีการจองแล้ว):', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height:6),
                Wrap(
                  spacing: 8,
                  children: (blocked.toList()..sort((a,b)=>a.compareTo(b))).map((d) => Chip(
                    backgroundColor: Colors.orange[50],
                    avatar: Icon(Icons.event_busy, size:16, color: Colors.orange[700]),
                    label: Text(df.format(d)),
                  )).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Minimal API wrapper aligned to backend endpoints in activity.routes.js

class BaseActivityApi extends BaseService {
  static Future<Map<String, dynamic>> submit({
    required String courtId,
    required String courtName,
    required List<String> activityDates,
    required Map<String, dynamic> responsiblePerson,
    required Map<String, dynamic> activity,
  }) async {
  final headers = await BaseService.getHeaders();
    final resp = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/activity-requests'),
      headers: headers,
      body: json.encode({
        'courtId': courtId,
        'courtName': courtName,
        'activityDates': activityDates,
        'responsiblePerson': responsiblePerson,
        'activity': activity,
      }),
    );
    return BaseService.parseJsonResponse(resp);
  }
}
