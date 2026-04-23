import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:keframe/keframe.dart';
import '../../models/favorite_folder.dart';
import '../../models/video.dart';
import '../../services/auth_service.dart';
import '../../services/bilibili_api.dart';
import '../../widgets/time_display.dart';
import '../../widgets/tv_video_card.dart';
import '../player/player_screen.dart';

class FavoritesTab extends StatefulWidget {
  final FocusNode? sidebarFocusNode;
  final bool isVisible;

  const FavoritesTab({
    super.key,
    this.sidebarFocusNode,
    this.isVisible = false,
  });

  @override
  State<FavoritesTab> createState() => FavoritesTabState();
}

class FavoritesTabState extends State<FavoritesTab> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, FocusNode> _folderFocusNodes = {};
  final Map<int, FocusNode> _videoFocusNodes = {};

  List<FavoriteFolder> _folders = [];
  List<Video> _videos = [];
  int _selectedFolderIndex = 0;
  int _currentPage = 1;
  bool _isLoadingFolders = true;
  bool _isLoadingVideos = false;
  bool _hasLoaded = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      refresh();
    }
  }

  @override
  void didUpdateWidget(covariant FavoritesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible && !_hasLoaded) {
      refresh();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _folderFocusNodes.values) {
      node.dispose();
    }
    for (final node in _videoFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _folderNode(int index) {
    return _folderFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  FocusNode _videoNode(int index) {
    return _videoFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  Future<void> refresh() async {
    setState(() {
      _isLoadingFolders = true;
      _isLoadingVideos = true;
    });

    final folders = await BilibiliApi.getFavoriteFolders();
    if (!mounted) return;

    setState(() {
      _folders = folders;
      _selectedFolderIndex = 0;
      _videos = [];
      _currentPage = 1;
      _hasMore = true;
      _isLoadingFolders = false;
      _hasLoaded = true;
    });

    if (_folders.isNotEmpty) {
      await _loadFolderVideos(reset: true);
    } else if (mounted) {
      setState(() => _isLoadingVideos = false);
    }
  }

  Future<void> _loadFolderVideos({bool reset = false}) async {
    if (_folders.isEmpty || _isLoadingVideos) return;

    final folder = _folders[_selectedFolderIndex];
    final page = reset ? 1 : _currentPage;
    setState(() => _isLoadingVideos = true);

    final videos = await BilibiliApi.getFavoriteFolderVideos(
      mediaId: folder.id,
      page: page,
    );
    if (!mounted) return;

    setState(() {
      if (reset) {
        _videos = videos;
        _currentPage = 2;
      } else {
        _videos = [..._videos, ...videos];
        _currentPage += 1;
      }
      _hasMore = videos.isNotEmpty;
      _isLoadingVideos = false;
    });
  }

  void _selectFolder(int index) {
    if (index == _selectedFolderIndex) return;
    setState(() {
      _selectedFolderIndex = index;
      _videos = [];
      _currentPage = 1;
      _hasMore = true;
    });
    _scrollController.jumpTo(0);
    _loadFolderVideos(reset: true);
  }

  void _openVideo(Video video) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PlayerScreen(video: video)));
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return const Center(
        child: Text(
          '请先登录后查看收藏夹',
          style: TextStyle(color: Colors.white70, fontSize: 20),
        ),
      );
    }

    if (_isLoadingFolders) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_folders.isEmpty) {
      return Stack(
        children: [
          const Center(
            child: Text(
              '暂无收藏夹',
              style: TextStyle(color: Colors.white70, fontSize: 20),
            ),
          ),
          const Positioned(top: 20, right: 30, child: TimeDisplay()),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: SizeCacheWidget(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 82, 30, 20),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_folders.length, (index) {
                          final folder = _folders[index];
                          final selected = index == _selectedFolderIndex;
                          return Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Focus(
                              focusNode: _folderNode(index),
                              onFocusChange: (focused) {
                                if (focused) {
                                  _selectFolder(index);
                                }
                              },
                              onKeyEvent: (node, event) {
                                if (event is! KeyDownEvent) {
                                  return KeyEventResult.ignored;
                                }
                                if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                                    index == 0) {
                                  widget.sidebarFocusNode?.requestFocus();
                                  return KeyEventResult.handled;
                                }
                                if (event.logicalKey == LogicalKeyboardKey.enter ||
                                    event.logicalKey == LogicalKeyboardKey.select) {
                                  _selectFolder(index);
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: Builder(
                                builder: (context) {
                                  final focused = Focus.of(context).hasFocus;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: focused
                                          ? const Color(0xFFfb7299)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: focused
                                            ? Colors.white
                                            : (selected
                                                  ? const Color(0xFFfb7299)
                                                  : Colors.transparent),
                                        width: focused ? 2 : 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          folder.title,
                                          style: TextStyle(
                                            color: focused
                                                ? Colors.white
                                                : (selected
                                                      ? const Color(0xFFfb7299)
                                                      : Colors.white70),
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${folder.mediaCount} 个视频',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.65),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                if (_videos.isEmpty && _isLoadingVideos)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_videos.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        '这个收藏夹还没有视频',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(30, 0, 30, 80),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 320 / 280,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 30,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final video = _videos[index];
                        if (index == _videos.length - 4 && _hasMore && !_isLoadingVideos) {
                          _loadFolderVideos();
                        }

                        return Builder(
                          builder: (ctx) => TvVideoCard(
                            video: video,
                            focusNode: _videoNode(index),
                            onTap: () => _openVideo(video),
                            onMoveLeft: index % 4 == 0
                                ? () => _folderNode(_selectedFolderIndex).requestFocus()
                                : () => _videoNode(index - 1).requestFocus(),
                            onMoveRight: index + 1 < _videos.length
                                ? () => _videoNode(index + 1).requestFocus()
                                : null,
                            onMoveUp: index >= 4
                                ? () => _videoNode(index - 4).requestFocus()
                                : () => _folderNode(_selectedFolderIndex).requestFocus(),
                            onMoveDown: index + 4 < _videos.length
                                ? () => _videoNode(index + 4).requestFocus()
                                : null,
                            onFocus: () {
                              if (!_scrollController.hasClients) return;
                              final renderObject = ctx.findRenderObject();
                              if (renderObject is RenderBox) {
                                final viewport = RenderAbstractViewport.of(renderObject);
                                final reveal = viewport.getOffsetToReveal(renderObject, 0.0).offset;
                                final target = (reveal - 170).clamp(
                                  0.0,
                                  _scrollController.position.maxScrollExtent,
                                );
                                if ((_scrollController.offset - target).abs() > 50) {
                                  _scrollController.animateTo(
                                    target,
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              }
                            },
                          ),
                        );
                      }, childCount: _videos.length),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: const Color(0xFF121212),
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 15),
            child: const Text(
              '收藏夹',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const Positioned(top: 20, right: 30, child: TimeDisplay()),
      ],
    );
  }
}
