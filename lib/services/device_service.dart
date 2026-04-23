import 'package:flutter/services.dart';

/// 设备信息服务
class DeviceService {
  static const _channel = MethodChannel('com.bili.tv/codec');
  static Map<String, dynamic>? _deviceInfo;

  static Future<Map<String, dynamic>> getDeviceInfo() async {
    if (_deviceInfo != null) {
      return _deviceInfo!;
    }

    try {
      final result = await _channel.invokeMethod('getDeviceInfo');
      _deviceInfo = Map<String, dynamic>.from(result ?? const {});
    } catch (_) {
      _deviceInfo = <String, dynamic>{};
    }

    return _deviceInfo!;
  }

  static Future<List<String>> getSupportedAbis() async {
    final info = await getDeviceInfo();
    final abis = info['supportedAbis'];
    if (abis is List) {
      return abis.map((item) => item.toString()).toList();
    }
    return const [];
  }
}
