import 'package:flutter/foundation.dart';

import '../../core/network/network_client.dart';

class LocationService extends ChangeNotifier {
  final double _latitude = 0.0;
  final double _longitude = 0.0;
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
      await NetworkClient.post(
        '/map/location/upload',
        body: {'longitude': _longitude, 'latitude': _latitude},
      );
    } catch (_) {}
  }
}
