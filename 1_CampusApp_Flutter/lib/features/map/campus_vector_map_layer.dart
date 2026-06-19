import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CampusVectorMapLayer extends StatelessWidget {
  const CampusVectorMapLayer({super.key});

  static Future<_CampusVectorMap>? _cache;

  static Future<_CampusVectorMap> _load() {
    return _cache ??= _CampusVectorMap.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CampusVectorMap>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const ColoredBox(color: Color(0xFFEAF4F8));
        }
        return Stack(
          children: [
            const ColoredBox(color: Color(0xFFEAF4F8)),
            PolygonLayer(
              polygons: data.polygons,
              polygonLabels: false,
              simplificationTolerance: 0.45,
            ),
            PolylineLayer(
              polylines: data.polylines,
              simplificationTolerance: 0.35,
            ),
          ],
        );
      },
    );
  }
}

class _CampusVectorMap {
  final List<Polygon> polygons;
  final List<Polyline> polylines;

  const _CampusVectorMap({required this.polygons, required this.polylines});

  static Future<_CampusVectorMap> load() async {
    final raw = await rootBundle.loadString('assets/map/swu_vector_map.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>? ?? const [];
    final polygons = <Polygon>[];
    final polylines = <Polyline>[];

    for (final item in features.whereType<Map<String, dynamic>>()) {
      final layer = item['layer']?.toString() ?? 'land';
      final geometry = item['geometry']?.toString() ?? '';
      final points = _parsePoints(item['points']);
      if (points.length < 2) continue;

      if (geometry == 'polygon' && points.length >= 3) {
        polygons.add(
          Polygon(
            points: points,
            color: _fillColor(layer),
            borderColor: _borderColor(layer),
            borderStrokeWidth: _borderWidth(layer),
          ),
        );
      } else {
        polylines.add(
          Polyline(
            points: points,
            color: _lineColor(layer),
            strokeWidth: _lineWidth(layer),
          ),
        );
      }
    }

    return _CampusVectorMap(polygons: polygons, polylines: polylines);
  }

  static List<LatLng> _parsePoints(dynamic rawPoints) {
    if (rawPoints is! List) return const [];
    return rawPoints
        .whereType<List>()
        .map((point) {
          if (point.length < 2) return null;
          final lat = (point[0] as num?)?.toDouble();
          final lng = (point[1] as num?)?.toDouble();
          if (lat == null || lng == null) return null;
          return _wgs84ToGcj02(lat, lng);
        })
        .whereType<LatLng>()
        .toList(growable: false);
  }

  static LatLng _wgs84ToGcj02(double lat, double lng) {
    if (_outOfChina(lat, lng)) return LatLng(lat, lng);
    final dLat = _transformLat(lng - 105.0, lat - 35.0);
    final dLng = _transformLng(lng - 105.0, lat - 35.0);
    final radLat = lat / 180.0 * math.pi;
    var magic = math.sin(radLat);
    magic = 1 - 0.00669342162296594323 * magic * magic;
    final sqrtMagic = math.sqrt(magic);
    final mgLat =
        lat +
        (dLat * 180.0) /
            ((6378245.0 * (1 - 0.00669342162296594323)) /
                (magic * sqrtMagic) *
                math.pi);
    final mgLng =
        lng +
        (dLng * 180.0) / (6378245.0 / sqrtMagic * math.cos(radLat) * math.pi);
    return LatLng(mgLat, mgLng);
  }

  static bool _outOfChina(double lat, double lng) {
    return lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;
  }

  static double _transformLat(double x, double y) {
    var ret =
        -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * math.sqrt(x.abs());
    ret +=
        (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    ret +=
        (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) *
        2.0 /
        3.0;
    ret +=
        (160.0 * math.sin(y / 12.0 * math.pi) +
            320 * math.sin(y * math.pi / 30.0)) *
        2.0 /
        3.0;
    return ret;
  }

  static double _transformLng(double x, double y) {
    var ret =
        300.0 +
        x +
        2.0 * y +
        0.1 * x * x +
        0.1 * x * y +
        0.1 * math.sqrt(x.abs());
    ret +=
        (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    ret +=
        (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) *
        2.0 /
        3.0;
    ret +=
        (150.0 * math.sin(x / 12.0 * math.pi) +
            300.0 * math.sin(x / 30.0 * math.pi)) *
        2.0 /
        3.0;
    return ret;
  }

  static Color _fillColor(String layer) {
    switch (layer) {
      case 'building':
        return const Color(0xFFE6E1D8);
      case 'green':
        return const Color(0xFFCDE9AF);
      case 'water':
        return const Color(0xFFAED4F5);
      case 'land':
        return const Color(0xFFF5F1E8);
      default:
        return const Color(0xFFEAF4F8);
    }
  }

  static Color _borderColor(String layer) {
    switch (layer) {
      case 'building':
        return const Color(0xFFC9C0B4);
      case 'green':
        return const Color(0xFFB4D790);
      case 'water':
        return const Color(0xFF89BFEA);
      default:
        return const Color(0xFFD7E4EA);
    }
  }

  static double _borderWidth(String layer) {
    switch (layer) {
      case 'building':
        return 0.7;
      case 'water':
        return 0.5;
      default:
        return 0.25;
    }
  }

  static Color _lineColor(String layer) {
    switch (layer) {
      case 'major_road':
        return const Color(0xFFE7B75A);
      case 'road':
        return const Color(0xFFFFFFFF);
      case 'path':
        return const Color(0xFFFAFAFA);
      default:
        return const Color(0xFFFFFFFF);
    }
  }

  static double _lineWidth(String layer) {
    switch (layer) {
      case 'major_road':
        return 4.4;
      case 'road':
        return 2.6;
      case 'path':
        return 1.5;
      default:
        return 1.0;
    }
  }
}
