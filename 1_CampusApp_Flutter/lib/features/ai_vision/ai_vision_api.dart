import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AiVisionApi {
  static const _publicAiUrl = 'https://genna-boldhearted-dewily.ngrok-free.dev';

  static String get _baseUrl {
    const envUrl = String.fromEnvironment('AI_SERVICE_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5000';
    if (!kIsWeb && Platform.isIOS) return _publicAiUrl;
    return 'http://127.0.0.1:5000';
  }

  static List<String> get _baseUrls {
    final urls = <String>[];
    urls.add(_baseUrl);
    if (!kIsWeb && Platform.isIOS) {
      urls.addAll([_publicAiUrl, 'http://127.0.0.1:5000']);
    } else {
      urls.addAll([
        'http://127.0.0.1:5000',
        'http://10.0.2.2:5000',
        'http://localhost:5000',
        _publicAiUrl,
      ]);
    }
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
    throw AiVisionException(
      '无法连接 AI 视觉服务，请确认 Python AI 服务已在 5000 端口启动。错误：$lastError',
    );
  }

  static Future<AiVisionResult> _recognizeWith(
    String baseUrl,
    String imageBase64,
  ) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ),
    );

    try {
      final res = await dio.post(
        '/api/vision/recognize',
        data: {'image_base64': imageBase64},
      );

      final statusCode = res.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        throw AiVisionException('视觉服务异常：HTTP ${res.statusCode}');
      }

      final decoded = switch (res.data) {
        final Map<String, dynamic> map => map,
        final String text => json.decode(text) as Map<String, dynamic>,
        _ => <String, dynamic>{},
      };

      if (decoded['code'] != 200) {
        throw AiVisionException(decoded['message']?.toString() ?? '视觉服务返回失败');
      }

      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      final debug = data['debug'] is Map
          ? Map<String, dynamic>.from(data['debug'] as Map)
          : <String, dynamic>{};
      return AiVisionResult(
        buildingName: data['building_name']?.toString() ?? '未知建筑',
        description: data['description']?.toString() ?? '',
        recognized: data['recognized'] == true,
        fallback: data['fallback'] == true,
        requestId: data['request_id']?.toString() ?? '',
        matchSource: data['match_source']?.toString() ?? '',
        reason: data['reason']?.toString() ?? '',
        clipTop1Distance: double.tryParse(
          data['clip_top1_distance']?.toString() ?? '',
        ),
        debug: debug,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final detail = e.message ?? e.error?.toString() ?? e.type.name;
      throw AiVisionException(
        status == null ? '$baseUrl 连接失败：$detail' : '$baseUrl 返回异常：HTTP $status',
      );
    }
  }
}

class AiVisionResult {
  final String buildingName;
  final String description;
  final bool recognized;
  final bool fallback;
  final String requestId;
  final String matchSource;
  final String reason;
  final double? clipTop1Distance;
  final Map<String, dynamic> debug;

  const AiVisionResult({
    required this.buildingName,
    required this.description,
    required this.recognized,
    required this.fallback,
    this.requestId = '',
    this.matchSource = '',
    this.reason = '',
    this.clipTop1Distance,
    this.debug = const {},
  });
}

class AiVisionException implements Exception {
  final String message;
  const AiVisionException(this.message);

  @override
  String toString() => message;
}
