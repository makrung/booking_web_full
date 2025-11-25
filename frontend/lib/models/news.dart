class NewsMedia {
  final String url;
  final String type; // image | video
  final String? name;
  final int? size;

  NewsMedia({required this.url, required this.type, this.name, this.size});

  factory NewsMedia.fromJson(Map<String, dynamic> json) => NewsMedia(
        url: json['url'] ?? '',
        type: json['type'] ?? 'image',
        name: json['name'],
        size: json['size'],
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'type': type,
        'name': name,
        'size': size,
      };
}

class NewsItem {
  final String id;
  final String title;
  final String contentHtml; // for rich text rendering
  final String contentText; // plain text fallback
  final List<NewsMedia> media;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<dynamic>? contentDelta; // optional Quill Delta JSON

  NewsItem({
    required this.id,
    required this.title,
    required this.contentHtml,
    required this.contentText,
    required this.media,
    this.createdAt,
    this.updatedAt,
    this.contentDelta,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null; // Firestore serverTimestamp will be materialized as string via API
    }

    final mediaList = (json['media'] as List?)?.map((m) => NewsMedia.fromJson(Map<String, dynamic>.from(m))).toList() ?? [];
    return NewsItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      contentHtml: json['contentHtml'] ?? '',
      contentText: json['contentText'] ?? '',
      media: mediaList,
      createdAt: parseTs(json['createdAt']),
      updatedAt: parseTs(json['updatedAt']),
      contentDelta: json['contentDelta'] is List ? List<dynamic>.from(json['contentDelta']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'contentHtml': contentHtml,
        'contentText': contentText,
        'media': media.map((e) => e.toJson()).toList(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}
