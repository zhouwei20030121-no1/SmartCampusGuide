import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ChatApi {
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

  static Future<ChatReply> sendMessage({
    required String query,
    required List<Map<String, String>> history,
    String persona = '新生',
    Map<String, dynamic> context = const {},
  }) async {
    Object? lastError;
    for (final baseUrl in _baseUrls) {
      try {
        return await _sendTo(
          baseUrl: baseUrl,
          query: query,
          history: history,
          persona: persona,
          context: context,
        );
      } catch (e) {
        lastError = e;
      }
    }

    throw ChatApiException(
      '无法连接西小导服务，请确认 Python AI 服务已在 5000 端口启动。最后错误：$lastError',
    );
  }

  static Future<ChatReply> _sendTo({
    required String baseUrl,
    required String query,
    required List<Map<String, String>> history,
    required String persona,
    required Map<String, dynamic> context,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.postUrl(Uri.parse('$baseUrl/api/rag/chat'));
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('ngrok-skip-browser-warning', 'true');
      req.add(
        utf8.encode(
          json.encode({
            'query': query,
            'history': history,
            'persona': persona,
            'context': context,
          }),
        ),
      );

      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final decoded = json.decode(body) as Map<String, dynamic>;

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ChatApiException('AI 服务异常：HTTP ${res.statusCode}');
      }

      if (decoded['code'] != 200) {
        throw ChatApiException(decoded['message']?.toString() ?? 'AI 服务返回失败');
      }

      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      return ChatReply(
        reply: data['reply']?.toString() ?? '西小导暂时没有生成回答。',
        fallback: data['fallback'] == true,
        model: data['model']?.toString() ?? '',
        sources: (data['sources'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((item) => item['title']?.toString() ?? '')
            .where((title) => title.isNotEmpty)
            .toList(),
      );
    } on SocketException catch (e) {
      throw ChatApiException('$baseUrl 连接失败：${e.message}');
    } on FormatException catch (e) {
      throw ChatApiException('$baseUrl 返回格式异常：${e.message}');
    } finally {
      client.close();
    }
  }
}

class ChatReply {
  final String reply;
  final bool fallback;
  final String model;
  final List<String> sources;

  const ChatReply({
    required this.reply,
    required this.fallback,
    required this.model,
    required this.sources,
  });
}

class ChatApiException implements Exception {
  final String message;

  const ChatApiException(this.message);

  @override
  String toString() => message;
}
