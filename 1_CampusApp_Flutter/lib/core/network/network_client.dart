import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

class NetworkClient {
  static const String _baseUrl = 'http://10.0.2.2:8080';

  // ── Dio 实例（新 API，供 login/profile/bus 等页面使用）──
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // ── 当前登录账号（供个人中心等页面使用）──
  static String currentAccount = '';

  // ── 旧版静态方法（供 cache_service 等兼容）──
  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('$_baseUrl$path'));
      _setHeaders(req, headers);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      return json.decode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('$_baseUrl$path'));
      _setHeaders(req, headers);
      if (body != null) {
        req.write(json.encode(body));
      }
      final res = await req.close();
      final responseBody = await res.transform(utf8.decoder).join();
      return json.decode(responseBody) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  static void _setHeaders(HttpClientRequest req, Map<String, String>? extra) {
    req.headers.set('Content-Type', 'application/json');
    extra?.forEach((k, v) => req.headers.set(k, v));
  }
}
