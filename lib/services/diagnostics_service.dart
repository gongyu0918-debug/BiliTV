import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'api/base_api.dart';
import 'auth_service.dart';
import 'codec_service.dart';
import 'device_service.dart';
import 'session_watchdog.dart';
import 'settings_service.dart';
import 'tv_home_service.dart';

class DiagnosticsService {
  static Future<Map<String, dynamic>> buildSnapshot({
    bool refreshSession = false,
  }) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = await DeviceService.getDeviceInfo();
    final hardwareDecoders = await CodecService.getHardwareDecoders();
    final cacheSizeMb = await SettingsService.getImageCacheSizeMB();
    final session = refreshSession
        ? await SessionWatchdog.checkNow()
        : (SessionWatchdog.lastSnapshot ?? await SessionWatchdog.checkNow());

    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'app': {
        'packageName': packageInfo.packageName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
      },
      'auth': {
        'isLoggedIn': AuthService.isLoggedIn,
        'mid': AuthService.mid,
        'uname': AuthService.uname,
        'hasSessdata': AuthService.sessdata?.isNotEmpty ?? false,
        'hasCsrf': AuthService.biliJct?.isNotEmpty ?? false,
        'isVip': AuthService.isVip,
      },
      'session': session,
      'device': deviceInfo,
      'hardwareDecoders': hardwareDecoders,
      'settings': {
        'autoPlay': SettingsService.autoPlay,
        'showMiniProgress': SettingsService.showMiniProgress,
        'hideControlsOnStart': SettingsService.hideControlsOnStart,
        'hideLiveControlsOnStart': SettingsService.hideLiveControlsOnStart,
        'alwaysShowPlayerTime': SettingsService.alwaysShowPlayerTime,
        'seekPreviewMode': SettingsService.seekPreviewMode,
        'preferredCodec': SettingsService.preferredCodec.name,
        'preferredRenderMode': SettingsService.preferredRenderMode.name,
      },
      'storage': {'imageCacheSizeMb': cacheSizeMb},
      'api': BaseApi.buildDiagnosticsSnapshot(),
      'tvHome': await TvHomeService.getDebugState(),
    };
  }

  static Future<String> exportSnapshot({bool refreshSession = true}) async {
    final snapshot = await buildSnapshot(refreshSession: refreshSession);
    final docsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(
      '${docsDir.path}${Platform.pathSeparator}diagnostics',
    );
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final file = File(
      '${exportDir.path}${Platform.pathSeparator}bilitv_diagnostics_$timestamp.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot),
    );
    return file.path;
  }
}
