import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/network/network_client.dart';

class LocationService extends ChangeNotifier {
  LocationService._internal();

  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;

  static const MethodChannel _locationChannel =
      MethodChannel('smart_campus_guide/location');

  double _latitude = 29.820;
  double _longitude = 106.421;
  bool _isTracking = false;
  bool _visitReported = false;
  String? _triggeredSpot;
  String _geoStatus = 'not_started';
  String _nearbySpot = '';
  double _distance = 999;
  bool _realLocationAvailable = false;
  String _locationMode = 'simulation';
  double _speedMps = 0;
  double _accuracyMeters = -1;
  bool _isManualMode = false;

  Timer? _heartbeatTimer;
  Timer? _simulationTimer;
  final List<_LocationSample> _recentSamples = [];

  double get latitude => _latitude;
  double get longitude => _longitude;
  bool get isTracking => _isTracking;
  String? get triggeredSpot => _triggeredSpot;
  String get geoStatus => _geoStatus;
  String get nearbySpot => _nearbySpot;
  double get distance => _distance;
  bool get realLocationAvailable => _realLocationAvailable;
  bool get isManualMode => _isManualMode;
  String get locationMode => _locationMode;
  double get speedMps => _speedMps;
  double get accuracyMeters => _accuracyMeters;

  set latitude(double value) => updateLocation(value, _longitude);
  set longitude(double value) => updateLocation(_latitude, value);

  Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;
    _geoStatus = 'locating';
    _isManualMode = false;
    notifyListeners();

    if (!_visitReported) {
      _visitReported = true;
      unawaited(_recordAppVisit());
    }

    await _refreshRealLocation();
    _simulationTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!_realLocationAvailable) {
        _simulateMove();
      } else {
        unawaited(_refreshRealLocation());
      }
    });
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_realLocationAvailable && !_isManualMode) {
        await _refreshRealLocation();
      }
      await _sendHeartbeat();
    });
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    _geoStatus = 'stopped';
    _simulationTimer?.cancel();
    _heartbeatTimer?.cancel();
    notifyListeners();
  }

  Future<void> _refreshRealLocation() async {
    if (_isManualMode) return;
    try {
      final result = await _locationChannel.invokeMapMethod<String, dynamic>(
        'getCurrentLocation',
      );
      if (result == null || result['ok'] != true) {
        _realLocationAvailable = false;
        _locationMode = 'simulation';
        _geoStatus = 'real_location_unavailable';
        _simulateProximity();
        notifyListeners();
        return;
      }

      final lat = double.tryParse(result['latitude'].toString());
      final lng = double.tryParse(result['longitude'].toString());
      if (lat == null || lng == null || lat == 0.0 || lng == 0.0) return;

      _speedMps = double.tryParse(result['speed']?.toString() ?? '0') ?? 0;
      _accuracyMeters =
          double.tryParse(result['accuracy']?.toString() ?? '-1') ?? -1;
      final smoothed = _smoothLocation(lat, lng, _speedMps, _accuracyMeters);
      _latitude = smoothed.latitude;
      _longitude = smoothed.longitude;
      _realLocationAvailable = true;
      _locationMode = 'real';
      _simulateProximity();
      notifyListeners();
    } catch (_) {
      _realLocationAvailable = false;
      _locationMode = 'simulation';
      _geoStatus = 'real_location_unavailable';
      _simulateProximity();
      notifyListeners();
    }
  }

  void _simulateMove() {
    if (_isManualMode) return;
    _locationMode = 'simulation';
    _realLocationAvailable = false;
    _speedMps = 0.9;
    _latitude += (29.820 - _latitude) * 0.3 +
        (DateTime.now().second % 2 == 0 ? 0.0003 : -0.0002);
    _longitude += (106.421 - _longitude) * 0.3 +
        (DateTime.now().second % 3 == 0 ? 0.0002 : -0.0001);
    _simulateProximity();
    notifyListeners();
  }

  Future<void> _sendHeartbeat() async {
    if (!_isTracking) return;
    try {
      final res = await NetworkClient.dio.post('/api/location/heartbeat', data: {
        'userId': NetworkClient.currentUserId,
        'lng': _longitude,
        'lat': _latitude,
        'speedMps': _speedMps,
        'accuracyMeters': _accuracyMeters,
        'locationMode': _locationMode,
      });
      if (res.data['code'] == 200) {
        final data = res.data['data'] ?? {};
        if (data['action'] == 'TRIGGER_GUIDE') {
          _triggeredSpot = data['spotName']?.toString();
          _nearbySpot = _triggeredSpot ?? '';
          _distance = (data['distanceMeters'] is num)
              ? (data['distanceMeters'] as num).toDouble()
              : 0;
          _geoStatus = 'guide_triggered';
        } else {
          _triggeredSpot = null;
          _nearbySpot = data['spotName']?.toString() ?? '';
          _distance = (data['distanceMeters'] is num)
              ? (data['distanceMeters'] as num).toDouble()
              : 999;
          _geoStatus = data['reason']?.toString() ?? 'outside_geofence';
        }
        notifyListeners();
      }
    } catch (_) {
      _geoStatus = 'backend_offline_simulation';
      _simulateProximity();
      notifyListeners();
    }
  }

  Future<void> _recordAppVisit() async {
    try {
      await NetworkClient.dio.post('/stats/app-visit', data: {
        'userId': NetworkClient.currentUserId,
        'deviceInfo': 'flutter_app',
      });
    } catch (_) {
      _visitReported = false;
    }
  }

  void _simulateProximity() {
    const spots = {
      'Teaching Building 25': [106.421, 29.820],
      'Camphor Woods': [106.428, 29.822],
      'Central Library': [106.431, 29.824],
      'Youth Garden': [106.427, 29.821],
    };
    for (final entry in spots.entries) {
      final dx = (_longitude - entry.value[0]) * 111320 * 0.866;
      final dy = (_latitude - entry.value[1]) * 111320;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < 50) {
        _nearbySpot = entry.key;
        _distance = d;
        _geoStatus = 'near ${entry.key}, ${d.toStringAsFixed(0)}m';
        return;
      }
    }
    _nearbySpot = '';
    _distance = 999;
    _geoStatus = 'outside_geofence';
  }

  void clearTrigger() {
    _triggeredSpot = null;
    _isManualMode = false;
    notifyListeners();
  }

  void updateLocation(double lat, double lng) {
    if (lat == 0.0 || lng == 0.0) return;
    _latitude = lat;
    _longitude = lng;
    _isManualMode = true;
    _locationMode = 'manual_demo';
    _speedMps = 0;
    _accuracyMeters = 0;
    _simulateProximity();
    notifyListeners();
  }

  _LocationSample _smoothLocation(
    double lat,
    double lng,
    double speedMps,
    double accuracyMeters,
  ) {
    final now = DateTime.now();
    if (_recentSamples.isNotEmpty) {
      final last = _recentSamples.last;
      final seconds = math.max(1, now.difference(last.time).inSeconds);
      final jumpMeters =
          _distanceMeters(last.latitude, last.longitude, lat, lng);
      final allowedJump =
          math.max(45.0, (speedMps + 2.0) * seconds + math.max(accuracyMeters, 0));
      if (jumpMeters > allowedJump) {
        return last;
      }
    }

    _recentSamples.add(_LocationSample(lat, lng, accuracyMeters, now));
    if (_recentSamples.length > 5) {
      _recentSamples.removeAt(0);
    }

    final valid = _recentSamples
        .where((item) => item.accuracyMeters <= 0 || item.accuracyMeters <= 80)
        .toList();
    final samples = valid.isEmpty ? _recentSamples : valid;
    var weightSum = 0.0;
    var latSum = 0.0;
    var lngSum = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final accuracyWeight =
          sample.accuracyMeters <= 0 ? 1.0 : 1 / math.max(8.0, sample.accuracyMeters);
      final recencyWeight = 1.0 + i * 0.18;
      final weight = accuracyWeight * recencyWeight;
      weightSum += weight;
      latSum += sample.latitude * weight;
      lngSum += sample.longitude * weight;
    }
    return _LocationSample(latSum / weightSum, lngSum / weightSum, accuracyMeters, now);
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class _LocationSample {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime time;

  const _LocationSample(
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.time,
  );
}
