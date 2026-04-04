import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late Dio dio;

  DioClient._internal() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30), // ✨ 延长到 30 秒
      receiveTimeout: const Duration(seconds: 30), // ✨ 延长到 30 秒
      sendTimeout: const Duration(seconds: 30),    // ✨ 延长到 30 秒
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: false,
        requestHeader: false,
        responseHeader: false,
        responseBody: false, 
        error: true,
      ));
    }
  }
}