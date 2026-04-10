import 'dart:convert'; // 新增：用于 Base64 编码
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:flutter/foundation.dart';

class WebDavApi {
  static final WebDavApi _instance = WebDavApi._internal();
  factory WebDavApi() => _instance;
  WebDavApi._internal();

  webdav.Client? _client;
  String _currentUrl = '';
  String _currentUser = '';
  String _currentPwd = '';

  void init(String url, String user, String pwd) {
    if (url.isEmpty) return;
    
    _currentUrl = url.endsWith('/') ? url : '$url/';
    _currentUser = user;
    _currentPwd = pwd;

    _client = webdav.newClient(
      _currentUrl,
      user: user,
      password: pwd,
      debug: kDebugMode,
    );
  }

  bool get isConfigured => _client != null && _currentUrl.isNotEmpty;

  Future<List<webdav.File>> listDir(String path) async {
    if (!isConfigured) throw Exception('WebDAV 未配置');
    try {
      String safePath = path.startsWith('/') ? path : '/$path';
      return await _client!.readDir(safePath);
    } catch (e) {
      debugPrint('[WebDavApi.listDir] Error: $e');
      rethrow;
    }
  }

  /// 组装视频的干净 URL（不包含账号密码前缀）
  String getStreamUrl(String filePath) {
    if (!isConfigured) return '';
    try {
      final uri = Uri.parse(_currentUrl); // 例如: http://10.x.x.x:5244/dav/
      
      // 逐段编码路径，防止中文或特殊符号报错
      final encodedSegments = filePath.split('/').map((e) => e.isEmpty ? '' : Uri.encodeComponent(e));
      String safePath = encodedSegments.join('/');

      // 修复 Bug：保留原有的 base path (如 /dav/)
      String fullPath = uri.path;
      if (!fullPath.endsWith('/')) fullPath += '/';
      if (safePath.startsWith('/')) safePath = safePath.substring(1);
      fullPath += safePath;
      
      final streamUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: fullPath.replaceAll('//', '/'),
      );
      
      return streamUri.toString();
    } catch (e) {
      debugPrint('[WebDavApi.getStreamUrl] Error: $e');
      return '';
    }
  }

  /// 新增：生成标准的 HTTP 认证 Header 传给播放器
  Map<String, String> getAuthHeaders() {
    final credentials = base64Encode(utf8.encode('$_currentUser:$_currentPwd'));
    return {
      'Authorization': 'Basic $credentials',
      // 伪装浏览器 UA，防止夸克等网盘的直链被拦截
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };
  }
}