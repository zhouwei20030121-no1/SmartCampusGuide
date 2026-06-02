import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/network/network_client.dart';

class LocationService extends ChangeNotifier {
  double _latitude = 29.820;
  double _longitude = 106.421;
  bool _isTracking = false;
  String? _triggeredSpot;
  String _geoStatus = '未启动';
  String _nearbySpot = '';
  double _distance = 999;

  // 公开属性
  double get latitude => _latitude;
  double get longitude => _longitude;
  bool get isTracking => _isTracking;
  String? get triggeredSpot => _triggeredSpot;
  String get geoStatus => _geoStatus;
  String get nearbySpot => _nearbySpot;
  double get distance => _distance;

  Timer? _heartbeatTimer;
  Timer? _simulationTimer;

  /// 启动定位与心跳（每5秒向Java后端发送坐标）
  Future<void> startTracking() async {
    _isTracking = true;
    _geoStatus = '定位中...';
    notifyListeners();

    // 模拟GPS轨迹（实际应接入高德定位SDK）
    _simulationTimer = Timer.periodic(const Duration(seconds: 8), _simulateMove);

    // 心跳上报
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sendHeartbeat());
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    _geoStatus = '已停止';
    _simulationTimer?.cancel();
    _heartbeatTimer?.cancel();
    notifyListeners();
  }

  void _simulateMove(Timer t) {
    // 在25教和樟树林之间缓慢移动（模拟用户行走）
    _latitude += (29.820 - _latitude) * 0.3 + (DateTime.now().second % 2 == 0 ? 0.0003 : -0.0002);
    _longitude += (106.421 - _longitude) * 0.3 + (DateTime.now().second % 3 == 0 ? 0.0002 : -0.0001);
    notifyListeners();
  }

  Future<void> _sendHeartbeat() async {
    if (!_isTracking) return;
    try {
      final res = await NetworkClient.dio.post('/api/location/heartbeat', data: {
        'userId': 'demo_user',
        'lng': _longitude,
        'lat': _latitude,
      });
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
  void _simulateProximity() {
    const spots = {
      '25教': [106.421, 29.820],
      '樟树林': [106.428, 29.822],
      '中心图书馆': [106.431, 29.824],
      '共青团花园': [106.427, 29.821],
    };
    for (var e in spots.entries) {
      final dx = (_longitude - (e.value[0] as double)) * 111320 * 0.866; // cos(30°)
      final dy = (_latitude - (e.value[1] as double)) * 111320;
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
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
