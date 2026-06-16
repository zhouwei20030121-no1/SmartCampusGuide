import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../location/location_service.dart';

/// 与智能讲解页一致的校区范围
class CampusBounds {
  static const LatLng defaultCenter = LatLng(29.819000, 106.422000);

  static final LatLngBounds interaction = LatLngBounds(
    southwest: const LatLng(29.80649, 106.402434),
    northeast: const LatLng(29.835163, 106.436554),
  );

  static bool contains(LatLng point) => interaction.contains(point);

  static LatLng clampToCampus(LatLng point) {
    return contains(point) ? point : defaultCenter;
  }
}

/// 校园地图 Tab 与路线规划页共用：唯一红色「我的位置」数据源
class MapUserLocationController {
  MapUserLocationController._();

  static final MapUserLocationController shared = MapUserLocationController._();
  static const String _markerId = 'shared_user_location';

  final LocationService _loc = LocationService();
  final List<VoidCallback> _pageListeners = [];

  static const double _userMarkerZIndex = 999;

  Marker? _userMarker;
  LatLng _userPos = CampusBounds.defaultCenter;
  bool _followRealLocation = false;
  bool _serviceHooked = false;
  bool _notifyScheduled = false;

  LatLng get userPos => _resolvePosition();

  Marker get userMarker {
    _ensureMarker();
    return _userMarker!;
  }

  void attach(VoidCallback onChanged) {
    if (!_pageListeners.contains(onChanged)) {
      _pageListeners.add(onChanged);
    }
    _ensureMarker();
    _hookServiceListener();
    _publishIfNeeded(force: true);
  }

  void detach(VoidCallback onChanged) {
    _pageListeners.remove(onChanged);
  }

  void syncFromService({bool force = false}) {
    _ensureMarker();
    _publishIfNeeded(force: force);
  }

  void _ensureMarker() {
    if (_userMarker != null) return;
    final marker = Marker(
      position: CampusBounds.defaultCenter,
      zIndex: _userMarkerZIndex,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: '我的位置', snippet: 'GPS 定位显示'),
      draggable: false,
    );
    marker.setIdForCopy(_markerId);
    _userMarker = marker;
    _userPos = CampusBounds.defaultCenter;
  }

  void _hookServiceListener() {
    if (_serviceHooked) return;
    _loc.addListener(_handleLocationChanged);
    _serviceHooked = true;
  }

  void _handleLocationChanged() {
    _publishIfNeeded(force: false);
  }

  LatLng _resolvePosition() {
    final raw = LatLng(_loc.latitude, _loc.longitude);

    if (_followRealLocation &&
        !_loc.isManualMode &&
        _loc.realLocationAvailable &&
        CampusBounds.contains(raw)) {
      return raw;
    }
    if (CampusBounds.contains(raw)) {
      return raw;
    }
    return CampusBounds.defaultCenter;
  }

  void _publishIfNeeded({required bool force}) {
    final pos = _resolvePosition();
    final moved =
        pos.latitude != _userPos.latitude || pos.longitude != _userPos.longitude;
    if (!moved) {
      if (force) _notifyListeners();
      return;
    }

    _userPos = pos;
    _userMarker = _userMarker!.copyWith(positionParam: pos);
    _notifyListeners();
  }

  void _applyPosition(LatLng pos) {
    _userPos = pos;
    _ensureMarker();
    _userMarker = _userMarker!.copyWith(positionParam: pos);
    _notifyListeners();
  }

  void _notifyListeners() {
    if (_pageListeners.isEmpty || _notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      for (final listener in List<VoidCallback>.from(_pageListeners)) {
        listener();
      }
    });
  }

  Future<String?> useRealLocation() async {
    _ensureMarker();
    _hookServiceListener();
    await _loc.startTracking();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final raw = LatLng(_loc.latitude, _loc.longitude);
    if (_loc.realLocationAvailable && CampusBounds.contains(raw)) {
      _followRealLocation = true;
      _applyPosition(raw);
      return '已切换到真实定位';
    }

    _followRealLocation = false;
    _loc.updateLocation(
      CampusBounds.defaultCenter.latitude,
      CampusBounds.defaultCenter.longitude,
    );
    _applyPosition(CampusBounds.defaultCenter);
    return '当前 GPS 不在西南大学校区内（模拟器常见），已统一定位到校园中心';
  }

  void centerCameraOnUser(AMapController? controller, {bool animated = true}) {
    final pos = userPos;
    controller?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: pos, zoom: 17, tilt: 0, bearing: 0),
      ),
      animated: animated,
    );
  }
}
