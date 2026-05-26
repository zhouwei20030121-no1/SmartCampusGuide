import 'package:flutter/foundation.dart';
import '../../core/network/network_client.dart';

class LocationService extends ChangeNotifier {
  double _latitude = 0.0;
  double _longitude = 0.0;
  bool _isTracking = false;

  double get latitude => _latitude;
  double get longitude => _longitude;
  bool get isTracking => _isTracking;

  Future<void> startTracking() async {
    _isTracking = true;
    notifyListeners();
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    notifyListeners();
  }

  Future<void> uploadLocation() async {
    if (!_isTracking) return;
    try {
      // 关键修改：将原来的 body: 替换为了 Dio 专属的 data:
      await NetworkClient.post('/map/location/upload', data: {
        'longitude': _longitude,
        'latitude': _latitude,
      });
    } catch (_) {
      // 可以在这里加上 print 方便调试，比如：print('位置上传失败: $_');
    }
  }
}