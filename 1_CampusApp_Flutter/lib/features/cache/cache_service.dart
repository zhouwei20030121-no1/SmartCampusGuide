import 'package:flutter/foundation.dart';

import '../../core/storage/local_storage.dart';
import '../../core/network/network_client.dart';
import '../spot/spot_model.dart';
import 'offline_route_planner.dart';

typedef CacheProgressCallback = void Function(String stage, double progress);

class CacheService {
  static String? lastError;
  static String lastUsedBaseUrl = NetworkClient.baseUrl;

  static Future<bool> preloadAll({CacheProgressCallback? onProgress}) async {
    lastError = null;
    onProgress?.call('正在下载景点列表…', 0.05);
    final spotsOk = await preloadSpots(
      onProgress: (p) {
        onProgress?.call('正在下载景点列表…', 0.05 + p * 0.35);
      },
    );
    if (!spotsOk) return false;

    onProgress?.call('正在下载讲解内容…', 0.42);
    final guidesOk = await preloadGuides(
      onProgress: (p) {
        onProgress?.call('正在下载讲解内容…', 0.42 + p * 0.25);
      },
    );
    if (!guidesOk) {
      debugPrint('讲解缓存部分失败，继续下载路线与路网');
    }

    onProgress?.call('正在下载推荐路线…', 0.70);
    final routesOk = await preloadRoutes(
      onProgress: (p) {
        onProgress?.call('正在下载推荐路线…', 0.70 + p * 0.15);
      },
    );
    if (!routesOk) {
      debugPrint('推荐路线缓存部分失败，继续构建路网');
    }

    onProgress?.call('正在构建校园路网…', 0.88);
    await _buildAndSaveRoadGraph();
    await LocalStorage.setMeta(
      'last_sync_at',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
    onProgress?.call('离线数据准备完成', 1.0);
    return true;
  }

  static Future<bool> preloadSpots({
    void Function(double progress)? onProgress,
  }) async {
    lastError = null;
    try {
      final res = await NetworkClient.get(
        '/spot/list',
        queryParameters: {'page': 1, 'size': 1000},
      );
      lastUsedBaseUrl = res.requestOptions.baseUrl;

      final responseData = res.data;
      if (responseData['code'] == 200) {
        final data = responseData['data'];
        final records = data is Map
            ? data['records'] as List<dynamic>?
            : data is List
            ? data
            : null;

        if (records != null && records.isNotEmpty) {
          final safeDbSpots = records.map((e) {
            final json = e as Map<String, dynamic>;
            return {
              'id': json['id'],
              'name': json['name'] ?? '',
              'category': json['category'],
              'description': json['description'],
              'coverImage': json['coverImage'] ?? '',
              'images': json['images'],
              'longitude':
                  double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
              'latitude':
                  double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
              'visitCount': json['visitCount'] ?? 0,
            };
          }).toList();

          await LocalStorage.saveSpotList(safeDbSpots);
          onProgress?.call(1.0);
          return true;
        }
        lastError = '后端没有返回可缓存的景点数据';
      }
      lastError ??=
          '后端返回异常：${responseData['message'] ?? responseData['code'] ?? '未知错误'}';
      return false;
    } catch (e) {
      lastError = _friendlyNetworkError(e);
      debugPrint('缓存景点失败: $e');
      return false;
    }
  }

  static Future<bool> preloadGuides({
    void Function(double progress)? onProgress,
  }) async {
    lastError = null;
    try {
      final spots = await getCachedSpots();
      if (spots.isEmpty) {
        lastError = '请先下载景点列表';
        return false;
      }

      final guides = <Map<String, dynamic>>[];
      for (var i = 0; i < spots.length; i++) {
        final spotId = spots[i]['id'];
        if (spotId == null) continue;
        try {
          final res = await NetworkClient.get('/guide/content/$spotId');
          if (res.data['code'] == 200 && res.data['data'] != null) {
            final data = res.data['data'] as Map<String, dynamic>;
            final script = data['scriptContent']?.toString() ?? '';
            guides.add({
              'spot_id': spotId,
              'language': data['language'] ?? 'zh',
              'title': data['title'] ?? spots[i]['name'],
              'script_content': script.isNotEmpty
                  ? script
                  : _fallbackGuideText(spots[i]),
              'audio_url': data['audioUrl'],
            });
          } else {
            guides.add({
              'spot_id': spotId,
              'language': 'zh',
              'title': spots[i]['name'],
              'script_content': _fallbackGuideText(spots[i]),
              'audio_url': null,
            });
          }
        } catch (_) {
          guides.add({
            'spot_id': spotId,
            'language': 'zh',
            'title': spots[i]['name'],
            'script_content': _fallbackGuideText(spots[i]),
            'audio_url': null,
          });
        }
        onProgress?.call((i + 1) / spots.length);
      }

      await LocalStorage.saveGuideContent(guides);
      return guides.isNotEmpty;
    } catch (e) {
      lastError = _friendlyNetworkError(e);
      return false;
    }
  }

  static String _fallbackGuideText(Map<String, dynamic> spot) {
    final name = spot['name']?.toString() ?? '该景点';
    final desc = spot['description']?.toString() ?? '';
    if (desc.isEmpty) return '欢迎来到$name。';
    return '欢迎来到$name。$desc';
  }

  static Future<bool> preloadRoutes({
    void Function(double progress)? onProgress,
  }) async {
    lastError = null;
    try {
      final res = await NetworkClient.get(
        '/route/plan/list',
        queryParameters: {'page': 1, 'size': 100},
      );
      if (res.data['code'] != 200) {
        lastError = res.data['message']?.toString() ?? '推荐路线下载失败';
        return false;
      }

      final records = (res.data['data']?['records'] as List<dynamic>?) ?? [];
      final routes = <Map<String, dynamic>>[];

      for (var i = 0; i < records.length; i++) {
        final item = records[i] as Map<String, dynamic>;
        final id = item['id'];
        Map<String, dynamic> detail = item;

        try {
          final detailRes = await NetworkClient.get('/route/plan/$id');
          if (detailRes.data['code'] == 200 && detailRes.data['data'] != null) {
            detail = Map<String, dynamic>.from(detailRes.data['data']);
          }
        } catch (_) {}

        final spots = detail['spots'];
        routes.add({
          'id': detail['id'],
          'route_name': detail['routeName'],
          'target_audience': detail['targetAudience'],
          'estimated_time': detail['estimatedTime'],
          'description': detail['description'],
          'spot_ids': detail['spotIds'],
          'spots_json': LocalStorage.encodeJson(spots ?? []),
        });
        onProgress?.call((i + 1) / records.length);
      }

      await LocalStorage.saveRouteList(routes);
      return true;
    } catch (e) {
      lastError = _friendlyNetworkError(e);
      return false;
    }
  }

  static Future<void> _buildAndSaveRoadGraph() async {
    final spots = (await getCachedSpots())
        .map((e) => SpotModel.fromJson(e))
        .where((s) => s.latitude != 0 && s.longitude != 0)
        .toList();
    final edges = OfflineRoutePlanner.buildGraphEdges(spots);
    await LocalStorage.saveGraphEdges(edges);
  }

  static Future<List<Map<String, dynamic>>> getCachedSpots() async {
    return LocalStorage.getSpotList();
  }

  static Future<List<SpotModel>> getCachedSpotModels() async {
    final records = await getCachedSpots();
    return records.map((e) => SpotModel.fromJson(e)).toList();
  }

  /// 离线 POI 搜索：名称 / 分类 / 描述模糊匹配。
  static Future<List<SpotModel>> searchSpotsOffline(String keyword) async {
    final records = await LocalStorage.searchSpots(keyword);
    return records
        .map((e) => SpotModel.fromJson(e))
        .where((s) => s.latitude != 0 && s.longitude != 0)
        .toList();
  }

  static Future<Map<String, dynamic>?> getCachedGuide(
    int spotId, {
    String language = 'zh',
  }) async {
    return LocalStorage.getGuideContent(spotId, language: language);
  }

  static Future<String?> getCachedGuideBySpotName(
    String spotName, {
    String language = 'zh',
  }) async {
    final spots = await getCachedSpots();
    Map<String, dynamic>? match;
    for (final s in spots) {
      if (s['name']?.toString() == spotName.trim()) {
        match = s;
        break;
      }
    }
    if (match == null) return null;
    final guide = await getCachedGuide(match['id'] as int, language: language);
    final script = guide?['script_content']?.toString() ?? '';
    if (script.isNotEmpty) return _stripHtml(script);
    final desc = match['description']?.toString() ?? '';
    return desc.isNotEmpty ? desc : null;
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  static Future<List<Map<String, dynamic>>> getCachedRoutes() async {
    return LocalStorage.getRouteList();
  }

  static Future<List<Map<String, dynamic>>> getCachedGraphEdges() async {
    return LocalStorage.getGraphEdges();
  }

  static Future<Map<String, int>> getCacheStats() async {
    return LocalStorage.getCacheStats();
  }

  static Future<String?> getLastSyncTime() async {
    final raw = await LocalStorage.getMeta('last_sync_at');
    if (raw == null) return null;
    final ms = int.tryParse(raw);
    if (ms == null) return null;
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  /// 离线路线规划：基于缓存景点与校园路网。
  static Future<List<SpotModel>> planRouteOffline({
    required int startId,
    required int endId,
    List<int> waypoints = const [],
    String strategy = 'DISTANCE',
    String userIdentity = 'TOURIST',
  }) async {
    final spots = await getCachedSpotModels();
    return OfflineRoutePlanner.planAdvancedRoute(
      allSpots: spots,
      startId: startId,
      endId: endId,
      waypoints: waypoints,
      strategy: strategy,
      userIdentity: userIdentity,
    );
  }

  static Future<void> clearCache() async {
    await LocalStorage.clearOfflineCache();
  }

  static String _friendlyNetworkError(Object e) {
    final text = e.toString();
    if (text.contains('connection') ||
        text.contains('Connection') ||
        text.contains('SocketException') ||
        text.contains('connectionError')) {
      return '网络连接失败。真机请用 --dart-define=API_BASE_URL=http://电脑局域网IP:8080 构建，'
          '或确保后端在 8080 端口运行。当前地址：${NetworkClient.baseUrl}';
    }
    return text;
  }
}
