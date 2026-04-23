class SubtitleTrack {
  final int id;
  final String languageCode;
  final String language;
  final String url;

  const SubtitleTrack({
    required this.id,
    required this.languageCode,
    required this.language,
    required this.url,
  });

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    String url = json['subtitle_url'] as String? ?? '';
    if (url.startsWith('//')) {
      url = 'https:$url';
    }

    return SubtitleTrack(
      id: json['id'] as int? ?? 0,
      languageCode: json['lan'] as String? ?? '',
      language: json['lan_doc'] as String? ?? '未知字幕',
      url: url,
    );
  }
}

class SubtitleCue {
  final Duration from;
  final Duration to;
  final String content;

  const SubtitleCue({
    required this.from,
    required this.to,
    required this.content,
  });

  factory SubtitleCue.fromJson(Map<String, dynamic> json) {
    final fromSeconds = (json['from'] as num?)?.toDouble() ?? 0.0;
    final toSeconds = (json['to'] as num?)?.toDouble() ?? 0.0;
    final lines = (json['content'] as String? ?? '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return SubtitleCue(
      from: Duration(milliseconds: (fromSeconds * 1000).round()),
      to: Duration(milliseconds: (toSeconds * 1000).round()),
      content: lines.join('\n'),
    );
  }
}

class VideoChapter {
  final String title;
  final Duration from;
  final Duration to;
  final String coverUrl;

  const VideoChapter({
    required this.title,
    required this.from,
    required this.to,
    this.coverUrl = '',
  });

  factory VideoChapter.fromJson(Map<String, dynamic> json) {
    String cover = json['imgUrl'] as String? ?? json['cover'] as String? ?? '';
    if (cover.startsWith('//')) {
      cover = 'https:$cover';
    }

    Duration parseChapterTime(dynamic raw) {
      final seconds = (raw as num?)?.toDouble() ?? 0.0;
      return Duration(milliseconds: (seconds * 1000).round());
    }

    return VideoChapter(
      title: json['content'] as String? ?? json['title'] as String? ?? '未命名章节',
      from: parseChapterTime(json['from']),
      to: parseChapterTime(json['to']),
      coverUrl: cover,
    );
  }
}

class VideoPlayerExtras {
  final List<SubtitleTrack> subtitles;
  final List<VideoChapter> chapters;
  final String? danmakuMaskUrl;

  const VideoPlayerExtras({
    this.subtitles = const [],
    this.chapters = const [],
    this.danmakuMaskUrl,
  });
}
