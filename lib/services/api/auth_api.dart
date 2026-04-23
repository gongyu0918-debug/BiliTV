import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';
import 'sign_utils.dart';
import '../auth_service.dart';

/// 认证相关 API
class AuthApi {
  /// 获取当前登录态快照
  static Future<Map<String, dynamic>> getSessionStatus({
    bool refreshUserInfo = false,
  }) async {
    final result = <String, dynamic>{
      'checkedAt': DateTime.now().toIso8601String(),
      'valid': false,
      'code': null,
      'message': '',
      'isLoggedIn': AuthService.isLoggedIn,
      'data': const <String, dynamic>{},
    };

    try {
      final response = await http.get(
        Uri.parse('${BaseApi.apiBase}/x/web-interface/nav'),
        headers: BaseApi.getHeaders(withCookie: true),
      );

      result['httpStatus'] = response.statusCode;
      if (response.statusCode != 200) {
        result['message'] = 'HTTP ${response.statusCode}';
        return result;
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final data = json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'])
          : <String, dynamic>{};
      final code = json['code'];
      final valid = code == 0;

      result['valid'] = valid;
      result['code'] = code;
      result['message'] = json['message'] ?? '';
      result['data'] = data;

      if (valid && refreshUserInfo) {
        final face = data['face'] as String? ?? '';
        final uname = data['uname'] as String? ?? '';
        final vipData = data['vip'];
        final isVip = vipData != null && vipData['status'] == 1;
        if (face.isNotEmpty || uname.isNotEmpty) {
          await AuthService.saveUserInfo(
            face: face,
            uname: uname,
            isVip: isVip,
          );
        }
      }
    } catch (e) {
      result['message'] = e.toString();
    }

    return result;
  }

  /// 获取用户信息 (头像、昵称等)
  static Future<void> fetchAndSaveUserInfo() async {
    if (!AuthService.isLoggedIn) return;

    try {
      await getSessionStatus(refreshUserInfo: true);
    } catch (e) {
      // 忽略错误
    }
  }

  /// 生成 TV 登录二维码
  static Future<Map<String, String>?> generateTvQrCode() async {
    try {
      final params = SignUtils.signForTvLogin({'local_id': '0'});

      final uri = Uri.parse(
        '${BaseApi.passportBase}/x/passport-tv-login/qrcode/auth_code',
      ).replace(queryParameters: params);

      final response = await http.post(
        uri,
        headers: {
          ...BaseApi.getHeaders(),
          'Accept': 'application/json, text/plain, */*',
          'Origin': 'https://www.bilibili.com',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0 && json['data'] != null) {
          return {
            'url': json['data']['url'] ?? '',
            'auth_code': json['data']['auth_code'] ?? '',
          };
        }
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// 轮询 TV 登录状态
  /// 返回: {'status': 'success'|'waiting'|'scanned'|'expired', 'data': ...}
  static Future<Map<String, dynamic>> pollTvLogin(String authCode) async {
    try {
      final params = SignUtils.signForTvLogin({
        'auth_code': authCode,
        'local_id': '0',
      });

      final uri = Uri.parse(
        '${BaseApi.passportBase}/x/passport-tv-login/qrcode/poll',
      ).replace(queryParameters: params);

      final response = await http.post(
        uri,
        headers: {
          ...BaseApi.getHeaders(),
          'Accept': 'application/json, text/plain, */*',
          'Origin': 'https://www.bilibili.com',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final code = json['code'] ?? -1;

        switch (code) {
          case 0:
            final data = json['data'];
            return {
              'status': 'success',
              'access_token': data['access_token'] ?? '',
              'refresh_token': data['refresh_token'] ?? '',
              'mid': data['mid'] ?? 0,
              'cookie_info': data['cookie_info'],
            };
          case 86039:
            return {'status': 'waiting'};
          case 86090:
            return {'status': 'scanned'};
          case 86038:
            return {'status': 'expired'};
          default:
            return {'status': 'error', 'message': json['message'] ?? ''};
        }
      }
    } catch (e) {
      // ignore
    }
    return {'status': 'error'};
  }
}
