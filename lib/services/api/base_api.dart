import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_service.dart';

enum ApiProfile { web, webAuthed, live, liveAuthed, tvApp, tvLogin }

class ApiRequestCandidate {
  final String label;
  final String method;
  final Uri uri;
  final ApiProfile profile;
  final Map<String, String>? headers;
  final Object? body;
  final Encoding? encoding;

  const ApiRequestCandidate({
    required this.label,
    required this.method,
    required this.uri,
    this.profile = ApiProfile.web,
    this.headers,
    this.body,
    this.encoding,
  });
}

/// Bilibili API 基础类 - 提供共享工具方法
class BaseApi {
  static const String apiBase = 'https://api.bilibili.com';
  static const String passportBase = 'https://passport.bilibili.com';
  static const String liveApiBase = 'https://api.live.bilibili.com';
  static const int _traceLimit = 120;

  // WBI keys 缓存
  static String? imgKey;
  static String? subKey;
  static DateTime? wbiKeysTime;
  static bool _wbiLoaded = false;
  static final Map<String, int> _lastSuccessfulCandidateIndex = {};
  static final List<Map<String, dynamic>> _requestTrace = [];

  /// 获取通用请求头
  static Map<String, String> getHeaders({
    bool withCookie = false,
    ApiProfile profile = ApiProfile.web,
    String? referer,
    String? origin,
    String? userAgent,
    Map<String, String>? extraHeaders,
  }) {
    final headers = <String, String>{};

    switch (profile) {
      case ApiProfile.tvApp:
      case ApiProfile.tvLogin:
        headers['User-Agent'] =
            userAgent ??
            'Mozilla/5.0 BiliDroid/7.76.0 (tv; Android 14; Google TV Streamer) os/android model/TV mobi_app/android_tv build/7760000 channel/master innerVer/7760000';
        headers['Referer'] = referer ?? 'https://www.bilibili.com';
        headers['Origin'] = origin ?? 'https://www.bilibili.com';
        break;
      case ApiProfile.live:
      case ApiProfile.liveAuthed:
        headers['User-Agent'] =
            userAgent ??
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36';
        headers['Referer'] = referer ?? 'https://live.bilibili.com';
        if (origin != null) {
          headers['Origin'] = origin;
        }
        break;
      case ApiProfile.webAuthed:
      case ApiProfile.web:
        headers['User-Agent'] =
            userAgent ??
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36';
        headers['Referer'] = referer ?? 'https://www.bilibili.com';
        if (origin != null) {
          headers['Origin'] = origin;
        }
        break;
    }

    if (withCookie) {
      final sessdata = AuthService.sessdata;
      final biliJct = AuthService.biliJct;
      if (sessdata != null && sessdata.isNotEmpty) {
        var cookie = 'SESSDATA=$sessdata';
        if (biliJct != null && biliJct.isNotEmpty) {
          cookie += '; bili_jct=$biliJct';
        }
        headers['Cookie'] = cookie;
      }
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  static bool profileNeedsCookie(ApiProfile profile) {
    return profile == ApiProfile.webAuthed || profile == ApiProfile.liveAuthed;
  }

  static Future<http.Response> sendRequest(
    ApiRequestCandidate candidate,
  ) async {
    final headers = getHeaders(
      withCookie: profileNeedsCookie(candidate.profile),
      profile: candidate.profile,
      extraHeaders: candidate.headers,
    );

    switch (candidate.method.toUpperCase()) {
      case 'POST':
        return http.post(
          candidate.uri,
          headers: headers,
          body: candidate.body,
          encoding: candidate.encoding,
        );
      case 'GET':
      default:
        return http.get(candidate.uri, headers: headers);
    }
  }

  static Future<Map<String, dynamic>?> tryJsonRequests(
    List<ApiRequestCandidate> candidates, {
    required String endpointKey,
    bool acceptNonZeroCode = false,
  }) async {
    if (candidates.isEmpty) return null;

    final ordered = <({int index, ApiRequestCandidate candidate})>[];
    final preferredIndex = _lastSuccessfulCandidateIndex[endpointKey];

    if (preferredIndex != null &&
        preferredIndex >= 0 &&
        preferredIndex < candidates.length) {
      ordered.add((
        index: preferredIndex,
        candidate: candidates[preferredIndex],
      ));
    }

    for (int i = 0; i < candidates.length; i++) {
      if (i == preferredIndex) continue;
      ordered.add((index: i, candidate: candidates[i]));
    }

    for (final item in ordered) {
      final startedAt = DateTime.now();
      try {
        final response = await sendRequest(item.candidate);
        Map<String, dynamic>? json;

        if (response.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            json = decoded;
          }
        }

        final success =
            response.statusCode == 200 &&
            json != null &&
            (acceptNonZeroCode || json['code'] == 0);

        _appendTrace(
          endpointKey: endpointKey,
          candidate: item.candidate,
          statusCode: response.statusCode,
          code: json?['code'],
          success: success,
          startedAt: startedAt,
        );

        if (success) {
          _lastSuccessfulCandidateIndex[endpointKey] = item.index;
          return {'json': json, 'candidate': item.candidate.label};
        }
      } catch (e) {
        _appendTrace(
          endpointKey: endpointKey,
          candidate: item.candidate,
          success: false,
          error: e.toString(),
          startedAt: startedAt,
        );
      }
    }

    return null;
  }

  static void _appendTrace({
    required String endpointKey,
    required ApiRequestCandidate candidate,
    required DateTime startedAt,
    int? statusCode,
    dynamic code,
    bool success = false,
    String? error,
  }) {
    _requestTrace.add({
      'time': startedAt.toIso8601String(),
      'endpointKey': endpointKey,
      'candidate': candidate.label,
      'method': candidate.method,
      'uri': candidate.uri.toString(),
      'statusCode': statusCode,
      'code': code,
      'success': success,
      'error': error,
    });

    if (_requestTrace.length > _traceLimit) {
      _requestTrace.removeRange(0, _requestTrace.length - _traceLimit);
    }

    debugPrint(
      '[API][$endpointKey] ${candidate.label} -> ${success ? 'OK' : 'FAIL'}'
      '${statusCode != null ? ' HTTP$statusCode' : ''}'
      '${code != null ? ' code=$code' : ''}'
      '${error != null ? ' error=$error' : ''}',
    );
  }

  static List<Map<String, dynamic>> getRequestTrace() {
    return List<Map<String, dynamic>>.from(_requestTrace);
  }

  static Map<String, dynamic> buildDiagnosticsSnapshot() {
    return {
      'loggedIn': AuthService.isLoggedIn,
      'mid': AuthService.mid,
      'hasSessdata': AuthService.sessdata?.isNotEmpty ?? false,
      'hasCsrf': AuthService.biliJct?.isNotEmpty ?? false,
      'wbi': {
        'imgKey': imgKey,
        'subKey': subKey,
        'updatedAt': wbiKeysTime?.toIso8601String(),
      },
      'lastSuccessfulCandidateIndex': Map<String, int>.from(
        _lastSuccessfulCandidateIndex,
      ),
      'trace': getRequestTrace(),
    };
  }

  /// 从本地存储加载 WBI keys
  static Future<void> _loadWbiFromStorage() async {
    if (_wbiLoaded) return;
    _wbiLoaded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      imgKey = prefs.getString('wbi_img_key');
      subKey = prefs.getString('wbi_sub_key');
      final timeMs = prefs.getInt('wbi_keys_time');
      if (timeMs != null) {
        wbiKeysTime = DateTime.fromMillisecondsSinceEpoch(timeMs);
      }
    } catch (e) {
      // 忽略加载错误
    }
  }

  /// 保存 WBI keys 到本地存储
  static Future<void> _saveWbiToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (imgKey != null) prefs.setString('wbi_img_key', imgKey!);
      if (subKey != null) prefs.setString('wbi_sub_key', subKey!);
      if (wbiKeysTime != null) {
        prefs.setInt('wbi_keys_time', wbiKeysTime!.millisecondsSinceEpoch);
      }
    } catch (e) {
      // 忽略保存错误
    }
  }

  static bool _updateWbiKeys(dynamic data) {
    final wbiImg = data?['wbi_img'];
    if (wbiImg == null) return false;

    final imgUrl = wbiImg['img_url'] as String? ?? '';
    final subUrl = wbiImg['sub_url'] as String? ?? '';
    final nextImgKey = imgUrl.split('/').last.split('.').first;
    final nextSubKey = subUrl.split('/').last.split('.').first;

    if (nextImgKey.isEmpty || nextSubKey.isEmpty) {
      return false;
    }

    imgKey = nextImgKey;
    subKey = nextSubKey;
    wbiKeysTime = DateTime.now();
    _saveWbiToStorage();
    return true;
  }

  static Future<bool> _refreshWbiKeys({required bool withCookie}) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBase/x/web-interface/nav'),
        headers: getHeaders(withCookie: withCookie),
      );

      if (response.statusCode != 200) {
        return false;
      }

      final json = jsonDecode(response.body);
      return _updateWbiKeys(json['data']);
    } catch (e) {
      return false;
    }
  }

  /// 获取 WBI keys (从 nav 接口)
  /// 缓存2小时，失败时继续使用旧值
  static Future<void> ensureWbiKeys() async {
    // 首次启动时从本地加载
    await _loadWbiFromStorage();

    // 缓存2小时
    if (imgKey != null && subKey != null && wbiKeysTime != null) {
      if (DateTime.now().difference(wbiKeysTime!).inMinutes < 120) {
        return;
      }
    }

    final refreshedWithCookie = await _refreshWbiKeys(withCookie: true);
    if (refreshedWithCookie) {
      return;
    }

    await _refreshWbiKeys(withCookie: false);
  }

  /// 修复图片 URL
  static String fixPicUrl(String url) {
    if (url.startsWith('//')) return 'https:$url';
    return url;
  }

  /// 归一化媒体 CDN 地址
  static String normalizeMediaUrl(String url) {
    if (url.isEmpty) return url;

    final normalizedInput = url.startsWith('//') ? 'https:$url' : url;
    final uri = Uri.tryParse(normalizedInput);
    if (uri == null || uri.host.isEmpty) return normalizedInput;

    return uri
        .replace(scheme: uri.scheme.isEmpty ? 'https' : uri.scheme)
        .toString();
  }

  static List<String> normalizeMediaUrls(Iterable<String?> urls) {
    final preferred = <String>[];
    final fallback = <String>[];
    final seen = <String>{};

    for (final rawUrl in urls) {
      if (rawUrl == null || rawUrl.isEmpty) continue;

      final normalized = normalizeMediaUrl(rawUrl);
      if (!seen.add(normalized)) continue;

      final uri = Uri.tryParse(normalized);
      if (uri == null || uri.host.isEmpty) {
        fallback.add(normalized);
        continue;
      }

      if (_isPreferredMediaHost(uri)) {
        preferred.add(normalized);
      } else if (!_isRejectedMediaHost(uri)) {
        fallback.add(normalized);
      }
    }

    if (preferred.isNotEmpty) {
      return [...preferred, ...fallback];
    }

    return fallback;
  }

  static bool _isPreferredMediaHost(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.endsWith('.bilivideo.com') ||
        host == 'bilivideo.com' ||
        host.contains('.mcdn.bilivideo.cn') ||
        host == 'mcdn.bilivideo.cn';
  }

  static bool _isRejectedMediaHost(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.endsWith('.bilivideo.cn') &&
        !host.contains('.mcdn.bilivideo.cn') &&
        host != 'mcdn.bilivideo.cn';
  }

  /// 转换为整数 (支持 "1.2万" 格式)
  static int toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      final direct = int.tryParse(value);
      if (direct != null) return direct;

      if (value.endsWith('万')) {
        final num = double.tryParse(value.replaceAll('万', ''));
        if (num != null) return (num * 10000).round();
      }
      if (value.endsWith('亿')) {
        final num = double.tryParse(value.replaceAll('亿', ''));
        if (num != null) return (num * 100000000).round();
      }
    }
    return 0;
  }

  /// 解析时长 (支持 "1:23" 和 "1:23:45" 格式)
  static int parseDuration(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      final parts = value.split(':');
      if (parts.length == 2) {
        return (int.tryParse(parts[0]) ?? 0) * 60 +
            (int.tryParse(parts[1]) ?? 0);
      }
      if (parts.length == 3) {
        return (int.tryParse(parts[0]) ?? 0) * 3600 +
            (int.tryParse(parts[1]) ?? 0) * 60 +
            (int.tryParse(parts[2]) ?? 0);
      }
    }
    return 0;
  }
}
