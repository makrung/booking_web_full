import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../core/base_service.dart';
import '../config/app_config.dart';
import '../models/news.dart';

class NewsService extends BaseService {
  static String _url(String path) => '${AppConfig.apiBaseUrl}$path';

  // Public
  static Future<List<NewsItem>> list({int limit = 20}) async {
    final resp = await BaseService.get(_url('/news?limit=$limit'), includeAuth: false);
    if (BaseService.isSuccessful(resp)) {
      final data = BaseService.parseJsonResponse(resp);
      final items = (data['data'] as List?) ?? [];
      return items.map((e) => NewsItem.fromJson(Map<String, dynamic>.from(e))).toList();
    }
  throw Exception(BaseService.getErrorMessage(resp));
  }

  static Future<NewsItem?> latest() async {
    final resp = await BaseService.get(_url('/news/latest'), includeAuth: false);
    if (BaseService.isSuccessful(resp)) {
      final data = BaseService.parseJsonResponse(resp);
      if (data['data'] == null) return null;
      return NewsItem.fromJson(Map<String, dynamic>.from(data['data']));
    }
  throw Exception(BaseService.getErrorMessage(resp));
  }

  // Admin
  static Future<List<Map<String, dynamic>>> uploadMedia(List<Uint8List> files, {List<String>? fileNames, List<String>? mimeTypes}) async {
    final uri = Uri.parse(_url('/admin/news/upload'));
    final request = http.MultipartRequest('POST', uri);
    final headers = await BaseService.getHeaders(includeAuth: true);
    request.headers.addAll(headers);

    for (int i = 0; i < files.length; i++) {
      final bytes = files[i];
      final name = (fileNames != null && i < fileNames.length) ? fileNames[i] : 'file_$i';
      final mime = (mimeTypes != null && i < mimeTypes.length) ? mimeTypes[i] : 'application/octet-stream';
  request.files.add(http.MultipartFile.fromBytes('media', bytes, filename: name, contentType: MediaType.parse(mime)));
    }

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = json.decode(resp.body);
      return (data['files'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw Exception('Upload failed: ${resp.body}');
  }

  static Future<NewsItem> create({required String title, String contentHtml = '', String contentText = '', List<Map<String, dynamic>> media = const [], List<dynamic>? contentDelta}) async {
    final body = {
      'title': title,
      'contentHtml': contentHtml,
      'contentText': contentText,
      'media': media,
      if (contentDelta != null) 'contentDelta': contentDelta,
    };
    final resp = await BaseService.post(_url('/admin/news'), body, includeAuth: true);
    if (BaseService.isSuccessful(resp)) {
      final data = BaseService.parseJsonResponse(resp);
      return NewsItem.fromJson(Map<String, dynamic>.from(data['data']));
    }
  throw Exception(BaseService.getErrorMessage(resp));
  }

  static Future<NewsItem> update(String id, {String? title, String? contentHtml, String? contentText, List<Map<String, dynamic>>? media, List<dynamic>? contentDelta}) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (contentHtml != null) body['contentHtml'] = contentHtml;
    if (contentText != null) body['contentText'] = contentText;
    if (media != null) body['media'] = media;
    if (contentDelta != null) body['contentDelta'] = contentDelta;
    final resp = await BaseService.put(_url('/admin/news/$id'), body, includeAuth: true);
    if (BaseService.isSuccessful(resp)) {
      final data = BaseService.parseJsonResponse(resp);
      return NewsItem.fromJson(Map<String, dynamic>.from(data['data']));
    }
  throw Exception(BaseService.getErrorMessage(resp));
  }

  static Future<void> delete(String id) async {
    final resp = await BaseService.delete(_url('/admin/news/$id'), includeAuth: true);
    if (!BaseService.isSuccessful(resp)) {
      throw Exception(BaseService.getErrorMessage(resp));
    }
  }
}
