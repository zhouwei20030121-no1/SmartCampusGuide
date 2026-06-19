import 'dart:convert';
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

  static Dio _createDio(String primaryUrl, Duration timeout,
      {bool ngrokFallback = true}) {
    final d = Dio(
      BaseOptions(
        baseUrl: primaryUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );
    
    // AI 服务(TTS/RAG)不做 ngrok 回退：端点只在 AI 5000，
    // 回退到 ngrok→Caddy→后端只会 404，慢应靠加大超时而非改道。
    if (!ngrokFallback) return d;

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
              req.headers['ngrok-skip-browser-warning'] = 'true';
              final fullUrl = req.path.startsWith('http') ? req.path : req.baseUrl + req.path;
              final response = await d.request(
                fullUrl,
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
  // 语音合成(qwen-tts)合成长音频较慢，超时给足；且不走 ngrok 回退
  static final Dio aiDio =
      _createDio(aiBaseUrl, const Duration(seconds: 90), ngrokFallback: false);

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
