import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// 专业级：Dio 客户端封装
class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late Dio dio;

  static const int _timeoutSeconds = 30;
  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  DioClient._internal() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: _timeoutSeconds), 
      receiveTimeout: const Duration(seconds: _timeoutSeconds), 
      sendTimeout: const Duration(seconds: _timeoutSeconds),    
      headers: {
        'User-Agent': _userAgent,
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 请求拦截，可在此处注入鉴权 Token 等信息
        return handler.next(options); 
      },
      onResponse: (response, handler) {
        // 响应拦截，可在此处统一处理 JSON 数据脱壳结构
        return handler.next(response); 
      },
      onError: (DioException e, handler) {
        // 异常统一拦截，比如处理 401 token 过期跳转登录页
        debugPrint('[Network Request Error] URL: ${e.requestOptions.uri} \nMessage: ${e.message}');
        return handler.next(e); 
      },
    ));

    // 仅在开发环境中启用详细网络日志
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,          
        requestHeader: true,    // 建议打开 Header 日志以便调试鉴权
        responseHeader: false,
        responseBody: false,    
        error: true,
      ));
    }
  }
}