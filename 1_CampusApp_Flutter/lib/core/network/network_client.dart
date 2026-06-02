import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';

class NetworkClient {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://127.0.0.1:8080';
  }

  static String get aiBaseUrl {
    const envUrl = String.fromEnvironment('AI_SERVICE_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://127.0.0.1:5000';
  }

  // 保存当前登录账号，方便个人中心页面拉取后端信息。
  static String currentAccount = '';

  static Dio _createDio(String primaryUrl, Duration timeout) {
    final d = Dio(
      BaseOptions(
        baseUrl: primaryUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );
    
    d.interceptors.add(InterceptorsWrapper(
      onError: (err, handler) async {
        final isConnectionError = err.type == DioExceptionType.connectionTimeout || 
                                  err.type == DioExceptionType.receiveTimeout || 
                                  err.type == DioExceptionType.connectionError ||
                                  err.type == DioExceptionType.unknown;
        if (isConnectionError) {
          final req = err.requestOptions;
          if (!req.baseUrl.contains('ngrok')) {
            req.baseUrl = 'https://genna-boldhearted-dewily.ngrok-free.dev';
            try {
              final response = await d.request(
                req.path,
                data: req.data,
                queryParameters: req.queryParameters,
                options: Options(
                  method: req.method,
                  headers: req.headers,
                  responseType: req.responseType,
                  contentType: req.contentType,
                ),
              );
              return handler.resolve(response);
            } catch (e) {
              if (e is DioException) return handler.next(e);
            }
          }
        }
        return handler.next(err);
      }
    ));
    return d;
  }

  static final Dio dio = _createDio(baseUrl, const Duration(seconds: 10));
  static final Dio aiDio = _createDio(aiBaseUrl, const Duration(seconds: 30));

  static Future<Response> get(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return dio.get(path, data: data, queryParameters: queryParameters);
  }

  static Future<Response> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return dio.post(path, data: data, queryParameters: queryParameters);
  }
}
