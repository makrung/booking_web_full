import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart' as legacy_api;
import 'services/points_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _user;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    try {
      final result = await legacy_api.ApiService.getCurrentUser();
      if (mounted) {
        setState(() {
          _user = result['user'];
          _firstNameCtrl.text = _user?['firstName'] ?? '';
          _lastNameCtrl.text = _user?['lastName'] ?? '';
          _phoneCtrl.text = _user?['phone'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลโปรไฟล์ล้มเหลว: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_user == null) return;
    setState(() => _saving = true);
    try {
      final resp = await legacy_api.ApiService.updateProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _saving = false);
        if ((resp['success'] ?? false) || resp['message'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resp['message'] ?? 'บันทึกสำเร็จ')),
          );
          await _loadUser();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resp['error'] ?? 'บันทึกล้มเหลว')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์ของฉัน'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              // open simple dialog to request points
              int selected = 10;
              String reason = '';
              await showDialog(
                context: context,
                builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
                  return AlertDialog(
                    title: const Text('ขอเพิ่มคะแนน'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButton<int>(
                          value: selected,
                          items: const [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
                              .map((e) => DropdownMenuItem(value: e, child: Text('$e คะแนน')))
                              .toList(),
                          onChanged: (v) => setS(() => selected = v ?? 10),
                        ),
                        const SizedBox(height: 8),
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
                  );
                }),
              );
            },
            icon: const Icon(Icons.add_circle, color: Colors.white),
            label: const Text('ขอเพิ่มคะแนน', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _UserCodeCard(code: _user?['userCode']?.toString() ?? '-'),
                  const SizedBox(height: 16),
                  Text('ข้อมูลส่วนตัว', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firstNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lastNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'นามสกุล',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'โทรศัพท์',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('บันทึก'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('เปลี่ยนรหัสผ่าน', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _currentPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'รหัสผ่านเดิม', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newPassCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'รหัสผ่านใหม่', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _confirmPassCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'ยืนยันรหัสผ่านใหม่', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final cur = _currentPassCtrl.text;
                        final np = _newPassCtrl.text;
                        final cf = _confirmPassCtrl.text;
                        if (np.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร')));
                          return;
                        }
                        if (np != cf) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยืนยันรหัสผ่านใหม่ไม่ตรงกัน')));
                          return;
                        }
                        try {
                          final resp = await legacy_api.ApiService.changePassword(currentPassword: cur, newPassword: np);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? 'เปลี่ยนรหัสผ่านสำเร็จ')));
                          _currentPassCtrl.clear(); _newPassCtrl.clear(); _confirmPassCtrl.clear();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เปลี่ยนรหัสผ่านล้มเหลว: $e')));
                        }
                      },
                      icon: const Icon(Icons.password),
                      label: const Text('ยืนยันเปลี่ยนรหัสผ่าน'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _UserCodeCard extends StatelessWidget {
  final String code;
  const _UserCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2, size: 32, color: Colors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('รหัสการจองส่วนตัวของคุณ'),
                const SizedBox(height: 4),
                SelectableText(
                  code,
                  style: const TextStyle(fontSize: 18, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'คัดลอกรหัส',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('คัดลอกรหัสแล้ว')),
              );
            },
          )
        ],
      ),
    );
  }
}
