import '../../core/storage/local_storage.dart';
import '../../core/network/network_client.dart';

class CacheService {
  static Future<void> preloadSpots() async {
    try {
      final res = await NetworkClient.get('/spot/page?current=1&size=200');
      final data = res['data'] as Map<String, dynamic>?;
      final records = data?['records'] as List<dynamic>?;
      if (records != null) {
        await LocalStorage.saveSpotList(
            records.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getCachedSpots() async {
    return LocalStorage.getSpotList();
  }

  static Future<void> clearCache() async {
    await LocalStorage.clearAll();
  }
}
