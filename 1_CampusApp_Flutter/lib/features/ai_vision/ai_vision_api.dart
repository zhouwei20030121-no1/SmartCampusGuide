import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class AiVisionApi {
  static String get _baseUrl {
    const envUrl = String.fromEnvironment('AI_SERVICE_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://127.0.0.1:5000';
  }

  static List<String> get _baseUrls {
    final urls = <String>[
      _baseUrl,
      'http://127.0.0.1:5000',
      'http://10.0.2.2:5000',
      'http://localhost:5000',
      'https://genna-boldhearted-dewily.ngrok-free.dev',
    ];
    return urls.toSet().toList();
  }

  /// 调用视觉识别接口识别建筑
  static Future<AiVisionResult> recognize(String imageBase64) async {
    Object? lastError;
    for (final baseUrl in _baseUrls) {
      try {
        return await _recognizeWith(baseUrl, imageBase64);
      } catch (e) {
        lastError = e;
      }
    }
    throw AiVisionException('无法连接 AI 视觉服务，请确认 Python AI 服务已在 5000 端口启动。错误：$lastError');
  }

  static Future<AiVisionResult> _recognizeWith(
    String baseUrl,
    String imageBase64,
  ) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse('$baseUrl/api/vision/recognize'),
      );
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('ngrok-skip-browser-warning', 'true');
      req.add(utf8.encode(json.encode({'image_base64': imageBase64})));

      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final decoded = json.decode(body) as Map<String, dynamic>;

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw AiVisionException('视觉服务异常：HTTP ${res.statusCode}');
      }

      if (decoded['code'] != 200) {
        throw AiVisionException(decoded['message']?.toString() ?? '视觉服务返回失败');
      }

      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      return AiVisionResult(
        buildingName: data['building_name']?.toString() ?? '未知建筑',
        description: data['description']?.toString() ?? '',
        recognized: data['recognized'] == true,
        fallback: data['fallback'] == true,
      );
    } on SocketException catch (e) {
      throw AiVisionException('$baseUrl 连接失败：${e.message}');
    } finally {
      client.close();
    }
  }
}

class AiVisionResult {
  final String buildingName;
  final String description;
  final bool recognized;
  final bool fallback;

  const AiVisionResult({
    required this.buildingName,
    required this.description,
    required this.recognized,
    required this.fallback,
  });
}

class AiVisionException implements Exception {
  final String message;
  const AiVisionException(this.message);

  @override
  String toString() => message;
}
