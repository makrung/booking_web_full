import 'package:flutter/material.dart';
import 'services/content_service.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class BookingRulesPage extends StatefulWidget {
  const BookingRulesPage({super.key});

  @override
  State<BookingRulesPage> createState() => _BookingRulesPageState();
}

class _BookingRulesPageState extends State<BookingRulesPage> {
  bool _loading = true;
  String? _error;
  String _content = '';
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadRules();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRules() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final v = await ContentService.getContent('booking_rules_content');
      setState(() {
        _content = (v ?? '').trim();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _looksLikeHtml(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    return RegExp(r'<[a-zA-Z][\s\S]*?>').hasMatch(t);
  }

  static const String _defaultHtml = '''
<div>
  <h2>กฎการจองและใช้งานสนาม</h2>
  <p>โปรดอ่านและปฏิบัติตามกฎต่อไปนี้เพื่อให้ทุกคนสามารถใช้งานสนามได้อย่างเป็นระเบียบและปลอดภัย</p>
  <ul>
    <li>ผู้ใช้ต้องเช็คอินก่อนเวลาเริ่มเล่น 10 นาที หากไม่เช็คอินภายในเวลา ระบบอาจยกเลิกการจอง</li>
    <li>ยกเลิกการจองได้ล่วงหน้าอย่างน้อย 1 ชั่วโมง</li>
    <li>ห้ามโอนสิทธิ์การจองโดยไม่ได้รับอนุญาต</li>
    <li>แต่งกายให้เหมาะสมและใช้อุปกรณ์ที่ปลอดภัย</li>
    <li>รักษาความสะอาดและเคารพผู้อื่นที่ใช้สนามร่วมกัน</li>
  </ul>
  <p>หากมีการเปลี่ยนแปลงกฎหรือเวลาให้บริการ จะประกาศผ่านหน้า “ข่าว”</p>
  <p>ติดต่อเจ้าหน้าที่ได้ผ่านช่องทางที่ระบุในหน้าโปรไฟล์</p>
  </div>
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal[700],
        title: const Text('กฎและวิธีใช้งานการจองสนาม', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF0F8FF),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text('เกิดข้อผิดพลาดในการโหลดข้อมูล', style: TextStyle(color: Colors.red[700])),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadRules,
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองใหม่'),
                        )
                      ],
                    ),
                  ),
                )
              : ScrollbarTheme(
                  data: const ScrollbarThemeData(
                    crossAxisMargin: -8,
                    mainAxisMargin: 0,
                  ),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          controller: _scrollController,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 900),
                                  child: Card(
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Builder(
                                        builder: (_) {
                                          final content = _content.isNotEmpty ? _content : _defaultHtml;
                                          if (_looksLikeHtml(content)) {
                                            return HtmlWidget(
                                              content,
                                              enableCaching: true,
                                              textStyle: const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
                                            );
                                          }
                                          // Non-HTML: transform simple bullets to clean HTML
                                          final lines = content.replaceAll('\r\n', '\n').split('\n');
                                          final htmlBuffer = StringBuffer('<div>');
                                          bool inList = false;
                                          for (final raw in lines) {
                                            final line = raw.trimRight();
                                            if (line.trim().isEmpty) {
                                              if (inList) { htmlBuffer.write('</ul>'); inList = false; }
                                              htmlBuffer.write('<br/>' );
                                              continue;
                                            }
                                            final isBullet = line.trimLeft().startsWith('- ') || line.trimLeft().startsWith('• ');
                                            if (isBullet) {
                                              if (!inList) { htmlBuffer.write('<ul>'); inList = true; }
                                              final txt = line.trimLeft().substring(2).trim();
                                              htmlBuffer.write('<li>${_escapeHtml(txt)}</li>');
                                            } else {
                                              if (inList) { htmlBuffer.write('</ul>'); inList = false; }
                                              htmlBuffer.write('<p>${_escapeHtml(line.trim())}</p>');
                                            }
                                          }
                                          if (inList) htmlBuffer.write('</ul>');
                                          htmlBuffer.write('</div>');
                                          return HtmlWidget(
                                            htmlBuffer.toString(),
                                            enableCaching: true,
                                            textStyle: const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}

String _escapeHtml(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
