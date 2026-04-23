import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/favorite_folder.dart';
import '../../models/video.dart';
import '../../models/video_comment.dart';
import '../auth_service.dart';
import 'base_api.dart';

class ContentApi {
  static Future<List<FavoriteFolder>> getFavoriteFolders({
    int? aid,
  }) async {
    if (!AuthService.isLoggedIn) return const [];

    try {
      final mid = AuthService.mid;
      if (mid == null) return const [];

      final params = <String, String>{'up_mid': mid.toString()};
      if (aid != null && aid > 0) {
        params['type'] = '2';
        params['rid'] = aid.toString();
      }

      final uri = Uri.parse(
        '${BaseApi.apiBase}/x/v3/fav/folder/created/list-all',
      ).replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: BaseApi.getHeaders(withCookie: true, profile: ApiProfile.webAuthed),
      );
      if (response.statusCode != 200) return const [];

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json['code'] != 0 || json['data'] == null) return const [];

      final list = json['data']['list'] as List? ?? const [];
      return list
          .whereType<Map>()
          .map((item) => FavoriteFolder.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Video>> getFavoriteFolderVideos({
    required int mediaId,
    int page = 1,
    int pageSize = 20,
    String order = 'mtime',
  }) async {
    if (!AuthService.isLoggedIn) return const [];

    try {
      final uri = Uri.parse(
        '${BaseApi.apiBase}/x/v3/fav/resource/list',
      ).replace(
        queryParameters: {
          'media_id': mediaId.toString(),
          'pn': page.toString(),
          'ps': pageSize.toString(),
          'order': order,
          'type': '0',
          'tid': '0',
          'platform': 'web',
        },
      );

      final response = await http.get(
        uri,
        headers: BaseApi.getHeaders(withCookie: true, profile: ApiProfile.webAuthed),
      );
      if (response.statusCode != 200) return const [];

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json['code'] != 0 || json['data'] == null) return const [];

      final medias = json['data']['medias'] as List? ?? const [];
      return medias
          .whereType<Map>()
          .map((item) => _videoFromFavorite(Map<String, dynamic>.from(item)))
          .where((video) => video.bvid.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> favoriteToFolders({
    required int aid,
    required List<int> addMediaIds,
    List<int> delMediaIds = const [],
  }) async {
    if (!AuthService.isLoggedIn) return false;
    final csrf = AuthService.biliJct ?? '';
    if (csrf.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('${BaseApi.apiBase}/x/v3/fav/resource/deal'),
        headers: {
          ...BaseApi.getHeaders(withCookie: true, profile: ApiProfile.webAuthed),
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body:
            'rid=$aid&type=2&add_media_ids=${addMediaIds.join(',')}&del_media_ids=${delMediaIds.join(',')}&csrf=$csrf',
      );
      if (response.statusCode != 200) return false;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Video>> getWatchLaterVideos() async {
    if (!AuthService.isLoggedIn) return const [];

    try {
      final response = await http.get(
        Uri.parse('${BaseApi.apiBase}/x/v2/history/toview'),
        headers: BaseApi.getHeaders(withCookie: true, profile: ApiProfile.webAuthed),
      );
      if (response.statusCode != 200) return const [];

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json['code'] != 0 || json['data'] == null) return const [];

      final list = json['data']['list'] as List? ?? const [];
      return list
          .whereType<Map>()
          .map((item) => _videoFromWatchLater(Map<String, dynamic>.from(item)))
          .where((video) => video.bvid.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> addToWatchLater({
    int? aid,
    String? bvid,
  }) async {
    if (!AuthService.isLoggedIn) return false;
    final csrf = AuthService.biliJct ?? '';
    if (csrf.isEmpty || (aid == null && (bvid == null || bvid.isEmpty))) {
      return false;
    }

    final fields = <String, String>{'csrf': csrf};
    if (aid != null && aid > 0) {
      fields['aid'] = aid.toString();
    }
    if (bvid != null && bvid.isNotEmpty) {
      fields['bvid'] = bvid;
    }

    try {
      final response = await http.post(
        Uri.parse('${BaseApi.apiBase}/x/v2/history/toview/add'),
        headers: {
          ...BaseApi.getHeaders(withCookie: true, profile: ApiProfile.webAuthed),
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: fields.entries
            .map(
              (entry) =>
                  '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
            )
            .join('&'),
      );
      if (response.statusCode != 200) return false;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> removeFromWatchLater({
    int? aid,
    bool viewed = false,
  }) async {
    if (!AuthService.isLoggedIn) return false;
    final csrf = AuthService.biliJct ?? '';
    if (csrf.isEmpty) return false;

    final fields = <String, String>{
      'csrf': csrf,
      if (aid != null && aid > 0) 'aid': aid.toString(),
      if (viewed) 'viewed': 'true',
    };

    try {
      final response = await http.post(
        Uri.parse('${BaseApi.apiBase}/x/v2/history/toview/del'),
        headers: {
          ...BaseApi.getHeaders(withCookie: true, profile: ApiProfile.webAuthed),
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: fields.entries
            .map(
              (entry) =>
                  '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
            )
            .join('&'),
      );
      if (response.statusCode != 200) return false;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clearWatchLater() async {
    if (!AuthService.isLoggedIn) return false;
    final csrf = AuthService.biliJct ?? '';
    if (csrf.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('${BaseApi.apiBase}/x/v2/history/toview/clear'),
        headers: {
          ...BaseApi.getHeaders(withCookie: true, profile: ApiProfile.webAuthed),
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: 'csrf=${Uri.encodeQueryComponent(csrf)}',
      );
      if (response.statusCode != 200) return false;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getVideoComments({
    required int aid,
    int next = 0,
    int mode = 3,
  }) async {
    try {
      final uri = Uri.parse(
        '${BaseApi.apiBase}/x/v2/reply/main',
      ).replace(
        queryParameters: {
          'type': '1',
          'oid': aid.toString(),
          'mode': mode.toString(),
          'plat': '1',
          'next': next.toString(),
        },
      );
      final response = await http.get(
        uri,
        headers: BaseApi.getHeaders(profile: ApiProfile.web, referer: 'https://www.bilibili.com'),
      );
      if (response.statusCode != 200) {
        return {'list': const <VideoComment>[], 'next': 0, 'hasMore': false};
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json['code'] != 0 || json['data'] == null) {
        return {'list': const <VideoComment>[], 'next': 0, 'hasMore': false};
      }

      final replies = json['data']['replies'] as List? ?? const [];
      final cursor = json['data']['cursor'] as Map<String, dynamic>? ?? const {};
      return {
        'list': replies
            .whereType<Map>()
            .map((item) => VideoComment.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        'next': cursor['next'] as int? ?? 0,
        'hasMore': (cursor['is_end'] ?? false) != true &&
            (cursor['next'] as int? ?? 0) > 0,
      };
    } catch (_) {
      return {'list': const <VideoComment>[], 'next': 0, 'hasMore': false};
    }
  }

  static Future<List<VideoComment>> getCommentReplies({
    required int aid,
    required int rootRpid,
  }) async {
    try {
      final uri = Uri.parse(
        '${BaseApi.apiBase}/x/v2/reply/reply',
      ).replace(
        queryParameters: {
          'type': '1',
          'oid': aid.toString(),
          'root': rootRpid.toString(),
          'ps': '20',
          'pn': '1',
        },
      );
      final response = await http.get(
        uri,
        headers: BaseApi.getHeaders(profile: ApiProfile.web, referer: 'https://www.bilibili.com'),
      );
      if (response.statusCode != 200) return const [];

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json['code'] != 0 || json['data'] == null) return const [];

      final replies = json['data']['replies'] as List? ?? const [];
      return replies
          .whereType<Map>()
          .map((item) => VideoComment.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Video _videoFromFavorite(Map<String, dynamic> json) {
    return Video(
      bvid: json['bvid'] as String? ?? '',
      title: json['title'] as String? ?? '',
      pic: BaseApi.fixPicUrl(json['cover'] as String? ?? ''),
      ownerName: json['upper']?['name'] as String? ?? '',
      ownerMid: json['upper']?['mid'] as int? ?? 0,
      view: BaseApi.toInt(json['cnt_info']?['play']),
      danmaku: BaseApi.toInt(json['cnt_info']?['danmaku']),
      duration: BaseApi.parseDuration(json['duration'] ?? json['length'] ?? 0),
      pubdate: json['pubtime'] as int? ?? 0,
      badge: json['badge'] as String? ?? '',
    );
  }

  static Video _videoFromWatchLater(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>? ?? const {};
    final stat = json['stat'] as Map<String, dynamic>? ?? const {};
    return Video(
      bvid: json['bvid'] as String? ?? '',
      title: json['title'] as String? ?? '',
      pic: BaseApi.fixPicUrl(json['pic'] as String? ?? json['cover'] as String? ?? ''),
      ownerName: owner['name'] as String? ?? json['author'] as String? ?? '',
      ownerFace: BaseApi.fixPicUrl(owner['face'] as String? ?? ''),
      ownerMid: owner['mid'] as int? ?? 0,
      view: BaseApi.toInt(stat['view'] ?? json['play']),
      danmaku: BaseApi.toInt(stat['danmaku']),
      duration: BaseApi.parseDuration(json['duration'] ?? json['length'] ?? 0),
      pubdate: json['pubdate'] as int? ?? 0,
      progress: BaseApi.toInt(json['progress']),
      cid: BaseApi.toInt(json['cid']),
      badge: json['badge'] as String? ?? '',
    );
  }
}
