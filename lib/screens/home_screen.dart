import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:bili_tv_app/models/video.dart';
import 'home/home_tab.dart';
import 'home/history_tab.dart';
import 'home/search_tab.dart';
import 'home/login_tab.dart';
import 'home/dynamic_tab.dart';
import 'home/watch_later_tab.dart';
import 'home/favorites_tab.dart';
import 'home/live_tab.dart';
import '../widgets/tv_focusable_item.dart';
import '../services/auth_service.dart';
import '../services/bilibili_api.dart';
import '../services/launch_intent_service.dart';
import '../services/settings_service.dart';
import 'player/player_screen.dart';
import 'live/live_player_screen.dart';

/// 主页框架 - 完全按照 animeone_tv_app 的方式
class HomeScreen extends StatefulWidget {
  final List<Video>? preloadedVideos;

  const HomeScreen({super.key, this.preloadedVideos});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 1; // 默认选中首页
  DateTime? _lastBackPressed;
  DateTime? _backFromSearchHandled; // 防止搜索键盘返回键重复处理
  StreamSubscription<LaunchAction>? _launchActionSubscription;

  // Tab 顺序: 搜索、首页、动态、历史、稍后再看、收藏夹、直播、登录
  final List<String> _tabIcons = [
    'assets/icons/search.svg',
    'assets/icons/home.svg',
    'assets/icons/dynamic.svg',
    'assets/icons/history.svg',
    'assets/icons/watch_later.svg',
    'assets/icons/favorite.svg',
    'assets/icons/live.svg', // 新增直播图标
    'assets/icons/user.svg',
  ];

  late List<FocusNode> _sideBarFocusNodes;

  // 用于访问 SearchTab 状态
  final GlobalKey<SearchTabState> _searchTabKey = GlobalKey<SearchTabState>();
  // 用于访问 HomeTab 状态 (刷新功能)
  final GlobalKey<HomeTabState> _homeTabKey = GlobalKey<HomeTabState>();
  // 动态和历史记录 Tab - 每次切换时刷新
  final GlobalKey<DynamicTabState> _dynamicTabKey =
      GlobalKey<DynamicTabState>();
  final GlobalKey<HistoryTabState> _historyTabKey =
      GlobalKey<HistoryTabState>();
  final GlobalKey<WatchLaterTabState> _watchLaterTabKey =
      GlobalKey<WatchLaterTabState>();
  final GlobalKey<FavoritesTabState> _favoritesTabKey =
      GlobalKey<FavoritesTabState>();
  final GlobalKey<LoginTabState> _loginTabKey = GlobalKey<LoginTabState>();
  // 直播 Tab
  final GlobalKey<LiveTabState> _liveTabKey = GlobalKey<LiveTabState>();

  @override
  void initState() {
    super.initState();
    AuthService.addListener(_handleAuthStateChanged);
    _sideBarFocusNodes = List.generate(
      _tabIcons.length,
      (index) => FocusNode(),
    );

    // 可以在这里做一些初始化，但不再强制请求 sidebar 焦点
    // 而是等待 HomeTab 加载完成后请求内容焦点
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 确保 Highlight 策略正确
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    });

    _initLaunchActions();
  }

  // 激活焦点系统
  void _activateFocusSystem() {
    if (!mounted) return;

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    final currentFocusNode = _sideBarFocusNodes[_selectedTabIndex];
    if (!currentFocusNode.hasFocus) {
      currentFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    AuthService.removeListener(_handleAuthStateChanged);
    _launchActionSubscription?.cancel();
    for (var node in _sideBarFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _initLaunchActions() async {
    await LaunchIntentService.init();
    _launchActionSubscription = LaunchIntentService.stream.listen(
      _handleLaunchAction,
    );
    final pending = await LaunchIntentService.consumePendingAction();
    if (pending != null && mounted) {
      _handleLaunchAction(pending);
    }
  }

  void _handleAuthStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleLaunchAction(LaunchAction action) async {
    if (!mounted) return;

    switch (action.type) {
      case LaunchActionType.openSearch:
        setState(() => _selectedTabIndex = 0);
        _sideBarFocusNodes[0].requestFocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchTabKey.currentState?.openSearch(action.value);
        });
        break;
      case LaunchActionType.openVideo:
        final video = await BilibiliApi.getVideoByBvid(action.value);
        if (!mounted || video == null) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => PlayerScreen(video: video)));
        break;
      case LaunchActionType.openLive:
        final roomId = int.tryParse(action.value);
        if (!mounted || roomId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LivePlayerScreen(roomId: roomId, title: '直播间'),
          ),
        );
        break;
    }
  }

  void _handleSideBarTap(int index) {
    // 如果已经在当前标签，点击刷新
    if (index == _selectedTabIndex) {
      if (index == 1) {
        _homeTabKey.currentState?.refreshCurrentCategory();
      } else if (index == 2) {
        _dynamicTabKey.currentState?.refresh();
      } else if (index == 3) {
        _historyTabKey.currentState?.refresh();
      } else if (index == 4) {
        _watchLaterTabKey.currentState?.refresh();
      } else if (index == 5) {
        _favoritesTabKey.currentState?.refresh();
      } else if (index == 6) {
        _liveTabKey.currentState?.refresh();
      }
      return;
    }

    setState(() => _selectedTabIndex = index);
    _sideBarFocusNodes[index].requestFocus();

    // 动态和历史记录、直播标签: 切换时也刷新
    if (index == 2) {
      _dynamicTabKey.currentState?.refresh();
    } else if (index == 3) {
      _historyTabKey.currentState?.refresh();
    } else if (index == 4) {
      _watchLaterTabKey.currentState?.refresh();
    } else if (index == 5) {
      _favoritesTabKey.currentState?.refresh();
    } else if (index == 6) {
      _liveTabKey.currentState?.refresh();
    }
  }

  void _refreshCurrentTab() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 检查是否刚刚被搜索键盘的返回键处理过
        if (_backFromSearchHandled != null &&
            DateTime.now().difference(_backFromSearchHandled!) <
                const Duration(milliseconds: 200)) {
          return; // 已被处理，忽略
        }

        // 只有在主页标签 (index=1) 才显示退出提示
        // 搜索标签需要特殊处理：结果界面返回键盘，键盘返回主页
        if (_selectedTabIndex == 0) {
          // 搜索标签
          final handled = _searchTabKey.currentState?.handleBack() ?? false;
          if (!handled) {
            // 键盘界面 → 回主页
            setState(() => _selectedTabIndex = 1);
            _sideBarFocusNodes[1].requestFocus();
          }
          return;
        }

        if (_selectedTabIndex != 1) {
          // 其他标签按返回键都回到主页
          setState(() => _selectedTabIndex = 1);
          _sideBarFocusNodes[1].requestFocus();
          return;
        }

        // 主页标签：按两次退出
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;

          Fluttertoast.showToast(
            msg: '再按一次返回键退出应用',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            textColor: Colors.white,
            fontSize: 18.0,
          );
        } else {
          // 退出前清理缓存
          await SettingsService.clearImageCache();
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧边栏
            Expanded(
              flex: 8,
              child: Container(
                color: const Color(0xFF1E1E1E),
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(_tabIcons.length, (index) {
                    final isUserTab = index == 7;
                    final avatarUrl = isUserTab && AuthService.isLoggedIn
                        ? AuthService.face
                        : null;

                    return TvFocusableItem(
                      iconPath: _tabIcons[index],
                      avatarUrl: avatarUrl,
                      isSelected: _selectedTabIndex == index,
                      focusNode: _sideBarFocusNodes[index],
                      onFocus: () {
                        // 焦点移动时只切换标签页，不刷新任何内容
                        setState(() => _selectedTabIndex = index);
                      },
                      onTap: () => _handleSideBarTap(index), // 按确定键才刷新
                      // 用户标签按右键导航到设置分类标签
                      onMoveRight: index == 6
                          ? () {
                              _liveTabKey.currentState?.focusFirstItem();
                            }
                          : isUserTab && AuthService.isLoggedIn
                          ? () =>
                                _loginTabKey.currentState?.focusFirstCategory()
                          : null,
                    );
                  }),
                ),
              ),
            ),
            // 右侧内容区
            Expanded(flex: 92, child: _buildRightContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildRightContent() {
    // 使用 IndexedStack 保持所有 Tab 状态，避免切换时重新加载
    return IndexedStack(
      index: _selectedTabIndex,
      children: [
        // 0: 搜索
        SearchTab(
          key: _searchTabKey,
          sidebarFocusNode: _sideBarFocusNodes[0],
          onBackToHome: () {
            _backFromSearchHandled = DateTime.now(); // 记录处理时间
            setState(() => _selectedTabIndex = 1);
            _sideBarFocusNodes[1].requestFocus();
          },
        ),
        // 1: 首页
        HomeTab(
          key: _homeTabKey,
          sidebarFocusNode: _sideBarFocusNodes[1],
          onFirstLoadComplete: _activateFocusSystem,
          preloadedVideos: widget.preloadedVideos,
        ),
        // 2: 动态
        DynamicTab(
          key: _dynamicTabKey,
          sidebarFocusNode: _sideBarFocusNodes[2],
          isVisible: _selectedTabIndex == 2,
        ),
        // 3: 历史
        HistoryTab(
          key: _historyTabKey,
          sidebarFocusNode: _sideBarFocusNodes[3],
          isVisible: _selectedTabIndex == 3,
        ),
        // 4: 稍后再看
        WatchLaterTab(
          key: _watchLaterTabKey,
          sidebarFocusNode: _sideBarFocusNodes[4],
          isVisible: _selectedTabIndex == 4,
        ),
        // 5: 收藏夹
        FavoritesTab(
          key: _favoritesTabKey,
          sidebarFocusNode: _sideBarFocusNodes[5],
          isVisible: _selectedTabIndex == 5,
        ),
        // 6: 直播
        LiveTab(
          key: _liveTabKey,
          sidebarFocusNode: _sideBarFocusNodes[6],
          isVisible: _selectedTabIndex == 6,
        ),
        // 7: 登录/用户
        LoginTab(
          key: _loginTabKey,
          sidebarFocusNode: _sideBarFocusNodes[7],
          onLoginSuccess: _refreshCurrentTab,
        ),
      ],
    );
  }
}
