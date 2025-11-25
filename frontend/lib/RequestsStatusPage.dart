import 'package:flutter/material.dart';
import 'services/points_service.dart';
import 'package:intl/intl.dart';
import 'ActivityBookingFormPage.dart';
import 'package:http/http.dart' as http;
import 'core/base_service.dart';
import 'config/app_config.dart';

class RequestsStatusPage extends StatefulWidget {
  const RequestsStatusPage({super.key});

  @override
  State<RequestsStatusPage> createState() => _RequestsStatusPageState();
}

class _RequestsStatusPageState extends State<RequestsStatusPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _points = [];
  List<dynamic> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final points = await PointsService.myRequests();
      // Activity requests via backend route /activity-requests/my
      final acts = await _fetchMyActivityRequests();
      if (!mounted) return;
      setState(() { _points = points; _activities = acts; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'โหลดข้อมูลคำขอล้มเหลว: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<List<dynamic>> _fetchMyActivityRequests() async {
    try {
      final resp = await ActivityApiLite.myRequests();
      if (resp['success'] == true) {
        return List<dynamic>.from(resp['requests'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  // date formatting handled inline where necessary

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ติดตามสถานะคำขอ'),
        actions: [
          IconButton(
            tooltip: 'ขอจองกิจกรรม',
            icon: const Icon(Icons.event_available),
            onPressed: () async {
              final done = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityBookingFormPage()));
              if (done == true) _loadAll();
            },
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Text('คำขอกิจกรรม', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ..._activities.map((a) => _ActivityTile(a)),
                      const SizedBox(height: 16),
                      Text('คำขอเพิ่มคะแนน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ..._points.map((p) => _PointTile(p)),
                    ],
                  ),
                ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Map data;
  const _ActivityTile(this.data);

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }
  String _statusLabel(String s) {
    switch (s) {
      case 'approved': return 'อนุมัติแล้ว';
      case 'rejected': return 'ไม่อนุมัติ';
      default: return 'รอการอนุมัติ';
    }
  }
  String _fmt(String s) {
    try { final d = DateTime.tryParse(s); if (d != null) return DateFormat('dd/MM/yyyy').format(d); } catch (_) {}
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final court = data['courtName']?.toString() ?? '-';
    final status = data['status']?.toString() ?? 'pending';
    final dates = (data['activityDates'] is List && (data['activityDates'] as List).isNotEmpty)
        ? (data['activityDates'] as List).map((e)=> _fmt(e.toString())).join(', ')
        : _fmt((data['activityDate']?.toString() ?? '-'));
    final respName = data['responsiblePersonName']?.toString() ?? '';
    return Card(
      child: ListTile(
        leading: Icon(Icons.event, color: _statusColor(status)),
        title: Text('$court'),
        subtitle: Text('วันที่: $dates\nผู้รับผิดชอบ: $respName'),
        trailing: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status))),
      ),
    );
  }
}

class _PointTile extends StatelessWidget {
  final Map data;
  const _PointTile(this.data);

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return Colors.green;
      case 'denied': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pts = data['requestedPoints']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pending';
    final reason = data['reason']?.toString() ?? '';
    return Card(
      child: ListTile(
        leading: Icon(Icons.stars, color: _statusColor(status)),
        title: Text('ขอเพิ่มคะแนน $pts คะแนน'),
        subtitle: reason.isEmpty ? null : Text('เหตุผล: $reason'),
        trailing: Text(status, style: TextStyle(color: _statusColor(status))),
      ),
    );
  }
}

// Lightweight API helper to fetch my activity requests

class ActivityApiLite extends BaseService {
  static Future<Map<String, dynamic>> myRequests() async {
    final headers = await BaseService.getHeaders();
    final resp = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/activity-requests/my'), headers: headers);
    return BaseService.parseJsonResponse(resp);
  }
}
