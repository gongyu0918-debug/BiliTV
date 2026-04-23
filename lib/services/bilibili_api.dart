/// Bilibili API 服务 - 统一入口
///
/// 本文件作为门面(Facade)，委托给各子模块实现。
/// 拆分后的模块位于 api/ 目录：
/// - base_api.dart: 基础工具方法
/// - auth_api.dart: 认证相关
/// - video_api.dart: 视频列表、搜索
/// - playback_api.dart: 播放、弹幕、进度
/// - interaction_api.dart: 点赞、投币、收藏、关注
/// - player_extras_api.dart: 字幕、章节、播放器附加信息
/// - content_api.dart: 收藏夹、稍后再看、评论
library;

// 导出子模块，供外部直接使用
export 'api/video_api.dart' show DynamicFeed;

import 'api/auth_api.dart';
import 'api/video_api.dart';
import 'api/playback_api.dart';
import 'api/interaction_api.dart';
import 'api/player_extras_api.dart';
import 'api/content_api.dart';
import 'api/videoshot_api.dart';
import 'settings_service.dart' show VideoCodec;
import '../models/video.dart';
import '../models/favorite_folder.dart';
import '../models/player_extras.dart';
import '../models/video_comment.dart';
import '../models/videoshot.dart';

/// Bilibili API 服务 (门面模式)
/// 保持与原有接口完全兼容
class BilibiliApi {
  // ========== 用户信息相关 ==========

  /// 获取用户信息 (头像、昵称等)
  static Future<void> fetchAndSaveUserInfo() => AuthApi.fetchAndSaveUserInfo();

  // ========== TV 登录相关 ==========

  /// 生成 TV 登录二维码
  static Future<Map<String, String>?> generateTvQrCode() =>
      AuthApi.generateTvQrCode();

  /// 轮询 TV 登录状态
  static Future<Map<String, dynamic>> pollTvLogin(String authCode) =>
      AuthApi.pollTvLogin(authCode);

  // ========== 视频列表相关 ==========

  /// 获取热门视频 (无需登录)
  static Future<List<Video>> getPopularVideos({int page = 1}) =>
      VideoApi.getPopularVideos(page: page);

  /// 获取推荐视频 (需要 WBI 签名)
  static Future<List<Video>> getRecommendVideos({int idx = 0}) =>
      VideoApi.getRecommendVideos(idx: idx);

  /// 获取分区视频 (按 tid)
  static Future<List<Video>> getRegionVideos({
    required int tid,
    int page = 1,
  }) => VideoApi.getRegionVideos(tid: tid, page: page);

  /// 获取观看历史 (需要登录)
  static Future<Map<String, dynamic>> getHistory({
    int ps = 30,
    int viewAt = 0,
    int max = 0,
  }) => VideoApi.getHistory(ps: ps, viewAt: viewAt, max: max);

  // ========== 搜索相关 ==========

  /// 获取搜索建议
  static Future<List<String>> getSearchSuggestions(String keyword) =>
      VideoApi.getSearchSuggestions(keyword);

  /// 搜索视频 (需要 WBI 签名)
  static Future<List<Video>> searchVideos(
    String keyword, {
    int page = 1,
    String order = 'totalrank',
  }) => VideoApi.searchVideos(keyword, page: page, order: order);

  // ========== 动态相关 ==========

  /// 获取动态视频列表
  static Future<DynamicFeed> getDynamicFeed({String offset = ''}) =>
      VideoApi.getDynamicFeed(offset: offset);

  /// 获取相关视频
  static Future<List<Video>> getRelatedVideos(String bvid) =>
      VideoApi.getRelatedVideos(bvid);

  /// 获取 UP主 投稿视频列表
  static Future<List<Video>> getSpaceVideos({
    required int mid,
    int page = 1,
    String order = 'pubdate',
  }) => VideoApi.getSpaceVideos(mid: mid, page: page, order: order);

  // ========== 播放相关 ==========

  /// 获取视频详情（包含分P信息和播放历史）
  static Future<Map<String, dynamic>?> getVideoInfo(String bvid) =>
      PlaybackApi.getVideoInfo(bvid);

  /// 通过 bvid 获取可直接进入播放器的视频模型
  static Future<Video?> getVideoByBvid(String bvid) async {
    final info = await getVideoInfo(bvid);
    if (info == null) return null;
    return Video.fromViewInfo(info);
  }

  /// 获取视频的 cid
  static Future<int?> getVideoCid(String bvid) => PlaybackApi.getVideoCid(bvid);

  /// 获取视频播放地址
  static Future<Map<String, dynamic>?> getVideoPlayUrl({
    required String bvid,
    required int cid,
    int qn = 80,
    VideoCodec? forceCodec,
  }) => PlaybackApi.getVideoPlayUrl(
    bvid: bvid,
    cid: cid,
    qn: qn,
    forceCodec: forceCodec,
  );

  /// 获取弹幕数据
  static Future<List<Map<String, dynamic>>> getDanmaku(int cid) =>
      PlaybackApi.getDanmaku(cid);

  /// 上报播放进度
  static Future<bool> reportProgress({
    required String bvid,
    required int cid,
    required int progress,
  }) => PlaybackApi.reportProgress(bvid: bvid, cid: cid, progress: progress);

  /// 获取视频在线观看人数
  static Future<Map<String, String>?> getOnlineCount({
    required int aid,
    required int cid,
  }) => PlaybackApi.getOnlineCount(aid: aid, cid: cid);

  /// 获取播放器附加信息（字幕、章节、弹幕防挡）
  static Future<VideoPlayerExtras> getPlayerExtras({
    required String bvid,
    required int cid,
  }) => PlayerExtrasApi.getPlayerExtras(bvid: bvid, cid: cid);

  /// 获取字幕内容
  static Future<List<SubtitleCue>> getSubtitleContent(String url) =>
      PlayerExtrasApi.getSubtitleContent(url);

  /// 获取视频快照(雪碧图)数据
  static Future<VideoshotData?> getVideoshot({
    required String bvid,
    int? cid,
  }) => VideoshotApi.getVideoshot(bvid: bvid, cid: cid);

  // ========== 用户操作相关 ==========

  /// 点赞/取消点赞
  static Future<bool> likeVideo({required int aid, required bool like}) =>
      InteractionApi.likeVideo(aid: aid, like: like);

  /// 检查是否已点赞
  static Future<bool> checkLikeStatus(int aid) =>
      InteractionApi.checkLikeStatus(aid);

  /// 投币
  static Future<String?> coinVideo({required int aid, int count = 1}) =>
      InteractionApi.coinVideo(aid: aid, count: count);

  /// 检查已投币数
  static Future<int> checkCoinStatus(int aid) =>
      InteractionApi.checkCoinStatus(aid);

  /// 收藏/取消收藏
  static Future<bool> favoriteVideo({
    required int aid,
    required bool favorite,
  }) => InteractionApi.favoriteVideo(aid: aid, favorite: favorite);

  /// 获取收藏夹列表
  static Future<List<FavoriteFolder>> getFavoriteFolders({int? aid}) =>
      ContentApi.getFavoriteFolders(aid: aid);

  /// 获取收藏夹内容
  static Future<List<Video>> getFavoriteFolderVideos({
    required int mediaId,
    int page = 1,
    int pageSize = 20,
    String order = 'mtime',
  }) => ContentApi.getFavoriteFolderVideos(
    mediaId: mediaId,
    page: page,
    pageSize: pageSize,
    order: order,
  );

  /// 收藏到指定收藏夹
  static Future<bool> favoriteToFolders({
    required int aid,
    required List<int> addMediaIds,
    List<int> delMediaIds = const [],
  }) => ContentApi.favoriteToFolders(
    aid: aid,
    addMediaIds: addMediaIds,
    delMediaIds: delMediaIds,
  );

  /// 检查是否已收藏
  static Future<bool> checkFavoriteStatus(int aid) =>
      InteractionApi.checkFavoriteStatus(aid);

  /// 获取稍后再看列表
  static Future<List<Video>> getWatchLaterVideos() =>
      ContentApi.getWatchLaterVideos();

  /// 添加到稍后再看
  static Future<bool> addToWatchLater({int? aid, String? bvid}) =>
      ContentApi.addToWatchLater(aid: aid, bvid: bvid);

  /// 从稍后再看移除
  static Future<bool> removeFromWatchLater({int? aid, bool viewed = false}) =>
      ContentApi.removeFromWatchLater(aid: aid, viewed: viewed);

  /// 清空稍后再看
  static Future<bool> clearWatchLater() => ContentApi.clearWatchLater();

  /// 获取评论列表
  static Future<Map<String, dynamic>> getVideoComments({
    required int aid,
    int next = 0,
    int mode = 3,
  }) => ContentApi.getVideoComments(aid: aid, next: next, mode: mode);

  /// 获取楼中楼回复
  static Future<List<VideoComment>> getCommentReplies({
    required int aid,
    required int rootRpid,
  }) => ContentApi.getCommentReplies(aid: aid, rootRpid: rootRpid);

  /// 关注/取消关注 UP主
  static Future<bool> followUser({required int mid, required bool follow}) =>
      InteractionApi.followUser(mid: mid, follow: follow);

  /// 检查是否已关注
  static Future<bool> checkFollowStatus(int mid) =>
      InteractionApi.checkFollowStatus(mid);
}
