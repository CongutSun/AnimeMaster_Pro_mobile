import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 统一异常封装，方便上层业务识别具体的错误来源
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String path;

  ApiException({this.statusCode, required this.message, required this.path});

  @override
  String toString() => 'ApiException(code: $statusCode, path: $path, message: $message)';
}

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late Dio dio;

  static const int _timeoutSeconds = 30;
  // 建议移除写死的桌面端 UA，或者根据实际平台动态生成，这里采用通用移动端标识或留空交由底层处理
  static const String _userAgent = 'AnimeMaster_Pro/1.0.0 (Mobile Client)';

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
        return handler.next(options); 
      },
      onResponse: (response, handler) {
        return handler.next(response); 
      },
      onError: (DioException e, handler) {
        // 统一异常归一化处理
        final apiException = ApiException(
          statusCode: e.response?.statusCode,
          message: e.message ?? 'Unknown Network Error',
          path: e.requestOptions.path,
        );
        debugPrint('[Network Error] $apiException');
        
        // 将自定义异常包装在 error 字段中继续传递
        final customError = e.copyWith(error: apiException);
        return handler.next(customError); 
      },
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,          
        requestHeader: true,    
        responseHeader: false,
        responseBody: false,    
        error: true,
      ));
    }
  }
}