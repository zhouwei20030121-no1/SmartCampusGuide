import 'package:dio/dio.dart';

class NetworkClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8088',
  );

  // 保存当前登录账号，方便个人中心页面拉取后端信息。
  static String currentAccount = '';

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
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
