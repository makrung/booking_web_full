import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../core/base_service.dart';

class ContentService {
  // Simple in-memory cache with TTL to reduce network calls
  static final Map<String, _CacheEntry> _cache = {};
  static const int _defaultTtlMs = 60 * 1000; // 60s

  static _CacheEntry? _getCached(String key) {
    final e = _cache[key];
    if (e == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - e.tsMs < e.ttlMs) return e;
    _cache.remove(key);
    return null;
  }

  static void _setCached(String key, dynamic value, {int? ttlMs}) {
    _cache[key] = _CacheEntry(value, DateTime.now().millisecondsSinceEpoch, ttlMs ?? _defaultTtlMs);
  }

  // Public fetch of a content value by key
  static Future<String?> getContent(String key, {int? ttlMs}) async {
    try {
      final c = _getCached('v:$key');
      if (c != null) return c.value?.toString();
      final resp = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/content/$key'), headers: {'Content-Type': 'application/json'});
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        if ((data['success'] ?? false) == true) {
          final v = data['value'];
          if (v == null) return null;
          _setCached('v:$key', v, ttlMs: ttlMs);
          return v.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  // Fetch with metadata (value and updatedAt if available)
  static Future<Map<String, dynamic>> getContentWithMeta(String key, {int? ttlMs}) async {
    try {
      final c = _getCached('m:$key');
      if (c != null && c.value is Map<String, dynamic>) return Map<String, dynamic>.from(c.value);
      final resp = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/content/$key'), headers: {'Content-Type': 'application/json'});
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        if ((data['success'] ?? false) == true) {
          final m = {
            'value': data['value'],
            'updatedAt': data['updatedAt'],
          };
          _setCached('m:$key', m, ttlMs: ttlMs);
          return m;
        }
      }
    } catch (_) {}
    return {'value': null, 'updatedAt': null};
  }

  // Admin update of a content key (requires auth)
  static Future<bool> setContent(String key, String value) async {
    try {
      final resp = await BaseService.patch(
        '${AppConfig.apiBaseUrl}/admin/content',
        {'key': key, 'value': value},
      );
      if (BaseService.isSuccessful(resp)) {
        final data = BaseService.parseJsonResponse(resp);
        // Bust caches
        _cache.remove('v:$key');
        _cache.remove('m:$key');
        return (data['success'] ?? true) == true;
      }
    } catch (_) {}
    return false;
  }
}

class _CacheEntry {
  final dynamic value;
  final int tsMs;
  final int ttlMs;
  _CacheEntry(this.value, this.tsMs, this.ttlMs);
}
