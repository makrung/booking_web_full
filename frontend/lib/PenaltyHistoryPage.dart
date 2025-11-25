import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/penalty_service.dart';
import 'services/points_service.dart';
import 'MessagesPage.dart';
import 'PointsRequestsPage.dart';
import 'dart:async';

class PenaltyHistoryPage extends StatefulWidget {
  @override
  _PenaltyHistoryPageState createState() => _PenaltyHistoryPageState();
}

class _PenaltyHistoryPageState extends State<PenaltyHistoryPage> {
  List<dynamic> penaltyHistory = [];
  int currentPoints = 0;
  int totalPenaltyPoints = 0;
  bool isLoading = true;
  String? error;
  int _unreadInbox = 0;
  Timer? _inboxTimer;
  int _lastUnread = 0;

  @override
  void initState() {
    super.initState();
    _loadPenaltyHistory();
    _loadCurrentPoints();
    _loadUnread();
    _startInboxPolling();
  }

  Future<void> _loadPenaltyHistory() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await PenaltyService.getPenaltyHistory();
      if (result['success']) {
        setState(() {
          penaltyHistory = result['penalties'];
          totalPenaltyPoints = result['totalPoints'];
        });
      } else {
        setState(() {
          error = result['error'];
        });
      }
    } catch (e) {
      setState(() {
        error = 'เกิดข้อผิดพลาด: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentPoints() async {
    try {
      final result = await PenaltyService.getCurrentPoints();
      if (result['success']) {
        setState(() {
          currentPoints = result['points'];
        });
      }
    } catch (e) {
      print('Error loading current points: $e');
    }
  }

  Future<void> _loadUnread() async {
    try {
      final n = await PointsService.unreadMessagesCount();
      if (mounted) setState(() { _unreadInbox = n; });
    } catch (_) {}
  }

  void _startInboxPolling() {
    _inboxTimer?.cancel();
    _lastUnread = _unreadInbox;
    _inboxTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        final n = await PointsService.unreadMessagesCount();
        if (!mounted) return;
        if (n > _lastUnread) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('มีข้อความใหม่ในกล่องข้อความ'),
              action: SnackBarAction(
                label: 'เปิด',
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessagesPage()));
                  await _loadUnread();
                },
              ),
            ),
          );
        }
        setState(() {
          _unreadInbox = n;
          _lastUnread = n;
        });
      } catch (_) {}
    });
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
          children: [
            Text(
              'ประวัติคะแนนโทษ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'คะแนนปัจจุบัน: $currentPoints คะแนน',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'กล่องข้อความ',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MessagesPage()),
              );
              try { await PointsService.markAllMessagesRead(); } catch (_) {}
              await _loadUnread();
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.mail, color: Colors.white),
                if (_unreadInbox > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                      child: Text('$_unreadInbox', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'ติดตามคำร้อง',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PointsRequestsPage()),
              );
            },
            icon: const Icon(Icons.assignment_outlined, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          int selected = 10; String reason = '';
          await showDialog(context: context, builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => AlertDialog(
              title: const Text('ขอเพิ่มคะแนน'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: selected,
                    items: const [10,20,30,40,50,60,70,80,90,100]
                        .map((e) => DropdownMenuItem(value: e, child: Text('$e คะแนน')))
                        .toList(),
                    onChanged: (v) => setS(() => selected = v ?? 10),
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'เหตุผล (ไม่บังคับ)'),
                    onChanged: (v) => reason = v,
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
                ElevatedButton(
                  onPressed: () async {
                    final resp = await PointsService.requestPoints(points: selected, reason: reason);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(resp['message'] ?? 'ส่งคำขอแล้ว')),
                      );
                    }
                  },
                  child: const Text('ส่งคำขอ'),
                )
              ],
            ),
          ));
        },
        icon: const Icon(Icons.assignment_turned_in),
        label: const Text('ส่งคำร้องขอคะแนน'),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(error!),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          _loadPenaltyHistory();
                          _loadCurrentPoints();
                        },
                        child: Text('ลองใหม่'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // สรุปคะแนน
                    Container(
                      margin: EdgeInsets.all(16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard(
                            'คะแนนปัจจุบัน',
                            '$currentPoints',
                            Icons.stars,
                            currentPoints >= 50 ? Colors.green : Colors.orange,
                          ),
                          _buildStatCard(
                            'คะแนนโทษทั้งหมด',
                            '$totalPenaltyPoints',
                            Icons.warning,
                            Colors.red,
                          ),
                          _buildStatCard(
                            'จำนวนครั้ง',
                            '${penaltyHistory.length}',
                            Icons.history,
                            Colors.blue,
                          ),
                        ],
                      ),
                    ),
                    
                    // คำแนะนำ
                    if (currentPoints < 50)
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'คะแนนของคุณต่ำกว่า 50 คะแนน กรุณาระวังการจองและยืนยันตรงเวลา',
                                style: TextStyle(color: Colors.orange[800]),
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 16),

                    // รายการประวัติ
                    Expanded(
                      child: penaltyHistory.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 64,
                                    color: Colors.green,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'ไม่มีประวัติคะแนนโทษ',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'คุณจองและยืนยันตรงเวลาเสมอ เยี่ยมมาก!',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              itemCount: penaltyHistory.length,
                              itemBuilder: (context, index) {
                                return _buildPenaltyCard(penaltyHistory[index]);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPenaltyCard(Map<String, dynamic> penalty) {
    final date = DateTime.parse(penalty['createdAt'] ?? DateTime.now().toIso8601String());
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${penalty['courtName'] ?? 'สนาม'}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '-${penalty['penaltyPoints'] ?? 10} คะแนน',
                  style: TextStyle(
                    color: Colors.red[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'วันที่จอง: ${penalty['bookingDate'] ?? 'ไม่ระบุ'}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            'เวลาที่จอง: ${penalty['timeSlots']?.join(', ') ?? 'ไม่ระบุ'}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'สาเหตุ: ${penalty['reason'] ?? 'ไม่ได้มายืนยันการจองตรงเวลา'}',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'วันที่หักคะแนน: $formattedDate',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
