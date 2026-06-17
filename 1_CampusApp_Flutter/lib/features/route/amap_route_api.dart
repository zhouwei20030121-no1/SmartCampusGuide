import 'package:dio/dio.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';

class AMapRouteApi {
  // ⚠️ 记得去高德开放平台申请一个【Web服务】类型的 Key，填在下面
  static const String webApiKey = '4bfbb1b19546bb49a3286ec7f45839b8';
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      sendTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );

  static Future<List<LatLng>> getRealWalkingRoute(LatLng origin, LatLng destination) async {
    const String url = 'https://restapi.amap.com/v3/direction/walking';

    try {
      final response = await _dio.get(url, queryParameters: {
        'origin': '${origin.longitude},${origin.latitude}',
        'destination': '${destination.longitude},${destination.latitude}',
        'key': webApiKey,
      });

      if (response.data['status'] == '1') {
        List<LatLng> realPath = [];
        var paths = response.data['route']['paths'];
        if (paths != null && paths.isNotEmpty) {
          var steps = paths[0]['steps'];
          for (var step in steps) {
            String polyline = step['polyline'];
            List<String> points = polyline.split(';');
            for (String point in points) {
              List<String> lngLat = point.split(',');
              if (lngLat.length == 2) {
                realPath.add(LatLng(
                  double.parse(lngLat[1]),
                  double.parse(lngLat[0]),
                ));
              }
            }
          }
        }
        if (realPath.isNotEmpty) {
          return realPath;
        }
      }
    } catch (e) {
      print('获取高德真实路线失败: $e');
    }
    // 兜底返回直线
    return [origin, destination];
  }
}
