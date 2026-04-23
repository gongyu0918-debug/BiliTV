import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:keframe/keframe.dart';
import '../../models/video.dart';
import '../../services/auth_service.dart';
import '../../services/bilibili_api.dart';
import '../../widgets/time_display.dart';
import '../../widgets/tv_video_card.dart';
import '../player/player_screen.dart';

class WatchLaterTab extends StatefulWidget {
  final FocusNode? sidebarFocusNode;
  final bool isVisible;

  const WatchLaterTab({
    super.key,
    this.sidebarFocusNode,
    this.isVisible = false,
  });

  @override
  State<WatchLaterTab> createState() => WatchLaterTabState();
}

class WatchLaterTabState extends State<WatchLaterTab> {
  List<Video> _videos = [];
  bool _isLoading = true;
  bool _hasLoaded = false;
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();
  final Map<int, FocusNode> _videoFocusNodes = {};

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      refresh();
    }
  }

  @override
  void didUpdateWidget(covariant WatchLaterTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible && !_hasLoaded) {
      refresh();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _videoFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _getFocusNode(int index) {
    return _videoFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  Future<void> refresh() async {
    setState(() {
      _isLoading = true;
      _isRefreshing = true;
    });
    final videos = await BilibiliApi.getWatchLaterVideos();
    if (!mounted) return;
    setState(() {
      _videos = videos;
      _isLoading = false;
      _isRefreshing = false;
      _hasLoaded = true;
    });
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
          '请先登录后查看稍后再看',
          style: TextStyle(color: Colors.white70, fontSize: 20),
        ),
      );
    }

    if (_isLoading && _videos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos.isEmpty) {
      return Stack(
        children: [
          const Center(
            child: Text(
              '稍后再看为空',
              style: TextStyle(color: Colors.white70, fontSize: 20),
            ),
          ),
          const Positioned(top: 20, right: 30, child: TimeDisplay()),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: SizeCacheWidget(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(30, 80, 30, 80),
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

                      Widget buildCard(BuildContext ctx) {
                        return TvVideoCard(
                          video: video,
                          focusNode: _getFocusNode(index),
                          onTap: () => _openVideo(video),
                          onMoveLeft: index % 4 == 0
                              ? () => widget.sidebarFocusNode?.requestFocus()
                              : () => _getFocusNode(index - 1).requestFocus(),
                          onMoveRight: index + 1 < _videos.length
                              ? () => _getFocusNode(index + 1).requestFocus()
                              : null,
                          onMoveUp: index >= 4
                              ? () => _getFocusNode(index - 4).requestFocus()
                              : () {},
                          onMoveDown: index + 4 < _videos.length
                              ? () => _getFocusNode(index + 4).requestFocus()
                              : null,
                          onFocus: () {
                            if (!_scrollController.hasClients) return;
                            final renderObject = ctx.findRenderObject();
                            if (renderObject is RenderBox) {
                              final viewport = RenderAbstractViewport.of(renderObject);
                              final reveal = viewport.getOffsetToReveal(renderObject, 0.0).offset;
                              final target = (reveal - 120).clamp(
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
                        );
                      }

                      if (_isRefreshing) {
                        return FrameSeparateWidget(
                          index: index,
                          placeHolder: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          child: Builder(builder: buildCard),
                        );
                      }

                      return Builder(builder: buildCard);
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
              '稍后再看',
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
