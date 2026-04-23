import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../widgets/settings_panel.dart';
import '../focus/player_focus_handler.dart';
import 'player_action_mixin.dart';

/// 播放器按键事件 Mixin
mixin PlayerEventMixin on PlayerActionMixin {
  void onPopInvoked(bool didPop, dynamic result) {
    if (didPop) return;

    // 检查是否返回键已经被 handleGlobalKeyEvent 处理过
    if (backKeyJustHandled) {
      backKeyJustHandled = false;
      return;
    }

    if (showSettingsPanel) {
      if (settingsMenuType != SettingsMenuType.main) {
        setState(() {
          settingsMenuType = SettingsMenuType.main;
          focusedSettingIndex = 0;
        });
        return;
      }
      setState(() {
        showSettingsPanel = false;
        showControls = true;
      });
      startHideTimer();
      return;
    }

    if (showEpisodePanel) {
      setState(() {
        showEpisodePanel = false;
        showControls = true;
      });
      startHideTimer();
      return;
    }

    // 关闭 UP主面板
    if (showUpPanel) {
      setState(() {
        showUpPanel = false;
        showControls = true;
      });
      startHideTimer();
      return;
    }

    // 关闭更多视频面板
    if (showRelatedPanel) {
      setState(() {
        showRelatedPanel = false;
        showControls = true;
      });
      startHideTimer();
      return;
    }

    if (showChapterPanel) {
      setState(() {
        showChapterPanel = false;
        showControls = true;
      });
      startHideTimer();
      return;
    }

    if (showCommentPanel) {
      setState(() {
        showCommentPanel = false;
        showControls = true;
      });
      startHideTimer();
      return;
    }

    if (showActionButtons) {
      setState(() => showActionButtons = false);
      startHideTimer();
      return;
    }

    // 预览模式下按返回键取消预览
    if (isSeekPreviewMode) {
      cancelPreviewSeek();
      return;
    }

    // 控制栏显示时按返回键隐藏控制栏
    if (showControls) {
      setState(() => showControls = false);
      return;
    }

    final now = DateTime.now();
    if (lastBackPressed == null ||
        now.difference(lastBackPressed!) > const Duration(seconds: 2)) {
      lastBackPressed = now;
      Fluttertoast.showToast(
        msg: '再按一次返回键退出播放',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        textColor: Colors.white,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  KeyEventResult handleGlobalKeyEvent(FocusNode node, KeyEvent event) {
    // 处理 KeyUpEvent - 松开左右键时提交进度
    if (event is KeyUpEvent) {
      if (isProgressBarFocused && previewPosition != null) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight) {
          commitProgress();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    // 只处理 KeyDownEvent 和 KeyRepeatEvent
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // 设置面板
    if (showSettingsPanel) {
      if (PlayerFocusHandler.isBackKey(event) && event is KeyDownEvent) {
        backKeyJustHandled = true;
        if (settingsMenuType != SettingsMenuType.main) {
          setState(() {
            settingsMenuType = SettingsMenuType.main;
            focusedSettingIndex = 0;
          });
        } else {
          setState(() {
            showSettingsPanel = false;
            showControls = true;
          });
          startHideTimer();
        }
        return KeyEventResult.handled;
      }
      final result = handleSettingsKeyEvent(event);
      if (result == KeyEventResult.handled) {
        if (!showControls) setState(() => showControls = true);
        return KeyEventResult.handled;
      }
    }

    // 选集面板 - 使用 PlayerFocusHandler
    if (showEpisodePanel) {
      if (PlayerFocusHandler.isBackKey(event) && event is KeyDownEvent) {
        backKeyJustHandled = true;
        _closeEpisodePanel();
        return KeyEventResult.handled;
      }
      final result = handleEpisodeKeyEvent(event);
      if (result == KeyEventResult.handled) {
        if (!showControls) setState(() => showControls = true);
        return KeyEventResult.handled;
      }
    }

    // UP主面板返回处理
    if (showUpPanel) {
      if (PlayerFocusHandler.isBackKey(event) && event is KeyDownEvent) {
        backKeyJustHandled = true;
        setState(() {
          showUpPanel = false;
          showControls = true;
        });
        startHideTimer();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // 相关视频面板返回处理
    if (showRelatedPanel) {
      if (PlayerFocusHandler.isBackKey(event) && event is KeyDownEvent) {
        backKeyJustHandled = true;
        setState(() {
          showRelatedPanel = false;
          showControls = true;
        });
        startHideTimer();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (showChapterPanel) {
      if (PlayerFocusHandler.isBackKey(event) && event is KeyDownEvent) {
        backKeyJustHandled = true;
        setState(() {
          showChapterPanel = false;
          showControls = true;
        });
        startHideTimer();
        return KeyEventResult.handled;
      }
      return _handleChapterPanelKeyEvent(event);
    }

    if (showCommentPanel) {
      if (PlayerFocusHandler.isBackKey(event) && event is KeyDownEvent) {
        backKeyJustHandled = true;
        setState(() {
          showCommentPanel = false;
          showControls = true;
        });
        startHideTimer();
        return KeyEventResult.handled;
      }
      return _handleCommentPanelKeyEvent(event);
    }

    // 点赞/投币/收藏按钮返回处理
    if (showActionButtons) {
      if (PlayerFocusHandler.isBackKey(event) && event is KeyDownEvent) {
        backKeyJustHandled = true;
        setState(() => showActionButtons = false);
        startHideTimer();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // 控制栏显示时
    if (showControls) {
      return _handleControlsVisibleKeyEvent(event);
    } else {
      // 控制栏隐藏时
      return _handleControlsHiddenKeyEvent(event);
    }
  }

  /// 控制栏显示时的按键处理
  KeyEventResult _handleControlsVisibleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // 使用 PlayerFocusHandler 处理控制栏导航
    final nav = PlayerFocusHandler.handleControlsNavigation(
      event,
      currentIndex: focusedButtonIndex,
      maxIndex: 6,
      onSelect: _activateControlButton,
      onHide: () => setState(() => showControls = false),
    );

    if (nav.result == KeyEventResult.handled) {
      if (nav.newIndex != focusedButtonIndex) {
        setState(() => focusedButtonIndex = nav.newIndex);
        startHideTimer();
      }
      return KeyEventResult.handled;
    }

    // 返回键隐藏控制栏
    if (PlayerFocusHandler.isBackKey(event)) {
      if (event.logicalKey != LogicalKeyboardKey.escape) {
        backKeyJustHandled = true;
      }
      setState(() => showControls = false);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 激活控制栏按钮
  void _activateControlButton(int index) {
    switch (index) {
      case 0: // 选集
        setState(() {
          showEpisodePanel = true;
          hideTimer?.cancel();
        });
        break;
      case 1: // 章节
        openChapterPanel();
        break;
      case 2: // UP主
        setState(() {
          showUpPanel = true;
          hideTimer?.cancel();
        });
        break;
      case 3: // 更多视频
        setState(() {
          showRelatedPanel = true;
          hideTimer?.cancel();
        });
        break;
      case 4: // 评论
        setState(() {
          showCommentPanel = true;
          hideTimer?.cancel();
        });
        if (comments.isEmpty && !commentsLoading) {
          loadComments(reset: true);
        }
        break;
      case 5: // 设置
        setState(() {
          showSettingsPanel = true;
          hideTimer?.cancel();
        });
        break;
      case 6: // 点赞/投币/收藏
        setState(() {
          showActionButtons = !showActionButtons;
        });
        break;
    }
  }

  /// 控制栏隐藏时的按键处理
  KeyEventResult _handleControlsHiddenKeyEvent(KeyEvent event) {
    // 如果处于预览模式，使用 PlayerFocusHandler 处理
    if (isSeekPreviewMode && previewPosition != null) {
      final result = PlayerFocusHandler.handleSeekPreviewNavigation(
        event,
        onSeekBackward: seekPreviewBackward,
        onSeekForward: seekPreviewForward,
        onConfirm: confirmPreviewSeek,
        onCancel: () {
          if (event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.browserBack) {
            backKeyJustHandled = true;
          }
          cancelPreviewSeek();
        },
      );
      if (result == KeyEventResult.handled) {
        return KeyEventResult.handled;
      }
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // 上下键显示控制栏
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      toggleControls();
      return KeyEventResult.handled;
    }

    // 确认键播放/暂停
    if (PlayerFocusHandler.isSelectKey(event) && event is KeyDownEvent) {
      togglePlayPause();
      return KeyEventResult.handled;
    }

    // 左右键快退/快进 (支持按住重复触发)
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      seekBackward();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      seekForward();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 关闭选集面板
  void _closeEpisodePanel() {
    setState(() {
      showEpisodePanel = false;
      showControls = true;
    });
    startHideTimer();
  }

  /// 选集面板按键处理 - 使用 PlayerFocusHandler
  KeyEventResult handleEpisodeKeyEvent(KeyEvent event) {
    // 支持长按连续移动 (KeyRepeatEvent)
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final nav = PlayerFocusHandler.handleEpisodePanelNavigation(
      event,
      currentIndex: focusedEpisodeIndex,
      maxIndex: episodes.length - 1,
      onSelect: () {
        if (episodes.isNotEmpty) {
          switchEpisode(episodes[focusedEpisodeIndex]['cid']);
        }
      },
      onClose: _closeEpisodePanel,
    );

    if (nav.result == KeyEventResult.handled) {
      if (nav.newIndex != focusedEpisodeIndex) {
        setState(() => focusedEpisodeIndex = nav.newIndex);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 设置面板按键处理 - 保持原有逻辑（有子菜单特殊处理）
  KeyEventResult handleSettingsKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    int maxIndex = _getSettingsMaxIndex();

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        focusedSettingIndex = (focusedSettingIndex - 1).clamp(0, maxIndex);
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        focusedSettingIndex = (focusedSettingIndex + 1).clamp(0, maxIndex);
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (settingsMenuType == SettingsMenuType.main) {
        setState(() {
          showSettingsPanel = false;
          showControls = true;
        });
        startHideTimer();
      } else if (settingsMenuType == SettingsMenuType.subtitle) {
        setState(() => settingsMenuType = SettingsMenuType.main);
      } else if (settingsMenuType == SettingsMenuType.danmaku) {
        adjustDanmakuSetting(-1);
      } else if (settingsMenuType == SettingsMenuType.speed) {
        setState(() => settingsMenuType = SettingsMenuType.main);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (settingsMenuType == SettingsMenuType.main) {
        if (focusedSettingIndex == 1) {
          setState(() {
            settingsMenuType = SettingsMenuType.subtitle;
            focusedSettingIndex = 0;
          });
        } else if (focusedSettingIndex == 2) {
          setState(() {
            settingsMenuType = SettingsMenuType.danmaku;
            focusedSettingIndex = 0;
          });
        } else if (focusedSettingIndex == 3) {
          setState(() {
            settingsMenuType = SettingsMenuType.speed;
            focusedSettingIndex = 0;
          });
        }
      } else if (settingsMenuType == SettingsMenuType.subtitle) {
        activateSetting();
      } else if (settingsMenuType == SettingsMenuType.danmaku) {
        adjustDanmakuSetting(1);
      }
      return KeyEventResult.handled;
    }

    if (PlayerFocusHandler.isSelectKey(event)) {
      activateSetting();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (settingsMenuType == SettingsMenuType.main) {
        setState(() {
          showSettingsPanel = false;
          showControls = true;
        });
        startHideTimer();
      } else {
        setState(() {
          settingsMenuType = SettingsMenuType.main;
          focusedSettingIndex = 0;
        });
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 获取当前设置菜单的最大索引
  int _getSettingsMaxIndex() {
    switch (settingsMenuType) {
      case SettingsMenuType.main:
        return 3;
      case SettingsMenuType.subtitle:
        return 2;
      case SettingsMenuType.danmaku:
        return 7;
      case SettingsMenuType.speed:
        return availableSpeeds.length - 1;
      default:
        return 0;
    }
  }

  KeyEventResult _handleChapterPanelKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (chapters.isEmpty) return KeyEventResult.handled;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(
        () => focusedChapterIndex = (focusedChapterIndex - 1).clamp(
          0,
          chapters.length - 1,
        ),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(
        () => focusedChapterIndex = (focusedChapterIndex + 1).clamp(
          0,
          chapters.length - 1,
        ),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        showChapterPanel = false;
        showControls = true;
      });
      startHideTimer();
      return KeyEventResult.handled;
    }
    if (PlayerFocusHandler.isSelectKey(event)) {
      final chapter =
          chapters[focusedChapterIndex.clamp(0, chapters.length - 1)];
      debugPrint(
        'Player: selectChapter index=$focusedChapterIndex from=${chapter.from.inSeconds}',
      );
      videoController?.seekTo(chapter.from);
      resetDanmakuIndex(chapter.from);
      setState(() {
        showChapterPanel = false;
        showControls = true;
      });
      startHideTimer();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleCommentPanelKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (comments.isEmpty) {
      if (!commentsLoading && commentsHasMore) {
        loadComments(reset: true);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(
        () => focusedCommentIndex = (focusedCommentIndex - 1).clamp(
          0,
          comments.length - 1,
        ),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final nextIndex = (focusedCommentIndex + 1).clamp(0, comments.length - 1);
      setState(() => focusedCommentIndex = nextIndex);
      if (nextIndex >= comments.length - 3 &&
          commentsHasMore &&
          !commentsLoading) {
        loadComments();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        showCommentPanel = false;
        showControls = true;
      });
      startHideTimer();
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }
}
