import 'package:flutter/services.dart';
import '../models/video.dart';

class TvHomeService {
  static const MethodChannel _channel = MethodChannel('com.bili.tv/tv_home');

  static String _intentUriForVideo(String bvid) => 'bilitv://video/$bvid';

  static String _buildDescription(Video video) {
    final parts = <String>[];
    if (video.ownerName.isNotEmpty) {
      parts.add(video.ownerName);
    }
    if (video.view > 0) {
      parts.add('${video.viewFormatted}播放');
    }
    if (video.duration > 0) {
      parts.add(video.durationFormatted);
    }
    return parts.join(' · ');
  }

  static Future<void> publishRecommendations(List<Video> videos) async {
    final items = videos
        .where((video) => video.bvid.isNotEmpty && video.pic.isNotEmpty)
        .take(10)
        .map(
          (video) => {
            'internalId': 'preview:${video.bvid}',
            'title': video.title,
            'description': _buildDescription(video),
            'imageUrl': video.pic,
            'intentUri': _intentUriForVideo(video.bvid),
          },
        )
        .toList();

    if (items.isEmpty) return;
    try {
      await _channel.invokeMethod('publishRecommendations', {'items': items});
    } catch (_) {
      // Ignore on unsupported devices.
    }
  }

  static Future<void> publishWatchNext({
    required Video video,
    required Duration position,
    required Duration duration,
  }) async {
    if (video.bvid.isEmpty ||
        video.pic.isEmpty ||
        duration.inMilliseconds <= 0) {
      return;
    }

    final nearEnd = position.inSeconds >= duration.inSeconds - 5;
    if (nearEnd) {
      await clearWatchNext(video.bvid);
      return;
    }

    if (position.inSeconds < 5) return;

    try {
      await _channel.invokeMethod('publishWatchNext', {
        'item': {
          'internalId': 'watchnext:${video.bvid}',
          'title': video.title,
          'description': _buildDescription(video),
          'imageUrl': video.pic,
          'intentUri': _intentUriForVideo(video.bvid),
          'progressMillis': position.inMilliseconds,
          'durationMillis': duration.inMilliseconds,
        },
      });
    } catch (_) {
      // Ignore on unsupported devices.
    }
  }

  static Future<void> clearWatchNext(String bvid) async {
    if (bvid.isEmpty) return;
    try {
      await _channel.invokeMethod('clearWatchNext', {
        'internalId': 'watchnext:$bvid',
      });
    } catch (_) {
      // Ignore on unsupported devices.
    }
  }

  static Future<Map<String, dynamic>> getDebugState() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getDebugState',
      );
      return result ?? const <String, dynamic>{};
    } catch (error) {
      return <String, dynamic>{'error': error.toString()};
    }
  }
}
