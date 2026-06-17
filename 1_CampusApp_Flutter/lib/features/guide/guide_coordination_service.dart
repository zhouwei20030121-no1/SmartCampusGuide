import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class GuideCoordinationService {
  GuideCoordinationService._();

  static final GuideCoordinationService instance = GuideCoordinationService._();

  List<LatLng> _activeRoute = const [];
  String _routeLabel = '';
  String _destination = '';

  bool get hasActiveRoute => _activeRoute.length >= 2;
  String get routeLabel => _routeLabel;
  String get destination => _destination;

  void setActiveRoute({
    required List<LatLng> points,
    required String routeLabel,
    required String destination,
  }) {
    _activeRoute = List.unmodifiable(points);
    _routeLabel = routeLabel;
    _destination = destination;
  }

  void clearRoute() {
    _activeRoute = const [];
    _routeLabel = '';
    _destination = '';
  }

  double distanceToActiveRoute(LatLng position) {
    if (_activeRoute.length < 2) return double.infinity;
    var best = double.infinity;
    for (var i = 0; i < _activeRoute.length - 1; i++) {
      best = math.min(
        best,
        _distanceToSegment(position, _activeRoute[i], _activeRoute[i + 1]),
      );
    }
    return best;
  }

  double distanceToDestination(LatLng position) {
    if (_activeRoute.isEmpty) return double.infinity;
    return _distance(position, _activeRoute.last);
  }

  double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    final px = _lngToMeters(p.longitude);
    final py = _latToMeters(p.latitude);
    final ax = _lngToMeters(a.longitude);
    final ay = _latToMeters(a.latitude);
    final bx = _lngToMeters(b.longitude);
    final by = _latToMeters(b.latitude);

    final dx = bx - ax;
    final dy = by - ay;
    if (dx == 0 && dy == 0) return _distance(p, a);

    final t = (((px - ax) * dx) + ((py - ay) * dy)) / ((dx * dx) + (dy * dy));
    final clamped = t.clamp(0.0, 1.0);
    final projectionX = ax + clamped * dx;
    final projectionY = ay + clamped * dy;
    final diffX = px - projectionX;
    final diffY = py - projectionY;
    return math.sqrt(diffX * diffX + diffY * diffY);
  }

  double _distance(LatLng left, LatLng right) {
    final dx = (left.longitude - right.longitude) * 111320 * 0.866;
    final dy = (left.latitude - right.latitude) * 111320;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _latToMeters(double lat) => lat * 111320;
  double _lngToMeters(double lng) => lng * 111320 * 0.866;
}
