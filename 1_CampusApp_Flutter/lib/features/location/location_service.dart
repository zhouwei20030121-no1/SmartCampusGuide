// lib/features/location/location_service.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/network/network_client.dart';

class LocationService extends ChangeNotifier {
  static const MethodChannel _locationChannel = MethodChannel(
    'smart_campus_guide/location',
  );
  static const EventChannel _headingChannel = EventChannel(
    'smart_campus_guide/heading',
  );

  // 私有化构造函数，切断外部通过 () 创建独立新实例的途径
  LocationService._internal();

  // 全局唯一单例
  static final LocationService _instance = LocationService._internal();

  // 工厂构造函数，让全局所有 LocationService() 调用都指向同一个单例
  factory LocationService() => _instance;

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
  double _headingDegrees = 0;
  bool _headingAvailable = false;
  DateTime? _lastRealFixAt;

  // 手动操作标记位，防止定时器与地图手动点击发生冲突
  bool _isManualMode = false;

  Timer? _heartbeatTimer;
  Timer? _simulationTimer;
  StreamSubscription<dynamic>? _headingSubscription;
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
  double get headingDegrees => _headingDegrees;
  bool get headingAvailable => _headingAvailable;

  // setter 统一走 updateLocation（内含 0.0 脏数据拦截 + 手动模式标记 + 即时距离同步）
  set latitude(double value) => updateLocation(value, _longitude);
  set longitude(double value) => updateLocation(_latitude, value);

  Future<void> startTracking() async {
    if (_isTracking) return; // 防止重复启动创建多个 Timer 造成内存泄漏
    _isTracking = true;
    _geoStatus = '定位中...';
    _isManualMode = false; // 启动时默认恢复为自动模拟行走模式
    notifyListeners();
    _startHeadingUpdates();

    if (!_visitReported) {
      _visitReported = true;
      unawaited(_recordAppVisit());
    }
    await _refreshRealLocation();
    _simulationTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (_realLocationAvailable && !_isManualMode) {
        unawaited(_refreshRealLocation());
      } else {
        _simulateMove(timer);
      }
    });

    // 心跳上报
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
    await _headingSubscription?.cancel();
    _headingSubscription = null;
    notifyListeners();
  }

  void _startHeadingUpdates() {
    if (_headingSubscription != null) return;
    _headingSubscription = _headingChannel.receiveBroadcastStream().listen(
      (event) {
        final heading = _readHeadingDegrees(event);
        if (heading == null) return;
        _headingDegrees = _normalizeDegrees(heading);
        _headingAvailable = true;
        notifyListeners();
      },
      onError: (_) {
        // iOS 真机支持该通道；其他平台或模拟器缺传感器时静默回退到移动方向推算。
      },
      cancelOnError: false,
    );
  }

  double? _readHeadingDegrees(dynamic event) {
    if (event is num) return event.toDouble();
    if (event is Map) {
      final raw = event['heading'];
      if (raw is num) return raw.toDouble();
    }
    return null;
  }

  void _simulateMove(Timer t) {
    // 如果用户在智能讲解页手动点击了地图，就跳过定时器的自动位移，避免位置被扯回原点
    if (_isManualMode) return;

    // 在25教和樟树林之间缓慢移动（模拟用户行走）
    _latitude +=
        (29.820 - _latitude) * 0.3 +
        (DateTime.now().second % 2 == 0 ? 0.0003 : -0.0002);
    _longitude +=
        (106.421 - _longitude) * 0.3 +
        (DateTime.now().second % 3 == 0 ? 0.0002 : -0.0001);
    _simulateProximity();
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
        _geoStatus = (result?['reason'] ?? '真实定位不可用，使用演示模式').toString();
        _simulateProximity();
        notifyListeners();
        return;
      }

      final lat = (result['latitude'] as num?)?.toDouble();
      final lng = (result['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
        _realLocationAvailable = false;
        _locationMode = 'simulation';
        _geoStatus = '真实定位数据异常，使用演示模式';
        _simulateProximity();
        notifyListeners();
        return;
      }

      _speedMps = (result['speed'] as num?)?.toDouble() ?? 0;
      _accuracyMeters = (result['accuracy'] as num?)?.toDouble() ?? -1;
      final heading = (result['heading'] as num?)?.toDouble();
      // GPS 返回 WGS-84，而高德底图/后端景点坐标是 GCJ-02，
      // 必须先转换，否则定位蓝点会与底图、景点偏移数百米。
      final gcj = _wgs84ToGcj02(lat, lng);
      // 多采样加权平滑，抑制 GPS 抖动
      final smoothed = _smoothLocation(
        gcj[0],
        gcj[1],
        _speedMps,
        _accuracyMeters,
      );
      _updateHeading(heading, smoothed.latitude, smoothed.longitude);
      _latitude = smoothed.latitude;
      _longitude = smoothed.longitude;
      _realLocationAvailable = true;
      _locationMode = 'real';
      _lastRealFixAt = DateTime.now();
      _simulateProximity();
      notifyListeners();
    } on PlatformException catch (e) {
      _realLocationAvailable = false;
      _locationMode = 'simulation';
      _geoStatus = e.message ?? '定位权限未开启，使用演示模式';
      _simulateProximity();
      notifyListeners();
    } catch (_) {
      _realLocationAvailable = false;
      _locationMode = 'simulation';
      _geoStatus = '真实定位不可用，使用演示模式';
      _simulateProximity();
      notifyListeners();
    }
  }

  Future<void> _sendHeartbeat() async {
    if (!_isTracking) return;
    try {
      final res = await NetworkClient.dio.post(
        '/api/location/heartbeat',
        data: {
          'userId': NetworkClient.currentUserId, // 统一使用登录用户ID
          'lng': _longitude,
          'lat': _latitude,
          'speedMps': _speedMps,
          'accuracyMeters': _accuracyMeters,
          'headingDegrees': _headingAvailable ? _headingDegrees : null,
          'locationMode': _locationMode,
          'lastFixAt': _lastRealFixAt?.toIso8601String(),
        },
      );
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
      await NetworkClient.dio.post(
        '/stats/app-visit',
        data: {
          'userId': NetworkClient.currentUserId,
          'deviceInfo': 'flutter_app',
        },
      );
    } catch (_) {
      _visitReported = false;
    }
  }

  /// 离线模拟：静态坐标距离判断
  void _simulateProximity() {
    const spots = {
      'Teaching Building 25': [106.421, 29.820],
      'Camphor Woods': [106.428, 29.822],
      'Central Library': [106.431, 29.824],
      'Youth Garden': [106.427, 29.821],
    };
    for (final entry in spots.entries) {
      final dx = (_longitude - entry.value[0]) * 111320 * 0.866; // cos(30°)
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
    if (lat == 0.0 || lng == 0.0) return; // 拦截模拟器 0.0 脏数据
    _updateHeading(null, lat, lng);
    _latitude = lat;
    _longitude = lng;
    _isManualMode = true; // 标记为用户手动控点模式，暂停自动模拟
    _locationMode = 'manual_demo';
    _speedMps = 0;
    _accuracyMeters = 0;
    _simulateProximity(); // 立即触发一次本地距离检测，让首页和讲解页秒级同步
    notifyListeners();
  }

  void _updateHeading(double? sensorHeading, double nextLat, double nextLng) {
    if (sensorHeading != null && sensorHeading.isFinite && sensorHeading >= 0) {
      _headingDegrees = _normalizeDegrees(sensorHeading);
      _headingAvailable = true;
      return;
    }

    final movedMeters = _distanceMeters(
      _latitude,
      _longitude,
      nextLat,
      nextLng,
    );
    if (movedMeters < 1.5) return;
    _headingDegrees = _bearingDegrees(_latitude, _longitude, nextLat, nextLng);
    _headingAvailable = true;
  }

  double _bearingDegrees(double lat1, double lng1, double lat2, double lng2) {
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final lambda1 = lng1 * math.pi / 180;
    final lambda2 = lng2 * math.pi / 180;
    final y = math.sin(lambda2 - lambda1) * math.cos(phi2);
    final x =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(lambda2 - lambda1);
    return _normalizeDegrees(math.atan2(y, x) * 180 / math.pi);
  }

  double _normalizeDegrees(double degrees) {
    final normalized = degrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
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
      final jumpMeters = _distanceMeters(
        last.latitude,
        last.longitude,
        lat,
        lng,
      );
      final allowedJump = math.max(
        45.0,
        (speedMps + 2.0) * seconds + math.max(accuracyMeters, 0),
      );
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
      final accuracyWeight = sample.accuracyMeters <= 0
          ? 1.0
          : 1 / math.max(8.0, sample.accuracyMeters);
      final recencyWeight = 1.0 + i * 0.18;
      final weight = accuracyWeight * recencyWeight;
      weightSum += weight;
      latSum += sample.latitude * weight;
      lngSum += sample.longitude * weight;
    }
    return _LocationSample(
      latSum / weightSum,
      lngSum / weightSum,
      accuracyMeters,
      now,
    );
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // ===== WGS-84（GPS 原始坐标）→ GCJ-02（高德底图/后端景点坐标系）=====
  // 不转换会导致定位蓝点与高德底图、景点标点偏移约 300-600 米。
  static const double _gcjA = 6378245.0;
  static const double _gcjEe = 0.00669342162296594323;

  List<double> _wgs84ToGcj02(double lat, double lng) {
    if (_outOfChina(lat, lng)) return [lat, lng];
    var dLat = _transformLat(lng - 105.0, lat - 35.0);
    var dLng = _transformLng(lng - 105.0, lat - 35.0);
    final radLat = lat / 180.0 * math.pi;
    var magic = math.sin(radLat);
    magic = 1 - _gcjEe * magic * magic;
    final sqrtMagic = math.sqrt(magic);
    dLat =
        (dLat * 180.0) /
        ((_gcjA * (1 - _gcjEe)) / (magic * sqrtMagic) * math.pi);
    dLng = (dLng * 180.0) / (_gcjA / sqrtMagic * math.cos(radLat) * math.pi);
    return [lat + dLat, lng + dLng];
  }

  bool _outOfChina(double lat, double lng) {
    return !(lng > 73.66 && lng < 135.05 && lat > 3.86 && lat < 53.55);
  }

  double _transformLat(double x, double y) {
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

  double _transformLng(double x, double y) {
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
