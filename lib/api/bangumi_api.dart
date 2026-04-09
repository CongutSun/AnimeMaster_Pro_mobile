import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import 'package:flutter/foundation.dart';
import 'dio_client.dart'; 

class _ApiConfig {
  static const String apiBase = 'https://api.bgm.tv';
  static const String webBase = 'https://bgm.tv';
  static const String chiiBase = 'https://chii.in';
}

class BangumiApi {
  static final Dio _dio = DioClient().dio;

  // 修改部分：增加 start 和 maxResults 参数以支持分页机制
  static Future<List<dynamic>> search(String keyword, {int type = 2, int start = 0, int maxResults = 25}) async {
    try {
      final response = await _dio.get('${_ApiConfig.apiBase}/search/subject/${Uri.encodeComponent(keyword)}?type=$type&start=$start&max_results=$maxResults');
      if (response.statusCode == 200) {
        return response.data['list'] ?? [];
      }
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.search] Exception: $e\n$stackTrace');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getSubjectsByTag(String tag, {int type = 2, int page = 1}) async {
    List<Map<String, dynamic>> results = [];
    try {
      final String typeStr = type == 1 ? 'book' : 'anime';
      final response = await _dio.get(
        '${_ApiConfig.webBase}/$typeStr/tag/${Uri.encodeComponent(tag)}?page=$page',
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.data);
        final document = parser.parse(decodedBody);
        final ul = document.getElementById('browserItemList');
        
        if (ul != null) {
          final items = ul.getElementsByClassName('item').take(24); 
          for (var item in items) {
            final aTag = item.querySelector('a.l');
            if (aTag == null) continue;

            final sid = aTag.attributes['href']?.split('/').last ?? '';
            final name = aTag.text.trim();

            final scoreTag = item.querySelector('small.fade');
            final score = scoreTag != null ? scoreTag.text.trim() : '暂无数据';

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
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.getSubjectsByTag] Exception: $e\n$stackTrace');
    }
    return results;
  }

  static Future<List<dynamic>> getCharacterSubjects(int characterId) async {
    try {
      final response = await _dio.get('${_ApiConfig.apiBase}/v0/characters/$characterId/subjects');
      if (response.statusCode == 200) {
        return response.data ?? [];
      }
    } catch (e) {
      debugPrint('[BangumiApi.getCharacterSubjects] Exception: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getPersonSubjects(int personId) async {
    try {
      final response = await _dio.get('${_ApiConfig.apiBase}/v0/persons/$personId/subjects');
      if (response.statusCode == 200) {
        return response.data ?? [];
      }
    } catch (e) {
      debugPrint('[BangumiApi.getPersonSubjects] Exception: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getCalendar() async {
    try {
      final response = await _dio.get('${_ApiConfig.apiBase}/calendar');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.getCalendar] Exception: $e\n$stackTrace');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getYearTop() async {
    final year = DateTime.now().year;
    List<Map<String, dynamic>> results = [];

    try {
      var response = await _dio.get(
        '${_ApiConfig.webBase}/anime/browser/airtime/$year?sort=rank',
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.statusCode != 200) {
        response = await _dio.get(
          '${_ApiConfig.webBase}/anime/browser?sort=rank',
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
            final score = scoreTag != null ? scoreTag.text.trim() : '暂无数据';

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
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.getYearTop] Exception: $e\n$stackTrace');
    }
    return results;
  }

  static Future<Map<String, dynamic>?> getAnimeDetail(int id) async {
    try {
      final response = await _dio.get('${_ApiConfig.apiBase}/v0/subjects/$id');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.getAnimeDetail] Exception: $e\n$stackTrace');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getUserCollection(int subjectId, String username, String token) async {
    if (username.isEmpty || token.isEmpty) return null;
    
    try {
      final response = await _dio.get(
        '${_ApiConfig.apiBase}/v0/users/$username/collections/$subjectId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) { 
        debugPrint('[BangumiApi.getUserCollection] Request Error: ${e.message}');
      }
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.getUserCollection] Exception: $e\n$stackTrace');
    }
    return null; 
  }

  static Future<List<dynamic>> getUserCollectionList(String username, {int type = 3, int subjectType = 2}) async {
    if (username.isEmpty) return [];
    try {
      final response = await _dio.get('${_ApiConfig.apiBase}/v0/users/$username/collections?subject_type=$subjectType&type=$type&limit=100');
      if (response.statusCode == 200) {
        return response.data['data'] ?? [];
      }
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.getUserCollectionList] Exception: $e\n$stackTrace');
    }
    return [];
  }

  static Future<bool> updateCollection(int subjectId, String token, Map<String, dynamic> postData) async {
    if (token.isEmpty) return false;
    try {
      final response = await _dio.post(
        '${_ApiConfig.apiBase}/v0/users/-/collections/$subjectId',
        data: postData, 
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        }),
      );
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        return true;
      } else {
        debugPrint('[BangumiApi.updateCollection] Failed: Code ${response.statusCode} - Data: ${response.data}');
      }
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.updateCollection] Exception: $e\n$stackTrace');
    }
    return false;
  }

  static Future<bool> updateEpisodeStatus(int subjectId, String token, int epStatus) async {
    if (token.isEmpty) return false;
    try {
      final response = await _dio.post(
        '${_ApiConfig.apiBase}/subject/$subjectId/update/watched_eps', 
        data: {'watched_eps': epStatus.toString()},                 
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          contentType: Headers.formUrlEncodedContentType,           
        ),
      );
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        return true;
      }
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.updateEpisodeStatus] Exception: $e\n$stackTrace');
    }
    return false;
  }

  static Future<List<Map<String, String>>> getSubjectComments(int id) async {
    List<Map<String, String>> comments = [];

    try {
      final response = await _dio.get(
        '${_ApiConfig.chiiBase}/subject/$id',
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.data);
        final document = parser.parse(decodedBody);
        
        final commentBox = document.getElementById('comment_box');
        if (commentBox != null) {
          final items = commentBox.getElementsByClassName('item').take(10); 
          for (var item in items) {
            final author = item.querySelector('.text a')?.text.trim() ?? '网络用户';
            final content = item.querySelector('p')?.text.trim() ?? '';
            
            String rate = '未评级';
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
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.getSubjectComments] Exception: $e\n$stackTrace');
    }
    return comments;
  }

  static Future<List<dynamic>> getSubjectCharacters(int id) async {
    try {
      final response = await _dio.get('${_ApiConfig.apiBase}/v0/subjects/$id/characters');
      if (response.statusCode == 200) {
        return response.data ?? [];
      }
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.getSubjectCharacters] Exception: $e\n$stackTrace');
    }
    return [];
  }

  static Future<List<dynamic>> getSubjectPersons(int id) async {
    try {
      final response = await _dio.get('${_ApiConfig.apiBase}/v0/subjects/$id/persons');
      if (response.statusCode == 200) {
        return response.data ?? [];
      }
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.getSubjectPersons] Exception: $e\n$stackTrace');
    }
    return [];
  }

  static Future<List<dynamic>> getSubjectRelations(int id) async {
    try {
      final response = await _dio.get('${_ApiConfig.apiBase}/v0/subjects/$id/subjects');
      if (response.statusCode == 200) {
        return response.data ?? [];
      }
    } catch (e, stackTrace) {
      debugPrint('[BangumiApi.getSubjectRelations] Exception: $e\n$stackTrace');
    }
    return [];
  }
}