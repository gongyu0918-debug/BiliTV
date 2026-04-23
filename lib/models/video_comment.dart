class VideoComment {
  final int rpid;
  final int mid;
  final String uname;
  final String avatar;
  final String message;
  final int likeCount;
  final int replyCount;
  final int ctime;
  final bool isUpLiked;
  final List<VideoComment> replies;

  const VideoComment({
    required this.rpid,
    required this.mid,
    required this.uname,
    required this.avatar,
    required this.message,
    required this.likeCount,
    required this.replyCount,
    required this.ctime,
    this.isUpLiked = false,
    this.replies = const [],
  });

  factory VideoComment.fromJson(Map<String, dynamic> json) {
    final member = json['member'] as Map<String, dynamic>? ?? {};
    final content = json['content'] as Map<String, dynamic>? ?? {};
    final replies = json['replies'] as List? ?? const [];
    String avatar = member['avatar'] as String? ?? '';
    if (avatar.startsWith('//')) {
      avatar = 'https:$avatar';
    }

    return VideoComment(
      rpid: json['rpid'] as int? ?? 0,
      mid: int.tryParse(member['mid']?.toString() ?? '') ?? 0,
      uname: member['uname'] as String? ?? '未知用户',
      avatar: avatar,
      message: content['message'] as String? ?? '',
      likeCount: json['like'] as int? ?? 0,
      replyCount: json['rcount'] as int? ?? replies.length,
      ctime: json['ctime'] as int? ?? 0,
      isUpLiked: json['up_action']?['like'] == true,
      replies: replies
          .whereType<Map>()
          .map((reply) => VideoComment.fromJson(Map<String, dynamic>.from(reply)))
          .toList(),
    );
  }

  String get publishedAt {
    if (ctime <= 0) return '';
    final published = DateTime.fromMillisecondsSinceEpoch(ctime * 1000);
    final diff = DateTime.now().difference(published);
    if (diff.inDays >= 365) return '${diff.inDays ~/ 365}年前';
    if (diff.inDays >= 30) return '${diff.inDays ~/ 30}个月前';
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
    return '刚刚';
  }
}
