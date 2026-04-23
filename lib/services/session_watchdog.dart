import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api/auth_api.dart';
import 'auth_service.dart';

class SessionWatchdog {
  static Timer? _timer;
  static Map<String, dynamic>? _lastSnapshot;
  static bool _isChecking = false;

  static Map<String, dynamic>? get lastSnapshot => _lastSnapshot;

  static void start({Duration interval = const Duration(minutes: 12)}) {
    if (_timer != null) return;

    _timer = Timer.periodic(interval, (_) {
      unawaited(checkNow());
    });

    if (AuthService.isLoggedIn) {
      unawaited(checkNow());
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<Map<String, dynamic>> checkNow() async {
    if (_isChecking) {
      return _lastSnapshot ??
          <String, dynamic>{
            'valid': false,
            'message': 'session-check-in-progress',
            'checkedAt': DateTime.now().toIso8601String(),
          };
    }

    _isChecking = true;
    try {
      final snapshot = await AuthApi.getSessionStatus(refreshUserInfo: true);
      _lastSnapshot = snapshot;
      final httpStatus = snapshot['httpStatus'] as int?;
      final code = snapshot['code'] as int?;
      if (AuthService.isLoggedIn && httpStatus == 200 && code == -101) {
        await AuthService.invalidateSession(
          reason: snapshot['message']?.toString(),
          code: code,
        );
      }
      debugPrint(
        '[SessionWatchdog] valid=${snapshot['valid']} code=${snapshot['code']} message=${snapshot['message']}',
      );
      return snapshot;
    } finally {
      _isChecking = false;
    }
  }
}
