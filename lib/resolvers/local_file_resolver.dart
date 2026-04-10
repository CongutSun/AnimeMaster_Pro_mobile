import '../models/playable_media.dart';

class LocalFileResolver implements MediaResolver {
  @override
  bool canResolve(dynamic sourceData) {
    return sourceData is Map && sourceData.containsKey('local_path');
  }

  @override
  Future<PlayableMedia> resolve(dynamic sourceData) async {
    if (!canResolve(sourceData)) {
      throw Exception('LocalFileResolver 无法解析');
    }

    // media_kit 可以直接将本地绝对路径作为 url 播放
    return PlayableMedia(
      title: sourceData['title'] ?? '本地视频',
      url: sourceData['local_path'],
      isLocal: true, // 核心：打上本地标签
    );
  }
}