class FavoriteFolder {
  final int id;
  final String title;
  final int mediaCount;
  final String coverUrl;
  final bool isDefaultFolder;
  final bool isSelected;

  const FavoriteFolder({
    required this.id,
    required this.title,
    required this.mediaCount,
    this.coverUrl = '',
    this.isDefaultFolder = false,
    this.isSelected = false,
  });

  factory FavoriteFolder.fromJson(Map<String, dynamic> json) {
    String cover = json['cover'] as String? ?? '';
    if (cover.startsWith('//')) {
      cover = 'https:$cover';
    }

    return FavoriteFolder(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '未命名收藏夹',
      mediaCount: json['media_count'] as int? ?? json['count'] as int? ?? 0,
      coverUrl: cover,
      isDefaultFolder: json['is_default'] == true,
      isSelected: json['fav_state'] == 1,
    );
  }
}
