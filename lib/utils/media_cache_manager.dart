import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheTask {
  final String id;
  final String title;
  final String url;
  final String localPath;
  double progress;
  int status; // 0: 下载中, 1: 已完成, 2: 下载失败

  CacheTask({
    required this.id,
    required this.title,
    required this.url,
    required this.localPath,
    this.progress = 0.0,
    this.status = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'localPath': localPath,
    'progress': progress,
    'status': status,
  };

  factory CacheTask.fromJson(Map<String, dynamic> json) => CacheTask(
    id: json['id'],
    title: json['title'],
    url: json['url'],
    localPath: json['localPath'],
    progress: json['progress'],
    status: json['status'],
  );
}

class MediaCacheManager extends ChangeNotifier {
  static final MediaCacheManager _instance = MediaCacheManager._internal();
  factory MediaCacheManager() => _instance;
  MediaCacheManager._internal();

  List<CacheTask> tasks = [];
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};
  bool _isInitialized = false;

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString('media_cache_tasks');
    if (tasksJson != null) {
      final List<dynamic> decoded = jsonDecode(tasksJson);
      tasks = decoded.map((e) => CacheTask.fromJson(e)).toList();
      for (var task in tasks) {
        if (task.status == 0) task.status = 2;
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await prefs.setString('media_cache_tasks', encoded);
  }

  Future<void> startDownload({
    required String id,
    required String title,
    required String url,
    required Map<String, String> headers,
  }) async {
    await ensureInitialized();

    if (tasks.any((t) => t.id == id && t.status != 2)) return;

    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final localPath = '${dir.path}/$safeTitle';

    final existingTaskIndex = tasks.indexWhere((t) => t.id == id);
    CacheTask task;
    if (existingTaskIndex >= 0) {
      task = tasks[existingTaskIndex];
      task.status = 0;
      task.progress = 0.0;
    } else {
      task = CacheTask(id: id, title: title, url: url, localPath: localPath);
      tasks.add(task);
    }
    
    _save();
    notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    try {
      await _dio.download(
        url,
        localPath,
        options: Options(headers: headers),
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            task.progress = received / total;
            notifyListeners();
          }
        },
      );
      task.status = 1;
      task.progress = 1.0;
    } catch (e) {
      // ===== 修复点：显式判断 DioException 类型 =====
      if (e is DioException && CancelToken.isCancel(e)) {
        task.status = 2; // 被手动取消
      } else {
        task.status = 2; // 失败
        debugPrint('下载失败: $e');
      }
      // ===========================================
    } finally {
      _cancelTokens.remove(id);
      _save();
      notifyListeners();
    }
  }

  Future<void> deleteTask(String id) async {
    _cancelTokens[id]?.cancel();
    final taskIndex = tasks.indexWhere((t) => t.id == id);
    if (taskIndex >= 0) {
      final task = tasks[taskIndex];
      final file = File(task.localPath);
      if (await file.exists()) {
        await file.delete();
      }
      tasks.removeAt(taskIndex);
      _save();
      notifyListeners();
    }
  }
}