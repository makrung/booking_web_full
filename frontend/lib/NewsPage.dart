import 'package:flutter/material.dart';
import 'models/news.dart';
import 'services/news_service.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'config/app_config.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';

// Brand color from provided image
const Color _brandGreen = Color(0xFF006D62);

// Color helpers for subtle theme-based gradients
Color _darken(Color c, [double amount = .08]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
}

Color _lighten(Color c, [double amount = .12]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
}

// Pretty Thai date like "8 ต.ค. 68 15:19 น."
String _prettyDateTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  const thMonthsShort = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
  final d = local.day;
  final m = thMonthsShort[local.month - 1];
  final beYear = local.year + 543;
  final yy = (beYear % 100).toString().padLeft(2, '0');
  final hm = DateFormat('HH:mm').format(local);
  return '$d $m $yy $hm น.';
}

class NewsPage extends StatefulWidget {
  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  bool isLoading = true;
  String? error;
  List<NewsItem> items = [];
  final Map<String, quill.Document> _docCache = {};
  final Map<String, quill.QuillController> _controllerCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { isLoading = true; error = null; });
  final data = await NewsService.list(limit: 20);
      setState(() {
        items = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() { error = '$e'; isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _load, child: const Text('ลองใหม่')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        expandedHeight: 160,
                        flexibleSpace: FlexibleSpaceBar(
                          titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 12),
                          title: const Text('ข่าวสาร', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .2)),
                          background: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _darken(_brandGreen, .04),
                                  _lighten(_brandGreen, .18),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Container(
                          width: double.infinity,
                          color: _brandGreen.withValues(alpha: .06),
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: Text(
                            'ประกาศล่าสุดและอัปเดตจากระบบจองสนาม',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _brandGreen.withValues(alpha: .95),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
                        sliver: SliverList.separated(
                          itemCount: items.length,
                          itemBuilder: (context, i) => Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 980),
                              child: _NewsCard(item: items[i]),
                            ),
                          ),
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                        ),
                      )
                    ],
                  ),
                ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = theme.cardColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
  side: BorderSide(color: _brandGreen.withValues(alpha: .25), width: 1),
      ),
      elevation: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.media.isNotEmpty) _MediaPreview(media: item.media, title: item.title, dateTime: item.updatedAt ?? item.createdAt),
            Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.10)),
            Container(
              color: bg,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _brandGreen.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _brandGreen.withValues(alpha: .30), width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_note, size: 14, color: _brandGreen),
                            const SizedBox(width: 6),
                            Text(
                              _prettyDateTime(item.updatedAt ?? item.createdAt),
                              style: theme.textTheme.labelMedium?.copyWith(color: _brandGreen.withValues(alpha: .95), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      if (item.updatedAt != null && item.updatedAt != item.createdAt) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _brandGreen.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('อัปเดต', style: theme.textTheme.labelSmall?.copyWith(color: _brandGreen, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: _ContentRenderer(item: item),
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

}

class _MediaPreview extends StatelessWidget {
  final List<NewsMedia> media;
  final String? title;
  final DateTime? dateTime;
  const _MediaPreview({required this.media, this.title, this.dateTime});

  @override
  Widget build(BuildContext context) {
    String _buildUrl(String url) {
      if (url.startsWith('http')) return url;
      final base = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
      if (url.startsWith('/')) return '$base$url';
      return '$base/$url';
    }
    return _MediaCarousel(media: media, buildUrl: _buildUrl, title: title, dateTime: dateTime);
  }
}

class _MediaCarousel extends StatefulWidget {
  final List<NewsMedia> media;
  final String Function(String) buildUrl;
  final String? title;
  final DateTime? dateTime;
  const _MediaCarousel({required this.media, required this.buildUrl, this.title, this.dateTime});

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  int _index = 0;
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  // Use explicit green accents to match homepage theme
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.media.length,
            itemBuilder: (context, i) {
              final m = widget.media[i];
              if (m.type == 'image') {
                return Container(
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: Image.network(
                    widget.buildUrl(m.url),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported)),
                  ),
                );
              } else {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black12),
                    Center(child: Icon(Icons.play_circle_filled, size: 56, color: Colors.white70)),
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
            },
          ),
          // desktop-friendly prev/next controls
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: .18)),
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () {
                final prev = (_index - 1).clamp(0, widget.media.length - 1);
                _controller.animateToPage(prev, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
              },
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: .18)),
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: () {
                final next = (_index + 1).clamp(0, widget.media.length - 1);
                _controller.animateToPage(next, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
              },
            ),
          ),
          // gradient overlay
          IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black38],
                ),
              ),
            ),
          ),
          // title & date overlay
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((widget.title ?? '').isNotEmpty) ...[
                  Text(
                    widget.title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: _brandGreen)),
                    const SizedBox(width: 8),
                    Text(
                      _prettyDateTime(widget.dateTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1))],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // indicators
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.media.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 12 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? _brandGreen : Colors.white70,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentRenderer extends StatelessWidget {
  final NewsItem item;
  const _ContentRenderer({required this.item});

  @override
  Widget build(BuildContext context) {
    // This widget is stateless, but we can access cache via an Inherited or fallback to quick build.
    // For simplicity, rebuild controller non-expensively. Delta size is typically small here.
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
    if (item.contentHtml.trim().isNotEmpty) {
      return HtmlWidget(
        item.contentHtml,
        textStyle: const TextStyle(fontSize: 16, height: 1.6),
      );
    }
    return Text(
      item.contentText,
      style: const TextStyle(fontSize: 16, height: 1.6),
    );
  }
}
