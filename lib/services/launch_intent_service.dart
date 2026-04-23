import 'dart:async';
import 'package:flutter/services.dart';

enum LaunchActionType { openVideo, openLive, openSearch }

class LaunchAction {
  final LaunchActionType type;
  final String value;

  const LaunchAction({required this.type, required this.value});

  static LaunchAction? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final type = map['type']?.toString();
    final value = map['value']?.toString() ?? '';
    if (value.isEmpty) return null;

    switch (type) {
      case 'video':
        return LaunchAction(type: LaunchActionType.openVideo, value: value);
      case 'live':
        return LaunchAction(type: LaunchActionType.openLive, value: value);
      case 'search':
        return LaunchAction(type: LaunchActionType.openSearch, value: value);
      default:
        return null;
    }
  }
}

class LaunchIntentService {
  static const MethodChannel _channel = MethodChannel('com.bili.tv/launch');
  static final StreamController<LaunchAction> _streamController =
      StreamController<LaunchAction>.broadcast();
  static bool _initialized = false;

  static Stream<LaunchAction> get stream => _streamController.stream;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onLaunchAction') return;
      final action = LaunchAction.fromMap(call.arguments);
      if (action != null) {
        _streamController.add(action);
      }
    });
  }

  static Future<LaunchAction?> consumePendingAction() async {
    await init();
    try {
      final result = await _channel.invokeMethod('consumePendingLaunchAction');
      return LaunchAction.fromMap(result);
    } catch (_) {
      return null;
    }
  }
}
