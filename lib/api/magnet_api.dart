import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:webfeed/webfeed.dart';
import 'package:flutter/foundation.dart';
import 'dio_client.dart'; // ✨ 引入单例

class MagnetApi {
  static final Dio _dio = DioClient().dio;

  static Future<List<Map<String, String>>> searchTorrents({
    required String keyword,
    required List<Map<String, String>> selectedSources,
    String mustInclude = '',
    String quality = '',
    String exclude = '',
  }) async {
    List<Map<String, String>> allResults = [];

    for (var source in selectedSources) {
      String urlStr = source['url']!.replaceAll('{keyword}', Uri.encodeComponent(keyword));
      
      try {
        // 请求 XML 数据，指定返回 bytes 进行 utf8 解码防止乱码
        final response = await _dio.get(
          urlStr,
          options: Options(responseType: ResponseType.bytes),
        );

        if (response.statusCode == 200) {
          final decodedBody = utf8.decode(response.data);
          final feed = RssFeed.parse(decodedBody);
          
          for (var item in feed.items ?? []) {
            String title = item.title ?? '未知资源文件';
            
            if (mustInclude.isNotEmpty && !title.toLowerCase().contains(mustInclude.toLowerCase())) continue;
            if (quality.isNotEmpty && !title.toLowerCase().contains(quality.toLowerCase())) continue;
            if (exclude.isNotEmpty && title.toLowerCase().contains(exclude.toLowerCase())) continue;

            String magnet = '';
            if (item.enclosure != null && item.enclosure!.url != null) {
              magnet = item.enclosure!.url!;
            } else if (item.link != null && item.link!.startsWith('magnet:')) {
              magnet = item.link!;
            }

            if (magnet.isNotEmpty) {
              allResults.add({
                'title': '[${source['name']}] $title',
                'magnet': magnet,
                'date': item.pubDate?.toString() ?? '未知时间',
              });
            }
          }
        }
      } catch (e) {
        debugPrint('从 ${source['name']} 搜索失败: $e');
      }
    }
    
    return allResults;
  }
}