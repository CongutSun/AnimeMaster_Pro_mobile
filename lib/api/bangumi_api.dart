import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import 'package:flutter/foundation.dart';
import 'dio_client.dart'; 

class BangumiApi {
  static final Dio _dio = DioClient().dio;

  static Future<List<dynamic>> search(String keyword) async {
    try {
      final response = await _dio.get('https://api.bgm.tv/search/subject/${Uri.encodeComponent(keyword)}?type=2');
      if (response.statusCode == 200) {
        return response.data['list'] ?? [];
      }
    } catch (e) {
      debugPrint('Search Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getCalendar() async {
    try {
      final response = await _dio.get('https://api.bgm.tv/calendar');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Calendar Error: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getYearTop() async {
    final year = DateTime.now().year;
    List<Map<String, dynamic>> results = [];

    try {
      // ✨ 优化：先尝试获取当年的排行榜，域名统一改为稳定的 bgm.tv
      var response = await _dio.get(
        'https://bgm.tv/anime/browser/airtime/$year?sort=rank',
        options: Options(responseType: ResponseType.bytes),
      );
      
      // ✨ 优化：复用你的 Python 逻辑，如果当年榜单获取失败，回退到总榜！
      if (response.statusCode != 200) {
        response = await _dio.get(
          'https://bgm.tv/anime/browser?sort=rank',
          options: Options(responseType: ResponseType.bytes),
        );
      }

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.data);
        final document = parser.parse(decodedBody);
        final ul = document.getElementById('browserItemList');
        
        if (ul != null) {
          final items = ul.getElementsByClassName('item').take(8);
          for (var item in items) {
            final aTag = item.querySelector('a.l');
            if (aTag == null) continue;

            final sid = aTag.attributes['href']?.split('/').last ?? '';
            final name = aTag.text.trim();

            final scoreTag = item.querySelector('small.fade');
            final score = scoreTag != null ? scoreTag.text.trim() : '暂无';

            final imgTag = item.querySelector('img');
            String imgUrl = '';
            if (imgTag != null && imgTag.attributes.containsKey('src')) {
              imgUrl = imgTag.attributes['src']!.replaceAll('/s/', '/l/');
              if (imgUrl.startsWith('//')) imgUrl = 'https:$imgUrl';
            }

            results.add({
              'id': int.tryParse(sid) ?? sid,
              'name': name,
              'rating': {'score': score},
              'images': {'large': imgUrl}
            });
          }
        }
      }
    } catch (e) {
      debugPrint('YearTop Error: $e');
    }
    return results;
  }

  static Future<Map<String, dynamic>?> getAnimeDetail(int id) async {
    try {
      final response = await _dio.get('https://api.bgm.tv/v0/subjects/$id');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      debugPrint('获取详情失败: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getUserCollection(int subjectId, String username, String token) async {
    if (username.isEmpty || token.isEmpty) return null;
    
    try {
      final response = await _dio.get(
        'https://api.bgm.tv/v0/users/$username/collections/$subjectId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        debugPrint('获取收藏状态失败: $e');
      }
    }
    return null; 
  }

  static Future<List<dynamic>> getUserCollectionList(String username, {int type = 3}) async {
    if (username.isEmpty) return [];
    try {
      final response = await _dio.get('https://api.bgm.tv/v0/users/$username/collections?subject_type=2&type=$type&limit=100');
      if (response.statusCode == 200) {
        return response.data['data'] ?? [];
      }
    } catch (e) {
      debugPrint('获取追番列表失败: $e');
    }
    return [];
  }

  static Future<bool> updateCollection(int subjectId, String token, Map<String, dynamic> postData) async {
    if (token.isEmpty) return false;

    try {
      final response = await _dio.post(
        'https://api.bgm.tv/v0/users/-/collections/$subjectId',
        data: postData, 
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        return true;
      } else {
        debugPrint('同步失败，服务器返回: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      debugPrint('同步网络异常: $e');
    }
    return false;
  }

  // ✨ 终极修复：照搬你 Python 里的 update_ep_progress 逻辑，完美避开 400 错误！
  static Future<bool> updateEpisodeStatus(int subjectId, String token, int epStatus) async {
    if (token.isEmpty) return false;
    try {
      final response = await _dio.post(
        'https://api.bgm.tv/subject/$subjectId/update/watched_eps', // 使用旧版专用进度接口
        data: {'watched_eps': epStatus.toString()},                 // 传入 watched_eps
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          contentType: Headers.formUrlEncodedContentType,           // ✨ 必须使用表单格式提交！
        ),
      );
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        return true;
      }
    } catch (e) {
      debugPrint('更新进度异常: $e');
    }
    return false;
  }

  static Future<List<Map<String, String>>> getSubjectComments(int id) async {
    List<Map<String, String>> comments = [];

    try {
      final response = await _dio.get(
        'https://chii.in/subject/$id',
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.data);
        final document = parser.parse(decodedBody);
        
        final commentBox = document.getElementById('comment_box');
        if (commentBox != null) {
          final items = commentBox.getElementsByClassName('item').take(10); 
          for (var item in items) {
            final author = item.querySelector('.text a')?.text.trim() ?? '匿名网友';
            final content = item.querySelector('p')?.text.trim() ?? '';
            
            String rate = '未打分';
            final starSpan = item.querySelector('.text span.starlight');
            if (starSpan != null) {
              final cls = starSpan.attributes['class'] ?? '';
              final match = RegExp(r'stars(\d+)').firstMatch(cls);
              if (match != null) {
                rate = '${match.group(1)}分';
              }
            }

            if (content.isNotEmpty) {
              comments.add({
                'author': author,
                'rate': rate,
                'content': content,
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('获取热评失败: $e');
    }
    return comments;
  }
}