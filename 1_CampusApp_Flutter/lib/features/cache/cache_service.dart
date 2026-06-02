import 'package:flutter/foundation.dart';

import '../../core/storage/local_storage.dart';
import '../../core/network/network_client.dart';

class CacheService {
  static Future<bool> preloadSpots() async {
    try {
      final res = await NetworkClient.get('/spot/list', queryParameters: {
        'page': 1,
        'size': 1000,
      });

      final responseData = res.data;
      if (responseData['code'] == 200) {
        final records = responseData['data']['records'] as List<dynamic>?;

        if (records != null && records.isNotEmpty) {
          // 🌟 核心修复点：手动清洗后端数据，剔除 SQLite 表中没有的字段
          // 并且新建了 Map 对象，防止出现“Map不可修改”的报错
          List<Map<String, dynamic>> safeDbSpots = records.map((e) {
            final json = e as Map<String, dynamic>;
            return {
              'id': json['id'],
              'name': json['name'] ?? '',
              'category': json['category'],
              'description': json['description'],
              // 安全解析可能传过来的 BigDecimal 数字或字符串
              'longitude': double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
              'latitude': double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
            };
          }).toList();

          await LocalStorage.saveSpotList(safeDbSpots);
          return true;
        }
      }
      return false;
    } catch (e) {
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
