import 'package:flutter/material.dart';
import '../../../models/player_extras.dart';

class ChapterPanel extends StatefulWidget {
  final List<VideoChapter> chapters;
  final int focusedIndex;
  final Duration currentPosition;
  final ValueChanged<VideoChapter> onSelect;
  final VoidCallback onClose;

  const ChapterPanel({
    super.key,
    required this.chapters,
    required this.focusedIndex,
    required this.currentPosition,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<ChapterPanel> createState() => _ChapterPanelState();
}

class _ChapterPanelState extends State<ChapterPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToIndex(widget.focusedIndex),
    );
  }

  @override
  void didUpdateWidget(covariant ChapterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedIndex != widget.focusedIndex) {
      _scrollToIndex(widget.focusedIndex);
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients || widget.chapters.isEmpty) return;
    final safeIndex = index.clamp(0, widget.chapters.length - 1);
    const itemHeight = 82.0;
    final offset = safeIndex * itemHeight;
    final currentOffset = _scrollController.offset;
    final viewport = _scrollController.position.viewportDimension;

    if (offset < currentOffset) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else if (offset + itemHeight > currentOffset + viewport) {
      _scrollController.animateTo(
        offset + itemHeight - viewport,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (value.inHours > 0) {
      return '${value.inHours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 360,
      child: Container(
        color: const Color(0xFF171717).withValues(alpha: 0.96),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bookmarks_outlined, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    '看点章节',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: widget.chapters.length,
                itemBuilder: (context, index) {
                  final chapter = widget.chapters[index];
                  final isFocused = index == widget.focusedIndex;
                  final isCurrent =
                      widget.currentPosition >= chapter.from &&
                      widget.currentPosition < chapter.to;
                  return InkWell(
                    onTap: () => widget.onSelect(chapter),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFocused
                              ? Colors.white
                              : (isCurrent
                                    ? const Color(0xFFfb7299)
                                    : Colors.transparent),
                          width: isFocused ? 2 : 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (chapter.coverUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                chapter.coverUrl,
                                width: 84,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 84,
                                  height: 48,
                                  color: Colors.white10,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 84,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.bookmark_outline,
                                color: Colors.white38,
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chapter.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: isCurrent || isFocused
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${_format(chapter.from)} - ${_format(chapter.to)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
