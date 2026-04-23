import 'package:bili_tv_app/core/plugin/plugin_manager.dart';
import 'package:bili_tv_app/plugins/ad_filter_plugin.dart';
import 'package:bili_tv_app/plugins/danmaku_enhance_plugin.dart';
import 'package:bili_tv_app/plugins/sponsor_block_plugin.dart';
import 'auth_service.dart';
import 'settings_service.dart';
import 'update_service.dart';

/// 应用启动初始化
class AppBootstrap {
  static Future<void>? _initFuture;
  static bool _pluginsRegistered = false;

  static Future<void> ensureInitialized() {
    _initFuture ??= _initialize();
    return _initFuture!;
  }

  static Future<void> _initialize() async {
    final pluginManager = PluginManager();

    if (!_pluginsRegistered) {
      pluginManager.register(SponsorBlockPlugin());
      pluginManager.register(AdFilterPlugin());
      pluginManager.register(DanmakuEnhancePlugin());
      _pluginsRegistered = true;
    }

    await Future.wait([
      SettingsService.init(),
      AuthService.init(),
      UpdateService.init(),
      pluginManager.init(),
    ]);
  }
}
