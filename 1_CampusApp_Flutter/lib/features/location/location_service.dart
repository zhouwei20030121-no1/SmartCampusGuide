// lib/features/location/location_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/network/network_client.dart';

class LocationService extends ChangeNotifier {
  static const MethodChannel _locationChannel = MethodChannel(
    'smart_campus_guide/location',
  );

  // 1. 私有化构造函数，切断外部通过 () 创建独立新实例的途径
  LocationService._internal();

  // 2. 保存全局唯一的单例实例
  static final LocationService _instance = LocationService._internal();

  // 3. 工厂构造函数，让全局所有的 LocationService() 调用都指向同一个单例
  factory LocationService() => _instance;

  double _latitude = 29.820;
  double _longitude = 106.421;
  bool _isTracking = false;
  bool _visitReported = false;
  String? _triggeredSpot;
  String _geoStatus = '未启动';
  String _nearbySpot = '';
  double _distance = 999;
  bool _realLocationAvailable = false;
  String _locationMode = 'simulation';
  double _accuracyMeters = -1;
  DateTime? _lastRealFixAt;

  // 4. 引入手动操作标记位，防止定时器与地图手动点击发生冲突
  bool _isManualMode = false;

  // 公开属性
  double get latitude => _latitude;
  set latitude(double v) {
    // 5. 核心拦截：如果是模拟器返回的 0.0 错误脏数据，直接丢弃，不予更新
    if (v == 0.0) return;
    _latitude = v;
    _isManualMode = true; // 6. 标记为用户手动控点模式，暂停自动乱跑模拟
    _simulateProximity(); // 7. 立即在本地触发一次距离检测，让首页和讲解页秒级同步
    notifyListeners();
  }

  double get longitude => _longitude;
  set longitude(double v) {
    if (v == 0.0) return; // 8. 拦截 0.0 脏数据
    _longitude = v;
    _isManualMode = true;
    _simulateProximity();
    notifyListeners();
  }

  bool get isTracking => _isTracking;
  String? get triggeredSpot => _triggeredSpot;
  String get geoStatus => _geoStatus;
  String get nearbySpot => _nearbySpot;
  double get distance => _distance;
  bool get realLocationAvailable => _realLocationAvailable;
  String get locationMode => _locationMode;
  double get accuracyMeters => _accuracyMeters;

  Timer? _heartbeatTimer;
  Timer? _simulationTimer;

  /// 启动定位与心跳（每5秒向Java后端发送坐标）
  Future<void> startTracking() async {
    if (_isTracking) return; // 9. 防止重复启动创建多个 Timer 造成内存泄漏
    _isTracking = true;
    _geoStatus = '定位中...';
    _isManualMode = false; // 10. 启动时默认恢复为队友写的自动模拟行走模式
    notifyListeners();

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
    _geoStatus = '已停止';
    _simulationTimer?.cancel();
    _heartbeatTimer?.cancel();
    notifyListeners();
  }

  void _simulateMove(Timer t) {
    // 11. 如果用户在智能讲解页手动点击了地图或者高德POI，就跳过定时器的自动位移，避免位置被扯回原点
    if (_isManualMode) return;

    // 在25教和樟树林之间缓慢移动（模拟用户行走）
    _latitude +=
        (29.820 - _latitude) * 0.3 +
        (DateTime.now().second % 2 == 0 ? 0.0003 : -0.0002);
    _longitude +=
        (106.421 - _longitude) * 0.3 +
        (DateTime.now().second % 3 == 0 ? 0.0002 : -0.0001);
    _simulateProximity(); // 12. 模拟移动时也同步进行本地账目计算
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

      _latitude = lat;
      _longitude = lng;
      _accuracyMeters = (result['accuracy'] as num?)?.toDouble() ?? -1;
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
          'userId': NetworkClient.currentUserId, // 13. 规范化使用统一的登录用户ID
          'lng': _longitude,
          'lat': _latitude,
          'locationMode': _locationMode,
          'accuracy': _accuracyMeters,
          'lastFixAt': _lastRealFixAt?.toIso8601String(),
        },
      );
      if (res.data['code'] == 200) {
        final data = res.data['data'];
        if (data['action'] == 'TRIGGER_GUIDE') {
          _triggeredSpot = data['spotName'];
          _geoStatus = '已触发讲解';
          _nearbySpot = data['spotName'];
          _distance = 0;
        } else {
          _triggeredSpot = null;
          _geoStatus = '未进入景点范围';
          _nearbySpot = '';
          _distance = 999;
        }
        notifyListeners();
      }
    } catch (_) {
      _geoStatus = '后端离线，模拟中';
      // 离线模式：根据静态坐标表模拟检测
      _simulateProximity();
      notifyListeners();
    }
  }

  /// 离线模拟：静态坐标距离判断
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

  void _simulateProximity() {
    const spots = {
      '25教': [106.421, 29.820],
      '樟树林': [106.428, 29.822],
      '中心图书馆': [106.431, 29.824],
      '共青团花园': [106.427, 29.821],
    };
    for (var e in spots.entries) {
      final dx = (_longitude - e.value[0]) * 111320 * 0.866; // cos(30°)
      final dy = (_latitude - e.value[1]) * 111320;
      final dist = (dx * dx + dy * dy).clamp(0, double.infinity).toDouble();
      final d = dist > 0 ? dist : 1.0;
      if (d < 50) {
        _nearbySpot = e.key;
        _distance = d;
        _geoStatus = '距离${e.key}约${d.toStringAsFixed(0)}米';
        return;
      }
    }
    _nearbySpot = '';
    _distance = 999;
    _geoStatus = '未进入景点范围';
  }

  void clearTrigger() {
    _triggeredSpot = null;
    _isManualMode = false;
    notifyListeners();
  }
}
