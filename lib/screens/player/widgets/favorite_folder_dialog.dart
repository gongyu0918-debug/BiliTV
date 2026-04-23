import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../models/favorite_folder.dart';
import '../../../services/bilibili_api.dart';

class FavoriteFolderDialog extends StatefulWidget {
  final int aid;
  final String videoTitle;

  const FavoriteFolderDialog({
    super.key,
    required this.aid,
    required this.videoTitle,
  });

  @override
  State<FavoriteFolderDialog> createState() => _FavoriteFolderDialogState();
}

class _FavoriteFolderDialogState extends State<FavoriteFolderDialog> {
  final FocusNode _focusNode = FocusNode();
  final Map<int, GlobalKey> _itemKeys = <int, GlobalKey>{};
  List<FavoriteFolder> _folders = [];
  Set<int> _selectedIds = <int>{};
  Set<int> _originalIds = <int>{};
  bool _isLoading = true;
  bool _isSaving = false;
  int _focusedIndex = 0;

  int get _saveIndex => _folders.length;

  @override
  void initState() {
    super.initState();
    _loadFolders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  GlobalKey _itemKeyFor(int folderId) {
    return _itemKeys.putIfAbsent(folderId, GlobalKey.new);
  }

  void _ensureFocusedVisible() {
    if (_focusedIndex < 0 || _focusedIndex >= _folders.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusedIndex < 0 || _focusedIndex >= _folders.length) {
        return;
      }
      final itemContext = _itemKeyFor(
        _folders[_focusedIndex].id,
      ).currentContext;
      if (itemContext == null) return;
      Scrollable.ensureVisible(
        itemContext,
        duration: const Duration(milliseconds: 160),
        alignment: 0.5,
      );
    });
  }

  Future<void> _loadFolders() async {
    final folders = await BilibiliApi.getFavoriteFolders(aid: widget.aid);
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _itemKeys
        ..clear()
        ..addEntries(folders.map((folder) => MapEntry(folder.id, GlobalKey())));
      _originalIds = folders
          .where((folder) => folder.isSelected)
          .map((folder) => folder.id)
          .toSet();
      _selectedIds = Set<int>.from(_originalIds);
      _isLoading = false;
      _focusedIndex = folders.isEmpty ? 0 : 0;
    });
    _ensureFocusedVisible();
  }

  void _toggleFolder(FavoriteFolder folder) {
    setState(() {
      if (_selectedIds.contains(folder.id)) {
        _selectedIds.remove(folder.id);
      } else {
        _selectedIds.add(folder.id);
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final addIds = _selectedIds.difference(_originalIds).toList();
    final delIds = _originalIds.difference(_selectedIds).toList();

    if (addIds.isEmpty && delIds.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _isSaving = true);
    final success = await BilibiliApi.favoriteToFolders(
      aid: widget.aid,
      addMediaIds: addIds,
      delMediaIds: delIds,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Fluttertoast.showToast(msg: _selectedIds.isEmpty ? '已取消收藏' : '收藏夹已更新');
      Navigator.of(context).pop(true);
      return;
    }

    Fluttertoast.showToast(msg: '收藏夹更新失败');
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _focusedIndex = (_focusedIndex - 1).clamp(0, _saveIndex);
      });
      _ensureFocusedVisible();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _focusedIndex = (_focusedIndex + 1).clamp(0, _saveIndex);
      });
      _ensureFocusedVisible();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.browserBack) {
      Navigator.of(context).pop(false);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (_focusedIndex < _folders.length) {
        _toggleFolder(_folders[_focusedIndex]);
      } else {
        _save();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildFolderItem(FavoriteFolder folder, bool isFocused) {
    final isSelected = _selectedIds.contains(folder.id);
    return Container(
      key: _itemKeyFor(folder.id),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isFocused
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFocused
              ? Colors.white
              : Colors.white.withValues(alpha: 0.08),
          width: isFocused ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isSelected ? const Color(0xFFfb7299) : Colors.white54,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        folder.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (folder.isDefaultFolder)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFfb7299,
                          ).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '默认',
                          style: TextStyle(
                            color: Color(0xFFfb7299),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${folder.mediaCount} 个视频',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 160, vertical: 80),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) => _handleKeyEvent(event),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择收藏夹',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.videoTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_folders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    '当前账号还没有可用收藏夹',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(_folders.length, (index) {
                        return _buildFolderItem(
                          _folders[index],
                          _focusedIndex == index,
                        );
                      }),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _focusedIndex == _saveIndex
                      ? const Color(0xFFfb7299)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _focusedIndex == _saveIndex
                        ? Colors.white
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  _isSaving ? '保存中...' : '保存 (${_selectedIds.length} 个收藏夹)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '上下切换，确定勾选或保存，返回键关闭',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
