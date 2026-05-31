import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ArApi {
  static String get _baseUrl {
    const envUrl = String.fromEnvironment('AI_SERVICE_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5050';
    return 'http://127.0.0.1:5050';
  }

  static List<String> get _baseUrls {
    final urls = <String>[
      _baseUrl,
      'http://127.0.0.1:5050',
      'http://10.0.2.2:5050',
      'http://localhost:5050',
    ];
    return urls.toSet().toList();
  }

  /// 调用视觉识别接口识别建筑
  static Future<ArRecognizeResult> recognize(String imageBase64) async {
    Object? lastError;
    for (final baseUrl in _baseUrls) {
      try {
        return await _recognizeWith(baseUrl, imageBase64);
      } catch (e) {
        lastError = e;
      }
    }
    throw ArApiException('无法连接 AI 视觉服务，请确认服务已启动。错误：$lastError');
  }

  static Future<ArRecognizeResult> _recognizeWith(
    String baseUrl,
    String imageBase64,
  ) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse('$baseUrl/api/vision/recognize'),
      );
      req.headers.set('Content-Type', 'application/json');
      req.add(utf8.encode(json.encode({'image_base64': imageBase64})));

      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final decoded = json.decode(body) as Map<String, dynamic>;

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ArApiException('视觉服务异常：HTTP ${res.statusCode}');
      }

      if (decoded['code'] != 200) {
        throw ArApiException(decoded['message']?.toString() ?? '视觉服务返回失败');
      }

      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      return ArRecognizeResult(
        buildingName: data['building_name']?.toString() ?? '未知建筑',
        description: data['description']?.toString() ?? '',
        recognized: data['recognized'] == true,
        fallback: data['fallback'] == true,
      );
    } on SocketException catch (e) {
      throw ArApiException('$baseUrl 连接失败：${e.message}');
    } finally {
      client.close();
    }
  }
}

class ArRecognizeResult {
  final String buildingName;
  final String description;
  final bool recognized;
  final bool fallback;

  const ArRecognizeResult({
    required this.buildingName,
    required this.description,
    required this.recognized,
    required this.fallback,
  });
}

class ArApiException implements Exception {
  final String message;
  const ArApiException(this.message);

  @override
  String toString() => message;
}
