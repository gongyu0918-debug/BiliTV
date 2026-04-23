import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/player_extras.dart';
import 'base_api.dart';
import 'sign_utils.dart';

class PlayerExtrasApi {
  static Future<VideoPlayerExtras> getPlayerExtras({
    required String bvid,
    required int cid,
  }) async {
    try {
      await BaseApi.ensureWbiKeys();

      final baseParams = {
        'bvid': bvid,
        'cid': cid.toString(),
      };

      final candidates = <ApiRequestCandidate>[];

      if (BaseApi.imgKey != null && BaseApi.subKey != null) {
        final signedParams = SignUtils.signWithWbi(
          baseParams,
          BaseApi.imgKey!,
          BaseApi.subKey!,
        );
        candidates.add(
          ApiRequestCandidate(
            label: 'wbi-v2',
            method: 'GET',
            uri: Uri.parse(
              '${BaseApi.apiBase}/x/player/wbi/v2',
            ).replace(queryParameters: signedParams),
            profile: ApiProfile.webAuthed,
          ),
        );
      }

      candidates.add(
        ApiRequestCandidate(
          label: 'v2',
          method: 'GET',
          uri: Uri.parse(
            '${BaseApi.apiBase}/x/player/v2',
          ).replace(queryParameters: baseParams),
          profile: ApiProfile.webAuthed,
        ),
      );

      final result = await BaseApi.tryJsonRequests(
        candidates,
        endpointKey: 'player_extras',
      );
      final json = result?['json'] as Map<String, dynamic>?;
      final data = json?['data'] as Map<String, dynamic>? ?? const {};

      final subtitleItems =
          data['subtitle']?['subtitles'] as List? ?? const [];
      final chapters = data['view_points'] as List? ?? const [];
      String? danmakuMaskUrl = data['dm_mask']?['mask_url'] as String?;
      if (danmakuMaskUrl != null && danmakuMaskUrl.startsWith('//')) {
        danmakuMaskUrl = 'https:$danmakuMaskUrl';
      }

      return VideoPlayerExtras(
        subtitles: subtitleItems
            .whereType<Map>()
            .map((item) => SubtitleTrack.fromJson(Map<String, dynamic>.from(item)))
            .where((track) => track.url.isNotEmpty)
            .toList(),
        chapters: chapters
            .whereType<Map>()
            .map((item) => VideoChapter.fromJson(Map<String, dynamic>.from(item)))
            .where((chapter) => chapter.to > chapter.from)
            .toList(),
        danmakuMaskUrl: danmakuMaskUrl,
      );
    } catch (_) {
      return const VideoPlayerExtras();
    }
  }

  static Future<List<SubtitleCue>> getSubtitleContent(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(
          profile: ApiProfile.web,
          referer: 'https://www.bilibili.com',
        ),
      );
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final body = decoded['body'] as List? ?? const [];
      return body
          .whereType<Map>()
          .map((item) => SubtitleCue.fromJson(Map<String, dynamic>.from(item)))
          .where((cue) => cue.content.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
