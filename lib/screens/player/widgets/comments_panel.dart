import 'package:flutter/material.dart';
import '../../../models/video_comment.dart';

class CommentsPanel extends StatefulWidget {
  final List<VideoComment> comments;
  final int focusedIndex;
  final bool isLoading;
  final bool hasMore;
  final VoidCallback onClose;
  final VoidCallback onLoadMore;

  const CommentsPanel({
    super.key,
    required this.comments,
    required this.focusedIndex,
    required this.isLoading,
    required this.hasMore,
    required this.onClose,
    required this.onLoadMore,
  });

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant CommentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedIndex != oldWidget.focusedIndex) {
      _ensureVisible(widget.focusedIndex);
    }
    if (widget.focusedIndex >= widget.comments.length - 3 &&
        widget.hasMore &&
        !widget.isLoading) {
      widget.onLoadMore();
    }
  }

  void _ensureVisible(int index) {
    if (!_scrollController.hasClients || index < 0) return;
    const itemHeight = 136.0;
    final offset = index * itemHeight;
    final currentOffset = _scrollController.offset;
    final viewport = _scrollController.position.viewportDimension;
    if (offset < currentOffset) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else if (offset + itemHeight > currentOffset + viewport) {
      _scrollController.animateTo(
        offset + itemHeight - viewport,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
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
      width: 460,
      child: Container(
        color: Colors.black.withValues(alpha: 0.92),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.comment_outlined, color: Colors.white),
                  const SizedBox(width: 10),
                  const Text(
                    '热门评论',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            Expanded(
              child: widget.comments.isEmpty && widget.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : widget.comments.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无评论',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: widget.comments.length + (widget.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= widget.comments.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                widget.isLoading ? '加载中...' : '继续下滑加载更多',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ),
                          );
                        }
                        return _CommentItem(
                          comment: widget.comments[index],
                          isFocused: widget.focusedIndex == index,
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

class _CommentItem extends StatelessWidget {
  final VideoComment comment;
  final bool isFocused;

  const _CommentItem({
    required this.comment,
    required this.isFocused,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFocused ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFocused ? Colors.white : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: comment.avatar.isNotEmpty
                ? NetworkImage(comment.avatar)
                : null,
            child: comment.avatar.isEmpty
                ? const Icon(Icons.person, size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.uname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      comment.publishedAt,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  comment.message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                if (comment.replies.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: comment.replies.take(2).map((reply) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${reply.uname}: ${reply.message}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.thumb_up_alt_outlined, size: 14, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(
                      comment.likeCount.toString(),
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    if (comment.replyCount > 0) ...[
                      const SizedBox(width: 14),
                      const Icon(Icons.forum_outlined, size: 14, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        comment.replyCount.toString(),
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
