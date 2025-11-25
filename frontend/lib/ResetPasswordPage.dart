import 'package:flutter/material.dart';
import 'package:booking_web_full/services/api_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final String token;
  const ResetPasswordPage({super.key, required this.token});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pass1.text != _pass2.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รหัสผ่านใหม่และยืนยันไม่ตรงกัน')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final resp = await ApiService.resetPassword(token: widget.token, newPassword: _pass1.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp['message'] ?? 'เปลี่ยนรหัสผ่านสำเร็จ')),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปลี่ยนรหัสผ่านล้มเหลว: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รีเซ็ตรหัสผ่าน')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _pass1,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'รหัสผ่านใหม่'),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'ต้องมีอย่างน้อย 6 ตัวอักษร'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass2,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'ยืนยันรหัสผ่านใหม่'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'กรอกยืนยันรหัสผ่าน' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ยืนยันการเปลี่ยนรหัสผ่าน'),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
