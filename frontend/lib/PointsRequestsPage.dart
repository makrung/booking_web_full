import 'package:flutter/material.dart';
import 'services/points_service.dart';
import 'package:intl/intl.dart';

class PointsRequestsPage extends StatefulWidget {
  const PointsRequestsPage({super.key});

  @override
  State<PointsRequestsPage> createState() => _PointsRequestsPageState();
}

class _PointsRequestsPageState extends State<PointsRequestsPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _requests = [];
  String _q = '';
  String _status = 'all'; // all|pending|approved|denied

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await PointsService.myRequests();
      setState(() { _requests = items; });
    } catch (e) {
      setState(() { _error = 'โหลดคำร้องล้มเหลว: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ติดตามคำร้องขอคะแนน')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(_error!),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _load, child: const Text('ลองใหม่')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(children: [
                        Expanded(child: TextField(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ค้นหาด้วยสถานะ จำนวน หรือเหตุผล'),
                          onChanged: (v)=> setState(()=> _q = v),
                        )),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: _status,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('ทุกสถานะ')),
                            DropdownMenuItem(value: 'pending', child: Text('กำลังพิจารณา')),
                            DropdownMenuItem(value: 'approved', child: Text('อนุมัติแล้ว')),
                            DropdownMenuItem(value: 'denied', child: Text('ปฏิเสธแล้ว')),
                          ],
                          onChanged: (v)=> setState(()=> _status = v ?? 'all'),
                        )
                      ]),
                    ),
                    Expanded(
                      child: Builder(builder: (context){
                        final q = _q.toLowerCase();
                        final list = _requests.where((e){
                          final m = (e is Map) ? e : {};
                          final status = (m['status'] ?? '').toString();
                          final reqPts = (m['requestedPoints'] ?? '').toString();
                          final reason = (m['reason'] ?? '').toString().toLowerCase();
                          final matchText = status.contains(q) || reqPts.contains(q) || reason.contains(q);
                          final matchStatus = _status=='all' || status==_status;
                          return matchText && matchStatus;
                        }).toList();
                        if (list.isEmpty) {
                          return ListView(children: const [SizedBox(height: 160), Center(child: Text('ไม่พบผลลัพธ์'))]);
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (c, i) => _RequestCard(req: list[i] as Map<String, dynamic>),
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemCount: list.length,
                        );
                      }),
                    )
                  ]),
                ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> req;
  const _RequestCard({required this.req});

  @override
  Widget build(BuildContext context) {
    final status = (req['status'] ?? 'pending') as String;
    final requested = req['requestedPoints'] ?? 0;
    final decided = req['approvedPoints'];
    final reason = req['reason'] ?? '';
    final createdAt = req['createdAt'];
    DateTime? dt;
    try { dt = createdAt != null ? DateTime.parse(createdAt) : null; } catch (_) {}
    final dateText = dt != null ? DateFormat('dd/MM/yyyy HH:mm').format(dt) : '';

    Color color; IconData icon; String statusText;
    switch (status) {
      case 'approved': color = Colors.green; icon = Icons.check_circle; statusText = 'อนุมัติแล้ว'; break;
      case 'denied': color = Colors.red; icon = Icons.cancel; statusText = 'ปฏิเสธแล้ว'; break;
      default: color = Colors.orange; icon = Icons.hourglass_top; statusText = 'กำลังพิจารณา';
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(statusText, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (dateText.isNotEmpty) Text(dateText, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Text('ขอเพิ่ม: $requested คะแนน'),
            if (status == 'approved' && decided != null)
              Text('อนุมัติ: $decided คะแนน', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('เหตุผล: ${reason.isEmpty ? '-' : reason}', maxLines: 5),
          ],
        ),
      ),
    );
  }
}
