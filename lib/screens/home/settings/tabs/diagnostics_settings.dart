import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../../services/diagnostics_service.dart';
import '../widgets/setting_action_row.dart';

class DiagnosticsSettings extends StatefulWidget {
  final VoidCallback onMoveUp;
  final FocusNode? sidebarFocusNode;

  const DiagnosticsSettings({
    super.key,
    required this.onMoveUp,
    this.sidebarFocusNode,
  });

  @override
  State<DiagnosticsSettings> createState() => _DiagnosticsSettingsState();
}

class _DiagnosticsSettingsState extends State<DiagnosticsSettings> {
  Map<String, dynamic>? _snapshot;
  bool _isRefreshing = false;
  bool _isExporting = false;
  String _lastExportPath = '';
  final FocusNode _refreshFocusNode = FocusNode();
  final FocusNode _exportFocusNode = FocusNode();
  final FocusNode _tvHomeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _refreshDiagnostics();
  }

  @override
  void dispose() {
    _refreshFocusNode.dispose();
    _exportFocusNode.dispose();
    _tvHomeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshDiagnostics() async {
    setState(() => _isRefreshing = true);
    final snapshot = await DiagnosticsService.buildSnapshot(
      refreshSession: true,
    );
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _isRefreshing = false;
    });
  }

  Future<void> _exportDiagnostics() async {
    setState(() => _isExporting = true);
    final path = await DiagnosticsService.exportSnapshot(refreshSession: true);
    if (!mounted) return;
    setState(() {
      _lastExportPath = path;
      _isExporting = false;
    });
    Fluttertoast.showToast(
      msg: '诊断包已导出',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
    );
  }

  String _sessionSummary() {
    final session = _snapshot?['session'] as Map<String, dynamic>?;
    if (session == null) return '尚未检查';
    final valid = session['valid'] == true;
    final code = session['code']?.toString() ?? '-';
    final message = session['message']?.toString() ?? '';
    return '${valid ? '有效' : '异常'} · code=$code${message.isNotEmpty ? ' · $message' : ''}';
  }

  Widget _buildInfoCard(String title, List<String> lines) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _deviceLines() {
    final app = _snapshot?['app'] as Map<String, dynamic>? ?? const {};
    final device = _snapshot?['device'] as Map<String, dynamic>? ?? const {};
    final codecs = (_snapshot?['hardwareDecoders'] as List? ?? const [])
        .map((item) => item.toString())
        .join(', ');
    return [
      '版本: ${app['version'] ?? '-'} (${app['buildNumber'] ?? '-'})',
      '设备: ${device['brand'] ?? '-'} / ${device['model'] ?? '-'} / Android ${device['sdkInt'] ?? '-'}',
      'ABI: ${((device['supportedAbis'] as List?) ?? const []).join(', ')}',
      '硬解: ${codecs.isEmpty ? '未识别' : codecs}',
    ];
  }

  List<String> _apiLines() {
    final api = _snapshot?['api'] as Map<String, dynamic>? ?? const {};
    final wbi = api['wbi'] as Map<String, dynamic>? ?? const {};
    final trace = (api['trace'] as List? ?? const []).cast<Map>().take(4).map((
      entry,
    ) {
      final endpoint = entry['endpointKey'] ?? '-';
      final candidate = entry['candidate'] ?? '-';
      final status = entry['statusCode']?.toString() ?? '-';
      final code = entry['code']?.toString() ?? '-';
      return '$endpoint · $candidate · HTTP$status · code=$code';
    }).toList();
    return [
      'WBI: ${wbi['imgKey'] != null && wbi['subKey'] != null ? '可用' : '缺失'}',
      'WBI更新时间: ${wbi['updatedAt'] ?? '-'}',
      if (trace.isEmpty) '最近请求: 暂无' else ...trace,
    ];
  }

  List<String> _settingsLines() {
    final settings =
        _snapshot?['settings'] as Map<String, dynamic>? ?? const {};
    final storage = _snapshot?['storage'] as Map<String, dynamic>? ?? const {};
    return [
      '自动连播: ${settings['autoPlay'] == true ? '开' : '关'}',
      '迷你进度条: ${settings['showMiniProgress'] == true ? '开' : '关'}',
      '快进预览: ${settings['seekPreviewMode'] == true ? '开' : '关'}',
      '解码器: ${settings['preferredCodec'] ?? '-'} · 渲染: ${settings['preferredRenderMode'] ?? '-'}',
      '缓存: ${(storage['imageCacheSizeMb'] as num?)?.toStringAsFixed(1) ?? '0.0'} MB',
      if (_lastExportPath.isNotEmpty) '最近导出: $_lastExportPath',
    ];
  }

  String _tvHomeSummary() {
    final tvHome = _snapshot?['tvHome'] as Map<String, dynamic>? ?? const {};
    if (tvHome.isEmpty) return '尚未检查';

    final error = tvHome['error']?.toString() ?? '';
    if (error.isNotEmpty) {
      return '诊断失败 · $error';
    }

    final exists = tvHome['previewChannelExists'] == true;
    final previewCount = tvHome['previewProgramCount']?.toString() ?? '0';
    final watchNextCount = tvHome['watchNextProgramCount']?.toString() ?? '0';
    final launcherPackage = tvHome['launcherPackage']?.toString() ?? '-';
    return '${exists ? '频道可用' : '频道缺失'} · 推荐$previewCount · 继续观看$watchNextCount · $launcherPackage';
  }

  List<String> _tvHomeLines() {
    final tvHome = _snapshot?['tvHome'] as Map<String, dynamic>? ?? const {};
    final error = tvHome['error']?.toString() ?? '';
    if (error.isNotEmpty) {
      return ['诊断失败: $error'];
    }

    return [
      '缓存频道ID: ${tvHome['cachedPreviewChannelId'] ?? '-'}',
      '当前频道ID: ${tvHome['resolvedPreviewChannelId'] ?? '-'}',
      '频道数: ${tvHome['previewChannelCount'] ?? 0}',
      '推荐项: ${tvHome['previewProgramCount'] ?? 0}',
      '继续观看: ${tvHome['watchNextProgramCount'] ?? 0}',
      'Launcher: ${tvHome['launcherPackage'] ?? '-'}',
      if ((tvHome['lastError']?.toString() ?? '').isNotEmpty)
        '最近错误: ${tvHome['lastError']}',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final prettyJson = _snapshot == null
        ? ''
        : const JsonEncoder.withIndent('  ').convert(_snapshot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingActionRow(
          label: '刷新登录态与诊断快照',
          value: _sessionSummary(),
          buttonLabel: _isRefreshing ? '刷新中...' : '刷新',
          autofocus: true,
          focusNode: _refreshFocusNode,
          isFirst: true,
          onMoveUp: widget.onMoveUp,
          sidebarFocusNode: widget.sidebarFocusNode,
          onTap: _isRefreshing ? null : _refreshDiagnostics,
        ),
        const SizedBox(height: 16),
        SettingActionRow(
          label: '导出诊断包',
          value: _lastExportPath.isEmpty
              ? '导出到应用文档目录 diagnostics/'
              : _lastExportPath,
          buttonLabel: _isExporting ? '导出中...' : '导出',
          focusNode: _exportFocusNode,
          sidebarFocusNode: widget.sidebarFocusNode,
          onTap: _isExporting ? null : _exportDiagnostics,
        ),
        const SizedBox(height: 16),
        SettingActionRow(
          label: 'TV Home 状态',
          value: _tvHomeSummary(),
          buttonLabel: _isRefreshing ? '刷新中...' : '刷新',
          focusNode: _tvHomeFocusNode,
          isLast: true,
          sidebarFocusNode: widget.sidebarFocusNode,
          onTap: _isRefreshing ? null : _refreshDiagnostics,
        ),
        _buildInfoCard('会话状态', [
          _sessionSummary(),
          'UID: ${_snapshot?['auth']?['mid'] ?? '-'}',
          '昵称: ${_snapshot?['auth']?['uname'] ?? '-'}',
          'SESSDATA: ${_snapshot?['auth']?['hasSessdata'] == true ? '已载入' : '缺失'}',
          'CSRF: ${_snapshot?['auth']?['hasCsrf'] == true ? '已载入' : '缺失'}',
        ]),
        _buildInfoCard('TV Home', _tvHomeLines()),
        _buildInfoCard('设备与解码', _deviceLines()),
        _buildInfoCard('接口与WBI', _apiLines()),
        _buildInfoCard('本地设置与缓存', _settingsLines()),
        if (prettyJson.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 16, bottom: 40),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              prettyJson,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                height: 1.35,
                fontFamily: 'monospace',
              ),
            ),
          ),
      ],
    );
  }
}
