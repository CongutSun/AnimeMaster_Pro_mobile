import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
        // 可以在这里统一注入 Token： options.headers['Authorization'] = 'Bearer XXX';
        return handler.next(options); 
      },
      onResponse: (response, handler) {
        // 可以在这里进行全局的数据脱壳处理
        return handler.next(response); 
      },
      onError: (DioException e, handler) {
        // 可以在这里统一处理 401 登录过期、网络无连接等通用业务错误
        debugPrint('【网络请求异常】 URL: ${e.requestOptions.uri} \nMessage: ${e.message}');
        return handler.next(e); 
      },
    ));

    // 开发环境开启详细日志
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,          // 建议开发期看完整的请求路径
        requestHeader: false,
        responseHeader: false,
        responseBody: false,    // 视数据量大小可设为 true
        error: true,
      ));
    }
  }
}