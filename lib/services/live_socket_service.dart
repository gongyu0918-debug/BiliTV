import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:brotli/brotli.dart';
import 'api/live_api.dart';
import 'auth_service.dart';

/// 直播弹幕 Socket 服务
class LiveSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  final StreamController<Map<String, dynamic>> _msgController =
      StreamController.broadcast();
  List<dynamic> _hostList = [];
  String _token = '';
  int? _roomId;
  int _hostIndex = 0;
  int _reconnectAttempt = 0;
  bool _manualDisconnect = false;
  int _connectEpoch = 0;

  Stream<Map<String, dynamic>> get messageStream => _msgController.stream;

  void _log(String msg) {
    debugPrint(msg);
  }

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// 连接直播间
  Future<void> connect(int roomId, {bool isReconnect = false}) async {
    final connectEpoch = ++_connectEpoch;
    _manualDisconnect = false;
    _roomId = roomId;
    if (!isReconnect) {
      _reconnectAttempt = 0;
    }
    _reconnectTimer?.cancel();
    _closeSocket();

    try {
      final conf = await LiveApi.getDanmakuConf(roomId);
      if (!_isConnectAttemptActive(connectEpoch, roomId)) {
        return;
      }

      if (conf == null) {
        _emit({'type': 'error', 'msg': '获取弹幕配置失败'});
        _scheduleReconnect(
          '获取弹幕配置失败',
          refetchConfig: true,
          connectEpoch: connectEpoch,
          roomId: roomId,
        );
        return;
      }

      _token = conf['token'] as String? ?? '';
      _hostList = List<dynamic>.from(conf['host_list'] as List? ?? const []);
      if (_hostList.isEmpty) {
        _emit({'type': 'error', 'msg': '弹幕服务器列表为空'});
        _scheduleReconnect(
          '弹幕服务器列表为空',
          refetchConfig: true,
          connectEpoch: connectEpoch,
          roomId: roomId,
        );
        return;
      }

      _hostList.sort((a, b) {
        final aScore = a['wss_port'] != null ? 0 : 1;
        final bScore = b['wss_port'] != null ? 0 : 1;
        return aScore.compareTo(bScore);
      });

      if (!_isConnectAttemptActive(connectEpoch, roomId)) {
        return;
      }

      await _connectWithFailover(connectEpoch, roomId);
    } catch (e) {
      _log('Connect Error: $e');
      _emit({'type': 'error', 'msg': '连接失败: $e'});
      _scheduleReconnect(
        '连接失败: $e',
        refetchConfig: true,
        connectEpoch: connectEpoch,
        roomId: roomId,
      );
    }
  }

  Future<void> _connectWithFailover(int connectEpoch, int roomId) async {
    if (_hostList.isEmpty || !_isConnectAttemptActive(connectEpoch, roomId)) {
      return;
    }

    final hostCount = _hostList.length;
    for (int offset = 0; offset < hostCount; offset++) {
      if (!_isConnectAttemptActive(connectEpoch, roomId)) {
        return;
      }

      final candidateIndex = (_hostIndex + offset) % hostCount;
      final hostInfo = _hostList[candidateIndex];
      final host = hostInfo['host'];
      final port = hostInfo['wss_port'] ?? hostInfo['port'];
      final wssUrl = 'wss://$host:$port/sub';

      _log('🔌 Connecting to Live WS: $wssUrl');

      try {
        final socket = await WebSocket.connect(
          wssUrl,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Origin': 'https://live.bilibili.com',
            'Referer': 'https://live.bilibili.com/',
          },
        );

        if (!_isConnectAttemptActive(connectEpoch, roomId)) {
          await socket.close(status.goingAway);
          return;
        }

        socket.pingInterval = const Duration(seconds: 10);
        _channel = IOWebSocketChannel(socket);
        _hostIndex = candidateIndex;
        _isConnected = true;
        _log('🚀 WS Connected & Channel Ready');

        _channelSubscription = _channel!.stream.listen(
          (message) {
            try {
              _handleMessage(message);
            } catch (e) {
              _log('Message Handle Error: $e');
            }
          },
          onError: (error) {
            _handleSocketFailure('连接中断: $error');
          },
          onDone: () {
            _handleSocketFailure(
              '连接关闭: ${socket.closeCode ?? 0}/${socket.closeReason ?? ''}',
            );
          },
          cancelOnError: true,
        );

        _sendAuth(roomId, _token);
        _startHeartbeat();
        _reconnectAttempt = 0;
        return;
      } catch (e) {
        _log('WS Handshake Error: $e');
      }
    }

    _scheduleReconnect(
      '握手失败',
      refetchConfig: true,
      connectEpoch: connectEpoch,
      roomId: roomId,
    );
  }

  void _handleSocketFailure(String reason) {
    _log(reason);
    _closeSocket();

    if (_manualDisconnect) {
      return;
    }

    if (_hostList.isNotEmpty) {
      _hostIndex = (_hostIndex + 1) % _hostList.length;
    }
    _scheduleReconnect(reason);
  }

  void _scheduleReconnect(
    String reason, {
    bool refetchConfig = false,
    int? connectEpoch,
    int? roomId,
  }) {
    if (_manualDisconnect || _roomId == null) {
      return;
    }

    if (connectEpoch != null && roomId != null) {
      if (!_isConnectAttemptActive(connectEpoch, roomId)) {
        return;
      }
    }

    if (_reconnectTimer?.isActive ?? false) {
      return;
    }

    _reconnectAttempt++;
    final seconds = min(15, max(2, 1 << min(_reconnectAttempt, 4)));
    _emit({'type': 'error', 'msg': '弹幕连接波动，$seconds秒后重连', 'reason': reason});
    _reconnectTimer = Timer(Duration(seconds: seconds), () async {
      if (_manualDisconnect || _roomId == null) {
        return;
      }
      if (connectEpoch != null && roomId != null) {
        if (!_isConnectAttemptActive(connectEpoch, roomId)) {
          return;
        }
      }
      if (refetchConfig) {
        await connect(_roomId!, isReconnect: true);
      } else {
        await _connectWithFailover(_connectEpoch, _roomId!);
      }
    });
  }

  void _emit(Map<String, dynamic> message) {
    if (!_msgController.isClosed) {
      _msgController.add(message);
    }
  }

  void disconnect() {
    _manualDisconnect = true;
    _connectEpoch++;
    _reconnectTimer?.cancel();
    _closeSocket();
  }

  bool _isConnectAttemptActive(int connectEpoch, int roomId) {
    return !_manualDisconnect &&
        _connectEpoch == connectEpoch &&
        _roomId == roomId;
  }

  void _closeSocket() {
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close(status.goingAway);
    _channel = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isConnected = false;
  }

  void _sendAuth(int roomId, String token) {
    final uid = AuthService.isLoggedIn ? (AuthService.mid ?? 0) : 0;
    final buvid = _generateBuvid();

    _log(
      '🔐 Sending Auth (Room: $roomId, UID: $uid, Proto: 2, Buvid: $buvid)...',
    );
    if (token.isEmpty) _log('⚠️ Warning: Token is empty');

    final body = jsonEncode({
      'uid': uid,
      'roomid': roomId,
      'protover': 2,
      'buvid': buvid,
      'platform': 'web',
      'type': 2,
      'key': token,
    });

    _sendPacket(1, 7, utf8.encode(body));
  }

  String _generateBuvid() {
    final random = Random();
    final buf = StringBuffer();
    for (var i = 0; i < 32; i++) {
      final digit = random.nextInt(16);
      buf.write(digit.toRadixString(16).toUpperCase());
    }
    buf.write('infoc');
    return buf.toString();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // 每 30 秒发送一次心跳
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        // Bilibili quirk: server expects "[object Object]" as heartbeat body
        // to return correct popularity. Empty body returns 1.
        _sendPacket(
          1,
          2,
          utf8.encode('[object Object]'),
        ); // Opcode 2 = Heartbeat
        // debugPrint('💓 Heartbeat sent');
      }
    });
  }

  /// 封包并发送
  /// Total Len (4) | Header Len (2) | Proto Ver (2) | Opcode (4) | Seq (4) | Body
  void _sendPacket(int ver, int op, List<int> body) {
    final headerLen = 16;
    final totalLen = headerLen + body.length;
    final buffer = ByteData(totalLen);

    buffer.setUint32(0, totalLen);
    buffer.setUint16(4, headerLen);
    buffer.setUint16(6, ver);
    buffer.setUint32(8, op);
    buffer.setUint32(12, 1); // Seq, always 1

    for (var i = 0; i < body.length; i++) {
      buffer.setUint8(16 + i, body[i]);
    }

    _channel?.sink.add(buffer.buffer.asUint8List());
  }

  /// 处理接收到的二进制数据
  void _handleMessage(dynamic message) {
    if (message is! List<int>) return;

    final data = Uint8List.fromList(message);
    var offset = 0;

    while (offset < data.length) {
      if (data.length - offset < 16) break;

      final view = ByteData.sublistView(data, offset);
      final totalLen = view.getUint32(0);
      final ver = view.getUint16(6);
      final op = view.getUint32(8);

      if (totalLen < 16) break; // Invalid packet

      // Ensure we have the full packet
      if (data.length - offset < totalLen) break;

      final body = data.sublist(offset + 16, offset + totalLen);

      debugPrint('RX: Op=$op Ver=$ver Len=$totalLen'); // Verbose debug

      if (op == 5) {
        // Notification
        if (ver == 0) {
          // JSON Plain Text
          try {
            final jsonStr = utf8.decode(body);
            // debugPrint('JSON: $jsonStr');
            _parseCommand(jsonDecode(jsonStr));
          } catch (e) {
            debugPrint('JSON decode error: $e');
          }
        } else if (ver == 2) {
          // Zlib Compressed
          try {
            final decompressed = zlib.decode(body);
            // debugPrint('Zlib Decompressed: ${decompressed.length}');
            _handleMessage(decompressed); // Recursive parse
          } catch (e) {
            debugPrint('Zlib decode error: $e');
          }
        } else if (ver == 3) {
          // Brotli Compressed
          try {
            final decompressed = brotli.decode(body);
            debugPrint('Brotli Decompressed: ${decompressed.length}');
            _handleMessage(decompressed); // Recursive parse
          } catch (e) {
            debugPrint('Brotli decode error: $e');
          }
        }
      } else if (op == 3) {
        // Heartbeat Reply
        final viewers = ByteData.sublistView(body).getUint32(0);
        // debugPrint('Heartbeat Reply: $viewers');
        _emit({'type': 'popularity', 'count': viewers});
      } else if (op == 8) {
        // Auth Reply
        _log('✅ Live WS Auth Success');
      }

      offset += totalLen;
    }
  }

  void _parseCommand(Map<String, dynamic> json) {
    if (!json.containsKey('cmd')) return;
    final cmd = json['cmd'] as String;
    // _log('CMD: $cmd'); // Enable debug to see traffic

    try {
      if (cmd == 'DANMU_MSG') {
        final info = json['info'] as List;
        final content = info[1] as String;
        final user = info[2] as List;
        final userName = user[1] as String;

        _log('💬 Danmaku: $content');

        // Parse color
        int color = 16777215; // White
        try {
          if (info.isNotEmpty && info[0] is List && info[0].length > 3) {
            color = info[0][3];
          }
        } catch (e) {
          // ignore
        }

        _emit({
          'type': 'danmaku',
          'content': content,
          'user': userName,
          'color': color,
        });
      } else if (cmd == 'SEND_GIFT') {
        // Gift
      } else if (cmd == 'INTERACT_WORD') {
        // Entry / Follow
      }
    } catch (e) {
      _log('Error Parse CMD: $cmd\nData: $json\nError: $e');
    }
  }

  void dispose() {
    disconnect();
    _msgController.close();
  }
}
