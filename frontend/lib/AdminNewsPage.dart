import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'models/news.dart';
import 'services/news_service.dart';
import 'config/app_config.dart';

class AdminNewsPage extends StatefulWidget {
  final bool embedded;
  const AdminNewsPage({super.key, this.embedded = false});

  @override
  State<AdminNewsPage> createState() => _AdminNewsPageState();
}

class _AdminNewsPageState extends State<AdminNewsPage> {
  final _titleController = TextEditingController();
  late quill.QuillController _quillController;
  bool isLoading = false;
  String? error;
  List<NewsItem> items = [];
  List<Map<String, dynamic>> uploadedMedia = [];
  String? editingId;
  int _selectedFontSize = 16;
  String _qNews = '';
  String _newsSort = 'none'; // none|latest|oldest

  @override
  void initState() {
    super.initState();
  _quillController = quill.QuillController.basic();
    _refresh();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      setState(() { isLoading = true; error = null; });
      final list = await NewsService.list(limit: 100);
      setState(() { items = list; isLoading = false; });
    } catch (e) {
      setState(() { error = '$e'; isLoading = false; });
    }
  }

  Future<void> _pickAndUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true, type: FileType.custom, allowedExtensions: ['png','jpg','jpeg','gif','mp4','mov','webm']);
      if (result == null) return;
      final files = <Uint8List>[];
      final names = <String>[];
      final mimes = <String>[];
      for (final f in result.files) {
        if (f.bytes == null) continue;
        files.add(f.bytes!);
        names.add(f.name);
        final ext = f.extension?.toLowerCase() ?? '';
        String mime = 'application/octet-stream';
        if (['png','jpg','jpeg','gif'].contains(ext)) mime = 'image/$ext'.replaceAll('jpg', 'jpeg');
        if (['mp4','mov','webm'].contains(ext)) mime = ext == 'mov' ? 'video/quicktime' : 'video/$ext';
        mimes.add(mime);
      }
      if (files.isEmpty) return;
      setState(() { isLoading = true; });
      final uploaded = await NewsService.uploadMedia(files, fileNames: names, mimeTypes: mimes);
      setState(() { uploadedMedia.addAll(uploaded); isLoading = false; });
    } catch (e) {
      setState(() { error = 'Upload error: $e'; isLoading = false; });
    }
  }

  Future<void> _save() async {
    try {
      setState(() { isLoading = true; error = null; });
      final title = _titleController.text.trim();
  final delta = _quillController.document.toDelta();
      final plain = _quillController.document.toPlainText().replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      final html = _quillDeltaToBasicHtml(delta); // minimal HTML for compatibility
      if (editingId == null) {
        await NewsService.create(title: title, contentHtml: html, contentText: plain, media: uploadedMedia, contentDelta: delta.toJson());
      } else {
        await NewsService.update(editingId!, title: title, contentHtml: html, contentText: plain, media: uploadedMedia, contentDelta: delta.toJson());
      }
      _titleController.clear();
  _quillController = quill.QuillController.basic();
      uploadedMedia.clear();
      editingId = null;
      await _refresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข่าวสารสำเร็จ')));
    } catch (e) {
      setState(() { error = '$e'; isLoading = false; });
    }
  }

  void _showPreview() {
    final title = _titleController.text.trim();
    final delta = _quillController.document.toDelta();
    final plain = _quillController.document
        .toPlainText()
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final html = _quillDeltaToBasicHtml(delta);

    final previewItem = NewsItem(
      id: editingId ?? 'preview',
      title: title.isEmpty ? '(ไม่มีหัวข้อ)' : title,
      contentHtml: html,
      contentText: plain,
      media: uploadedMedia
          .map((m) => NewsMedia.fromJson({
                'url': m['url'],
                'type': m['type'] ?? 'image',
                'name': m['name'],
                'size': m['size'],
              }))
          .toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      contentDelta: delta.toJson(),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility),
                      const SizedBox(width: 8),
                      const Text('ตัวอย่างการแสดงผลข่าว', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _AdminNewsPreviewCard(item: previewItem),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _edit(NewsItem item) async {
    setState(() {
      editingId = item.id;
      _titleController.text = item.title;
      uploadedMedia = item.media.map((m) => m.toJson()).toList();
      try {
        if (item.contentDelta != null) {
          _quillController = quill.QuillController(
            document: quill.Document.fromJson(item.contentDelta!),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          // Fallback: load plain text (or stripped HTML) so content isn't lost when editing old posts
          final fallbackText = item.contentText.isNotEmpty
              ? item.contentText
              : _stripHtmlTags(item.contentHtml);
          final json = [
            { 'insert': fallbackText },
            { 'insert': '\n' },
          ];
          _quillController = quill.QuillController(
            document: quill.Document.fromJson(json),
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      } catch (_) {
        _quillController = quill.QuillController.basic();
      }
    });
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('ยืนยันการลบ'), content: const Text('คุณต้องการลบข่าวสารนี้หรือไม่?'), actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('ยกเลิก')), ElevatedButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('ลบ'))]));
    if (ok != true) return;
    await NewsService.delete(id);
    await _refresh();
  }

  // no-op
  String _stripHtmlTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final body = Row(
        children: [
          // Editor
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ListView(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'หัวข้อ', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: quill.QuillSimpleToolbar(
                                controller: _quillController,
                                config: const quill.QuillSimpleToolbarConfig(
                                  multiRowsDisplay: false,
                                  showFontSize: true,
                                  showColorButton: true,
                                  showBackgroundColorButton: true,
                                  showAlignmentButtons: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<int>(
                              value: _selectedFontSize,
                              items: [for (int i = 1; i <= 40; i++) i]
                                  .map((v) => DropdownMenuItem(value: v, child: Text('ขนาด $v')))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                if (!mounted) return;
                                setState(() => _selectedFontSize = v);
                                // Apply 'size' attribute using numeric value (Quill supports predefined sizes or numeric)
                                try {
                                  _quillController.formatSelection(
                                    quill.Attribute.fromKeyValue('size', '$v'),
                                  );
                                } catch (_) {
                                  // Fallback to removing size if invalid
                                  _quillController.formatSelection(quill.Attribute.size);
                                }
                              },
                              underline: const SizedBox(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: quill.QuillEditor.basic(
                            controller: _quillController,
                            config: const quill.QuillEditorConfig(
                              padding: EdgeInsets.all(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(onPressed: isLoading ? null : _pickAndUpload, icon: const Icon(Icons.attach_file), label: const Text('แนบรูป/วิดีโอ')),
                      OutlinedButton.icon(onPressed: isLoading ? null : _showPreview, icon: const Icon(Icons.visibility), label: const Text('ดูตัวอย่าง')),
                      ElevatedButton.icon(onPressed: isLoading ? null : _save, icon: const Icon(Icons.save), label: Text(editingId == null ? 'โพสต์ข่าว' : 'บันทึกการแก้ไข')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (uploadedMedia.isNotEmpty) Text('ไฟล์ที่แนบ (${uploadedMedia.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (uploadedMedia.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: uploadedMedia
                          .map((m) => Chip(label: Text((m['name'] ?? m['url']).toString()), onDeleted: () => setState(() => uploadedMedia.remove(m))))
                          .toList(),
                    ),
                  if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          // List
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey.shade50,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.where((e) => _matchesNewsQuery(e)).length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              Expanded(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ค้นหาข่าวด้วยหัวข้อหรือเนื้อหา'), onChanged: (v) => setState(() => _qNews = v))),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value: _newsSort,
                                items: const [
                                  DropdownMenuItem(value: 'none', child: Text('เรียง: ปกติ')),
                                  DropdownMenuItem(value: 'latest', child: Text('เรียง: ล่าสุด')),
                                  DropdownMenuItem(value: 'oldest', child: Text('เรียง: เก่า')),
                                ],
                                onChanged: (v) => setState(() => _newsSort = v ?? 'none'),
                              ),
                            ]),
                          );
                        }
                        // Apply client-side sort
                        final baseList = items.where((e) => _matchesNewsQuery(e)).toList();
                        if (_newsSort == 'latest') {
                          baseList.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
                        } else if (_newsSort == 'oldest') {
                          baseList.sort((a, b) => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
                        }
                        final list = baseList;
                        final it = list[i-1];
                        return Card(
                          child: ListTile(
                            title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(it.contentText, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Wrap(spacing: 8, children: [
                              IconButton(onPressed: () => _edit(it), icon: const Icon(Icons.edit)),
                              IconButton(onPressed: () => _delete(it.id), icon: const Icon(Icons.delete, color: Colors.red)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          )
        ],
      );

    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('จัดการข่าวสาร')),
      body: body,
    );
  }

  bool _matchesNewsQuery(NewsItem it) {
    if (_qNews.trim().isEmpty) return true;
    final q = _qNews.toLowerCase();
    return it.title.toLowerCase().contains(q) || it.contentText.toLowerCase().contains(q);
  }

  // Minimal Quill Delta to HTML to keep compatibility with current NewsPage renderer
  String _quillDeltaToBasicHtml(dynamic delta) {
    final buffer = StringBuffer();
    final List ops = (delta.toJson() as List);
    for (final op in ops) {
      final data = op['insert'];
      final attrs = op['attributes'] ?? {};
      if (data is String) {
        String text = data.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
        if ((attrs['bold'] ?? false) == true) text = '<b>$text</b>';
        if ((attrs['italic'] ?? false) == true) text = '<i>$text</i>';
        if ((attrs['underline'] ?? false) == true) text = '<u>$text</u>';
        if (text == '\n') {
          buffer.write('<br/>');
        } else {
          buffer.write(text);
        }
      }
    }
    return buffer.toString();
  }
}

class _AdminNewsPreviewCard extends StatelessWidget {
  final NewsItem item;
  const _AdminNewsPreviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.media.isNotEmpty) _PreviewMediaCarousel(media: item.media),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('ตัวอย่าง • ${_formatDate(item.createdAt)}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: _PreviewContentRenderer(item: item),
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

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _PreviewMediaCarousel extends StatelessWidget {
  final List<NewsMedia> media;
  const _PreviewMediaCarousel({required this.media});

  String _buildUrl(String url) {
    if (url.startsWith('http')) return url;
    // Admin preview uses same base resolution logic as public
    final base = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          PageView(
            children: media.map((m) {
              if (m.type == 'image') {
                return Container(
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Image.network(
                      _buildUrl(m.url),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported)),
                    ),
                  ),
                );
              } else {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black12),
                    Center(child: Icon(Icons.play_circle_filled, size: 48, color: Colors.grey.shade700)),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('วิดีโอ: ${m.name ?? ''}', style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    )
                  ],
                );
              }
            }).toList(),
          ),
          // gradient overlay for aesthetics
          IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black26],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _PreviewContentRenderer extends StatelessWidget {
  final NewsItem item;
  const _PreviewContentRenderer({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.contentDelta != null && item.contentDelta!.isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(item.contentDelta!);
        final controller = quill.QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
        controller.readOnly = true;
        return FocusScope(
          canRequestFocus: false,
          child: quill.QuillEditor.basic(
            controller: controller,
            config: const quill.QuillEditorConfig(
              padding: EdgeInsets.zero,
            ),
          ),
        );
      } catch (_) {}
    }
    return Text(item.contentText, style: const TextStyle(fontSize: 15, height: 1.5));
  }
}
