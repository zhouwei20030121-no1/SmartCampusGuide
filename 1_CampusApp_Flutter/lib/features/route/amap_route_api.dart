import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class AMapRouteApi {
  static const String _webApiKey = '1720e1cdbd1e2bd1b01798d222cf6434';
  static const String _walkingUrl =
      'https://restapi.amap.com/v3/direction/walking';
  static const String _poiUrl =
      'https://restapi.amap.com/v3/place/text';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 8),
    ),
  );

  static Future<List<LatLng>> getRealWalkingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final response = await _dio.get(
        _walkingUrl,
        queryParameters: {
          'origin': '${origin.longitude},${origin.latitude}',
          'destination': '${destination.longitude},${destination.latitude}',
          'key': _webApiKey,
        },
      );

      final data = response.data;
      if (data is! Map || data['status']?.toString() != '1') {
        return [origin, destination];
      }

      final paths = data['route']?['paths'];
      if (paths is! List || paths.isEmpty) return [origin, destination];

      final steps = paths.first['steps'];
      if (steps is! List || steps.isEmpty) return [origin, destination];

      final route = <LatLng>[];
      for (final step in steps) {
        final polyline = step is Map ? step['polyline']?.toString() : null;
        if (polyline == null || polyline.isEmpty) continue;
        for (final rawPoint in polyline.split(';')) {
          final lngLat = rawPoint.split(',');
          if (lngLat.length != 2) continue;
          final lng = double.tryParse(lngLat[0]);
          final lat = double.tryParse(lngLat[1]);
          if (lat == null || lng == null) continue;
          final point = LatLng(lat, lng);
          if (route.isEmpty || route.last != point) {
            route.add(point);
          }
        }
      }

      return route.length >= 2 ? route : [origin, destination];
    } catch (_) {
      return [origin, destination];
    }
  }

  static Future<LatLng?> searchPoiCoordinates(String keyword) async {
    try {
      final response = await _dio.get(
        _poiUrl,
        queryParameters: {
          'keywords': keyword,
          'city': '重庆',
          'offset': 1,
          'page': 1,
          'key': _webApiKey,
        },
      );
      final data = response.data;
      if (data is Map && data['status']?.toString() == '1') {
        final pois = data['pois'];
        if (pois is List && pois.isNotEmpty) {
          final locationStr = pois.first['location']?.toString();
          if (locationStr != null && locationStr.isNotEmpty) {
            final parts = locationStr.split(',');
            if (parts.length == 2) {
              final lng = double.tryParse(parts[0]);
              final lat = double.tryParse(parts[1]);
              if (lng != null && lat != null) {
                return LatLng(lat, lng);
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
