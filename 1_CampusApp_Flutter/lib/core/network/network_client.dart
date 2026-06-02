import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';

class NetworkClient {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'https://genna-boldhearted-dewily.ngrok-free.dev';
    if (!kIsWeb && Platform.isIOS) return 'https://genna-boldhearted-dewily.ngrok-free.dev';
    return 'https://genna-boldhearted-dewily.ngrok-free.dev';
  }

  static String get aiBaseUrl {
    const envUrl = String.fromEnvironment('AI_SERVICE_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'https://genna-boldhearted-dewily.ngrok-free.dev';
    if (!kIsWeb && Platform.isIOS) return 'https://genna-boldhearted-dewily.ngrok-free.dev';
    return 'https://genna-boldhearted-dewily.ngrok-free.dev';
  }

  // 保存当前登录账号，方便个人中心页面拉取后端信息。
  static String currentAccount = '';

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static final Dio aiDio = Dio(
    BaseOptions(
      baseUrl: aiBaseUrl,
      connectTimeout: const Duration(seconds: 30), // AI takes longer
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

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
