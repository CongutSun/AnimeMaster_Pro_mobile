import '../models/playable_media.dart';
import '../api/webdav_api.dart';
/// 专门用于解析 WebDAV 资源的解析器
class WebDavResolver implements MediaResolver {
  
  @override
  bool canResolve(dynamic sourceData) {
    // 只要传入的数据是一个 Map，并且包含 'webdav_path' 标识，就归我管
    return sourceData is Map && sourceData.containsKey('webdav_path');
  }

  @override
  Future<PlayableMedia> resolve(dynamic sourceData) async {
    if (!canResolve(sourceData)) {
      throw Exception('WebDavResolver 无法解析该格式的数据');
    }

    final path = sourceData['webdav_path'] as String;
    final title = sourceData['title'] as String? ?? '未知视频';

    // 调用已有的 WebDavApi 获取直链和授权请求头
    final streamUrl = WebDavApi().getStreamUrl(path);
    final headers = WebDavApi().getAuthHeaders();

    return PlayableMedia(
      title: title,
      url: streamUrl,
      headers: headers,
      isLocal: false, // 网盘串流，非本地文件
    );
  }
}