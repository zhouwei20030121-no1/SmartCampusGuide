import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';

class NetworkClient {
  static String get baseUrl => apiBaseUrls.first;

  static List<String> get apiBaseUrls {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    final urls = <String>[
      if (envUrl.isNotEmpty) envUrl,
      if (!kIsWeb && Platform.isAndroid) 'http://10.0.2.2:8080',
      'http://127.0.0.1:8080',
      'http://localhost:8080',
      if (!kIsWeb && Platform.isAndroid) 'http://127.0.0.1:8080',
      'https://genna-boldhearted-dewily.ngrok-free.dev',
    ];
    return urls.toSet().toList();
  }

  static String get aiBaseUrl {
    const envUrl = String.fromEnvironment('AI_SERVICE_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://127.0.0.1:5000';
  }

  static String currentAccount = '';
  static int currentUserId = 1;
  static String currentToken = '';

  static void setLoginSession(String account, String token) {
    currentAccount = account;
    currentToken = token;
    currentUserId = _parseUserIdFromJwt(token) ?? 1;
  }

  static int? _parseUserIdFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      final sub = payload['sub']?.toString();
      return sub == null ? null : int.tryParse(sub);
    } catch (_) {
      return null;
    }
  }

  static Dio _createDio(String primaryUrl, Duration timeout) {
    return Dio(
      BaseOptions(
        baseUrl: primaryUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        headers: const {
          'ngrok-skip-browser-warning': 'true',
        },
      ),
    );
  }

  static final Dio dio = _createDio(baseUrl, const Duration(seconds: 15));
  static final Dio aiDio = _createDio(aiBaseUrl, const Duration(seconds: 30));

  static Future<Response<dynamic>> _requestWithFallback(
    Future<Response<dynamic>> Function(Dio client) action, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    Object? lastError;
    for (final url in apiBaseUrls) {
      try {
        final client = url == dio.options.baseUrl
            ? dio
            : _createDio(url, timeout);
        return await action(client);
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError is DioException) {
      throw lastError;
    }
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      message: '无法连接后端服务，请确认 Java 后端已在 8080 端口启动。最后错误：$lastError',
      type: DioExceptionType.connectionError,
    );
  }

  static Future<Response<dynamic>> get(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _requestWithFallback(
      (client) => client.get(path, data: data, queryParameters: queryParameters),
    );
  }

  static Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _requestWithFallback(
      (client) => client.post(path, data: data, queryParameters: queryParameters),
    );
  }
}
