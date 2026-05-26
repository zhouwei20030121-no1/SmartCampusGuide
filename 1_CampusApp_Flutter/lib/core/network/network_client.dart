import 'package:dio/dio.dart';

class NetworkClient {
  // 替换为当前电脑局域网 IP 地址
  static const String baseUrl = 'http://192.168.43.231:8080';

  // 💡 新增：全局保存当前登录的账号，方便个人中心页面拉取后端信息
  static String currentAccount = '';

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static Future<Response> get(String path, {Object? data, Map<String, dynamic>? queryParameters}) {
    return dio.get(path, data: data, queryParameters: queryParameters);
  }

  static Future<Response> post(String path, {Object? data, Map<String, dynamic>? queryParameters}) {
    return dio.post(path, data: data, queryParameters: queryParameters);
  }
}