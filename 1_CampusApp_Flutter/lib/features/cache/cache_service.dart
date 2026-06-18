import 'package:flutter/foundation.dart';

import '../../core/storage/local_storage.dart';
import '../../core/network/network_client.dart';

class CacheService {
  static String? lastError;

  static Future<bool> preloadSpots() async {
    lastError = null;
    try {
      final res = await NetworkClient.get('/spot/list', queryParameters: {
        'page': 1,
        'size': 1000,
      });

      final responseData = res.data;
      if (responseData['code'] == 200) {
        final data = responseData['data'];
        final records = data is Map
            ? data['records'] as List<dynamic>?
            : data is List
                ? data
                : null;

        if (records != null && records.isNotEmpty) {
          List<Map<String, dynamic>> safeDbSpots = records.map((e) {
            final json = e as Map<String, dynamic>;
            return {
              'id': json['id'],
              'name': json['name'] ?? '',
              'category': json['category'],
              'description': json['description'],
              'coverImage': json['coverImage'] ?? '',
              'images': json['images'],
              // 安全解析可能传过来的 BigDecimal 数字或字符串
              'longitude': double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
              'latitude': double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
            };
          }).toList();

          await LocalStorage.saveSpotList(safeDbSpots);
          return true;
        }
        lastError = '后端没有返回可缓存的景点数据';
      }
      lastError ??= '后端返回异常：${responseData['message'] ?? responseData['code'] ?? '未知错误'}';
      return false;
    } catch (e) {
      lastError = e.toString();
      debugPrint('缓存写入数据库报错啦: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getCachedSpots() async {
    return LocalStorage.getSpotList();
  }

  static Future<void> clearCache() async {
    await LocalStorage.clearAll();
  }
}
