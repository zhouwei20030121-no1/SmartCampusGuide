import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/network_client.dart';
import '../cache/cache_service.dart';
import '../guide/guide_coordination_service.dart';
import '../map/map_user_location_controller.dart';
import '../spot/spot_model.dart';
import 'amap_route_api.dart';

class RoutePage extends StatefulWidget {
  final String? initialEndName;
  final int? initialStartId;
  final int? initialEndId;
  final List<int>? initialWaypointIds;
  final bool autoPlanOnOpen;

  const RoutePage({
    super.key,
    this.initialEndName,
    this.initialStartId,
    this.initialEndId,
    this.initialWaypointIds,
    this.autoPlanOnOpen = false,
  });

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  static const LatLng _swuCenter = LatLng(29.819000, 106.422000);
  static const int _markerBatchSize = 24;
  static const double _campusSouthLat = 29.790000;
  static const double _campusNorthLat = 29.850000;
  static const double _campusWestLng = 106.397434;
  static const double _campusEastLng = 106.441554;
  static final LatLngBounds _mapLimitBounds = LatLngBounds(
    southwest: const LatLng(_campusSouthLat, _campusWestLng),
    northeast: const LatLng(_campusNorthLat, _campusEastLng),
  );

  AMapController? _mapController;
  final Map<String, Marker> _markers = {};
  bool _initialFitDone = false;
  late final MapUserLocationController _userLocation = MapUserLocationController.shared;
  late final VoidCallback _userLocationListener;

  List<SpotModel> _allSpots = [];
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  final Map<String, Polyline> _polylines = {};
  SpotModel? _startSpot;
  SpotModel? _endSpot;
  bool _isLoadingRoute = false;

  bool _showLabels = true;

  // 途经点与策略参数
  final List<SpotModel> _waypoints = [];
  String _userIdentity = 'TOURIST'; // 默认身份
  String _currentStrategy = 'DISTANCE';

  // 使用 Map 管理三种路径和时间文案
  final Map<String, List<LatLng>> _cachedPaths = {};
  final Map<String, String> _pathTimeStrs = {
    'DISTANCE': '计算中...',
    'TIME': '计算中...',
    'PERSONALIZED': '计算中...'
  };

  // 前端缓存高德路段，防止并发时请求超限
  final Map<String, List<LatLng>> _amapSegmentCache = {};
  int _routePlanGeneration = 0;

  CameraPosition _currentCameraPosition = const CameraPosition(
    target: _swuCenter, zoom: 15.6, tilt: 0.0, bearing: 0.0,
  );

  @override
  void initState() {
    super.initState();
    _userLocationListener = () {
      if (mounted) setState(() {});
    };
    _userLocation.attach(_userLocationListener);
    _loadMapData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _userLocation.syncFromService(force: true);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _userLocation.detach(_userLocationListener);
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Set<Marker> get _allMarkers => {
        ..._markers.values,
        _userLocation.userMarker,
      };

  void _showLocationNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _useRealLocation() async {
    final notice = await _userLocation.useRealLocation();
    if (!mounted || notice == null) return;
    _showLocationNotice(notice);
    _userLocation.centerCameraOnUser(_mapController);
  }

  void _centerOnUser() {
    _userLocation.centerCameraOnUser(_mapController);
  }

  Future<void> _loadMapData() async {
    List<SpotModel> spots = [];
    final cachedRecords = await CacheService.getCachedSpots();
    if (cachedRecords.isNotEmpty) {
      spots = cachedRecords.map((e) => SpotModel.fromJson(e)).toList();
    }

    // 与地图展示页一致：拉取最新景点，确保地图页传入的 id 能正确匹配
    try {
      final res = await NetworkClient.get('/spot/list', queryParameters: {
        'page': 1,
        'size': 1000,
      });
      if (res.data['code'] == 200) {
        final records = res.data['data']['records'] as List;
        spots = records
            .map((e) => SpotModel.fromJson(e as Map<String, dynamic>))
            .toList();
        await CacheService.preloadSpots();
      }
    } catch (e) {
      debugPrint('路线页获取景点失败: $e');
    }

    if (spots.isEmpty || !mounted) return;

    SpotModel? initialStart;
    SpotModel? initialEnd;
    final initialWaypoints = <SpotModel>[];

    SpotModel? findSpotById(int id) {
      for (final spot in spots) {
        if (spot.id == id) return spot;
      }
      return null;
    }

    if (widget.initialStartId != null) {
      initialStart = findSpotById(widget.initialStartId!);
    }
    if (widget.initialEndId != null) {
      initialEnd = findSpotById(widget.initialEndId!);
    }
    for (final id in widget.initialWaypointIds ?? const <int>[]) {
      final spot = findSpotById(id);
      if (spot != null && !initialWaypoints.any((w) => w.id == spot.id)) {
        initialWaypoints.add(spot);
      }
    }

    final keyword = widget.initialEndName?.trim();
    if (initialEnd == null && keyword != null && keyword.isNotEmpty) {
      final normalizedKeyword = _normalizePlaceName(keyword);
      for (final spot in spots) {
        final name = _normalizePlaceName(spot.name);
        if (name.contains(normalizedKeyword) || normalizedKeyword.contains(name)) {
          initialEnd = spot;
          break;
        }
      }
    }

    setState(() {
      _allSpots = spots;
      _currentCameraPosition = _cameraPositionForSpots(spots);
      _startSpot = initialStart;
      _endSpot = initialEnd;
      _startController.text = initialStart?.name ?? '';
      _endController.text = initialEnd?.name ?? '';
      _waypoints
        ..clear()
        ..addAll(initialWaypoints);
    });

    await _loadMarkersInBatches(spots);
    await _tryInitialFit();

    if (widget.autoPlanOnOpen &&
        mounted &&
        _startSpot != null &&
        _endSpot != null &&
        _startSpot!.id != _endSpot!.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _triggerRouteWithDelay();
      });
    }
  }

  LatLngBounds _spotMarkerBounds(List<SpotModel> spots) {
    if (spots.isEmpty) {
      return LatLngBounds(
        southwest: LatLng(_swuCenter.latitude - 0.012, _swuCenter.longitude - 0.014),
        northeast: LatLng(_swuCenter.latitude + 0.008, _swuCenter.longitude + 0.014),
      );
    }

    double minLat = spots.first.latitude;
    double maxLat = spots.first.latitude;
    double minLng = spots.first.longitude;
    double maxLng = spots.first.longitude;

    for (final spot in spots) {
      if (spot.latitude < minLat) minLat = spot.latitude;
      if (spot.latitude > maxLat) maxLat = spot.latitude;
      if (spot.longitude < minLng) minLng = spot.longitude;
      if (spot.longitude > maxLng) maxLng = spot.longitude;
    }

    final latSpan = math.max(maxLat - minLat, 0.004);
    final lngSpan = math.max(maxLng - minLng, 0.004);
    final latPad = latSpan * 0.07;
    final lngPad = lngSpan * 0.07;

    minLat -= latPad;
    maxLat += latPad;
    minLng -= lngPad;
    maxLng += lngPad;

    minLat = math.max(_campusSouthLat, minLat);
    maxLat = math.min(_campusNorthLat, maxLat);
    minLng = math.max(_campusWestLng, minLng);
    maxLng = math.min(_campusEastLng, maxLng);

    if (minLat >= maxLat) {
      minLat = _campusSouthLat;
      maxLat = _campusNorthLat;
    }
    if (minLng >= maxLng) {
      minLng = _campusWestLng;
      maxLng = _campusEastLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  CameraPosition _cameraPositionForSpots(List<SpotModel> spots) {
    final bounds = _spotMarkerBounds(spots);
    final latSpan = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngSpan = bounds.northeast.longitude - bounds.southwest.longitude;
    final center = LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2 + latSpan * 0.05,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );
    final zoom = (_estimateZoomForSpan(math.max(latSpan, lngSpan)) + 0.4).clamp(14.0, 16.8);
    return CameraPosition(target: center, zoom: zoom, tilt: 0, bearing: 0);
  }

  double _estimateZoomForSpan(double spanDegrees) {
    if (spanDegrees <= 0) return 16.0;
    return math.log(0.09 / spanDegrees) / math.ln2 + 15.2;
  }

  Future<void> _tryInitialFit() async {
    if (_initialFitDone || _mapController == null || _allSpots.isEmpty) return;
    _initialFitDone = true;
    await _fitCameraToAllSpots(animated: false);
  }

  Future<void> _fitCameraToAllSpots({bool animated = false}) async {
    final controller = _mapController;
    if (controller == null || _allSpots.isEmpty) return;

    final bounds = _spotMarkerBounds(_allSpots);
    await controller.moveCamera(
      CameraUpdate.newLatLngBounds(bounds, 34),
      animated: animated,
    );
    await controller.moveCamera(
      CameraUpdate.scrollBy(0, 72),
      animated: animated,
    );
  }

  void _onMapCreated(AMapController controller) {
    _mapController = controller;
    _userLocation.syncFromService(force: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tryInitialFit();
    });
  }

  String _normalizePlaceName(String value) {
    return value
        .replaceAll('西南大学', '')
        .replaceAll('北碚校区', '')
        .replaceAll(RegExp(r'[()\uFF08\uFF09]'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  Future<void> _loadMarkersInBatches(List<SpotModel> spots) async {
    for (var i = 0; i < spots.length; i += _markerBatchSize) {
      if (!mounted) return;
      final end = math.min(i + _markerBatchSize, spots.length);
      final batchMarkers = _createMarkersForSpots(spots.sublist(i, end));
      setState(() => _markers.addAll(batchMarkers));
      if (end < spots.length) {
        await Future<void>.delayed(Duration.zero);
        await SchedulerBinding.instance.endOfFrame;
      }
    }
  }

  Map<String, Marker> _createMarkersForSpots(List<SpotModel> spots) {
    final Map<String, Marker> batch = {};
    for (final spot in spots) {
      batch[spot.id.toString()] = Marker(
        position: LatLng(spot.latitude, spot.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(_markerHueForCategory(spot.category)),
        onTap: (_) => _handleSpotSelection(spot),
      );
    }
    return batch;
  }

  double _markerHueForCategory(String category) {
    switch (category.trim()) {
      case '自然景观':
        return 240.0;
      case '教学设施':
        return 225.0;
      case '历史建筑':
        return 210.0;
      case '校园文化':
        return 195.0;
      case '生活服务':
        return 180.0;
      default:
        return 210.0;
    }
  }

  void _handleSpotSelection(SpotModel spot) {
    _showRouteSpotGlassDialog(spot);
  }

  void _showRouteSpotGlassDialog(SpotModel spot) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: _glassPanel(
            borderRadius: 16,
            padding: const EdgeInsets.all(14),
            color: Colors.white.withValues(alpha: 0.92),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, Color(0xFF3A86C5)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.place_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spot.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppTheme.textMain,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                spot.category.isNotEmpty ? spot.category : '选择该节点的导航用途',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSub,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(Icons.close, size: 18, color: AppTheme.textSub),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpotDialogAction(
                            label: '设为起点',
                            icon: Icons.trip_origin,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _startSpot = spot;
                                _startController.text = spot.name;
                              });
                              _triggerRouteWithDelay();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _endSpot = spot;
                                _endController.text = spot.name;
                              });
                              _triggerRouteWithDelay();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.flag_rounded, size: 16),
                            label: const Text(
                              '设为终点',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: _buildSpotDialogAction(
                        label: '设为必经途经点',
                        icon: Icons.add_location_alt_outlined,
                        accent: true,
                        onTap: () {
                          Navigator.pop(ctx);
                          if (!_waypoints.any((w) => w.id == spot.id)) {
                            setState(() => _waypoints.add(spot));
                            _triggerRouteWithDelay();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    double borderRadius = 16,
    Color? color,
    Border? border,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSpotDialogAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    final color = accent ? AppTheme.warning : AppTheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: accent ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: accent ? 0.22 : 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 防卡顿异步触发器：让下拉菜单或弹窗先平滑关闭，再执行繁重的地图计算
  void _triggerRouteWithDelay() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _checkAndTriggerRoute();
    });
  }

  void _checkAndTriggerRoute() {
    if (_startSpot != null && _endSpot != null && _startSpot!.id != _endSpot!.id) {
      _fetchAllRoutesAndDraw();
    }
  }

  Future<void> _fetchAllRoutesAndDraw() async {
    if (_startSpot == null || _endSpot == null || _startSpot!.id == _endSpot!.id) {
      return;
    }

    final generation = ++_routePlanGeneration;
    final snapshot = _RoutePlanSnapshot(
      start: _startSpot!,
      end: _endSpot!,
      waypoints: List<SpotModel>.from(_waypoints),
      userIdentity: _userIdentity,
      strategy: _currentStrategy,
    );

    setState(() {
      _isLoadingRoute = true;
      _cachedPaths.clear();
      _polylines.clear();
      _pathTimeStrs['DISTANCE'] = '计算中...';
      _pathTimeStrs['TIME'] = '计算中...';
      _pathTimeStrs['PERSONALIZED'] = '计算中...';
    });

    final results = await Future.wait([
      _getRoutePath('DISTANCE'),
      _getRoutePath('TIME'),
      _getRoutePath('PERSONALIZED'),
    ]);

    if (!mounted || generation != _routePlanGeneration) return;

    setState(() {
      _cachedPaths['DISTANCE'] = results[0];
      _cachedPaths['TIME'] = results[1];
      _cachedPaths['PERSONALIZED'] = results[2];

      _updateAllTimeStrs();
    });

    _drawCurrentRoute(autoZoom: true);
    await _persistRouteHistory(generation, snapshot);
  }

  Future<void> _persistRouteHistory(int generation, _RoutePlanSnapshot snapshot) async {
    if (!mounted || generation != _routePlanGeneration) return;

    final path = _cachedPaths[snapshot.strategy] ?? _cachedPaths['DISTANCE'] ?? [];
    if (path.isEmpty) return;

    final distance = _calculateTotalDistance(path);
    final speed = snapshot.strategy == 'TIME'
        ? 95.0
        : (snapshot.strategy == 'PERSONALIZED' ? 75.0 : 80.0);
    final durationMinutes = math.max(1, (distance / speed).ceil());

    try {
      final response = await NetworkClient.post('/route/history', data: {
        'userId': NetworkClient.currentUserId,
        'startSpotId': snapshot.start.id,
        'endSpotId': snapshot.end.id,
        'startSpotName': snapshot.start.name,
        'endSpotName': snapshot.end.name,
        'waypointIds': snapshot.waypoints.map((e) => e.id).join(','),
        'waypointNames': snapshot.waypoints.map((e) => e.name).join(','),
        'strategy': snapshot.strategy,
        'userIdentity': snapshot.userIdentity,
        'distanceMeters': distance.round(),
        'durationMinutes': durationMinutes,
      });
      if (response.data['code'] != 200) {
        debugPrint('保存路线规划历史失败: ${response.data['message']}');
      }
    } catch (e) {
      debugPrint('保存路线规划历史失败: $e');
    }
  }

  void _updateAllTimeStrs() {
    double distD = _calculateTotalDistance(_cachedPaths['DISTANCE'] ?? []);
    double distT = _calculateTotalDistance(_cachedPaths['TIME'] ?? []);
    double distP = _calculateTotalDistance(_cachedPaths['PERSONALIZED'] ?? []);

    int timeD = (distD / 80).ceil();
    int timeT = (distT / 95).ceil();
    int timeP = (distP / 75).ceil();

    // 💡 核心修复：如果是同一条路径（距离差小于 10 米），强制统一时间
    if ((distT - distD).abs() < 10.0) {
      timeT = timeD;
    } else if (distT > 0 && distD > 0 && timeT >= timeD) {
      timeT = math.max(1, timeD - 1); // 只有路线确实不同时，才允许时间变少
    }

    if ((distP - distD).abs() < 10.0) {
      timeP = timeD; // 和最短路程是同一条路
    } else if ((distP - distT).abs() < 10.0) {
      timeP = timeT; // 和最短时间是同一条路
    }

    _pathTimeStrs['DISTANCE'] = distD < 1000
        ? '约$timeD分钟\n${distD.toInt()}米'
        : '约$timeD分钟\n${(distD/1000).toStringAsFixed(1)}公里';

    _pathTimeStrs['TIME'] = distT < 1000
        ? '约$timeT分钟\n${distT.toInt()}米'
        : '约$timeT分钟\n${(distT/1000).toStringAsFixed(1)}公里';

    _pathTimeStrs['PERSONALIZED'] = distP < 1000
        ? '约$timeP分钟\n${distP.toInt()}米'
        : '约$timeP分钟\n${(distP/1000).toStringAsFixed(1)}公里';
  }

  void _drawCurrentRoute({bool autoZoom = false}) {
    if (!_cachedPaths.containsKey(_currentStrategy)) return;
    List<LatLng> activePath = _cachedPaths[_currentStrategy]!;

    setState(() {
      _isLoadingRoute = false;
      Color routeColor;
      if (_currentStrategy == 'DISTANCE') routeColor = Colors.blueAccent;
      else if (_currentStrategy == 'TIME') routeColor = Colors.green;
      else routeColor = Colors.purpleAccent;

      final polyline = Polyline(
        points: activePath,
        width: 8,
        color: routeColor,
      );
      _polylines['calculated_route'] = polyline;
    });

    String label = '最短路程';
    if (_currentStrategy == 'TIME') label = '最短时间';
    if (_currentStrategy == 'PERSONALIZED') label = '个性化推荐';

    GuideCoordinationService.instance.setActiveRoute(
      points: activePath,
      routeLabel: label,
      destination: _endSpot?.name ?? '',
    );

    if (autoZoom && activePath.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _mapController?.moveCamera(
          CameraUpdate.newLatLngBounds(
            _calculateBounds(activePath),
            100.0,
          ),
          animated: true,
        );
      });
    }
  }

  Future<List<LatLng>> _getRoutePath(String strategy) async {
    List<LatLng> nodesToConnect = [];
    try {
      final Map<String, dynamic> params = {
        'startId': _startSpot!.id,
        'endId': _endSpot!.id,
        'strategy': strategy,
        'userIdentity': _userIdentity,
      };

      if (_waypoints.isNotEmpty) {
        params['waypoints'] = _waypoints.map((e) => e.id).toList();
      } else {
        params['waypoints'] = <int>[];
      }

      final response = await NetworkClient.get('/route/plan/advanced', queryParameters: params);

      if (response.data['code'] == 200) {
        List<dynamic>? spotsData = response.data['data'];
        if (spotsData != null && spotsData.isNotEmpty) {
          for (var spot in spotsData) {
            nodesToConnect.add(LatLng(
              double.tryParse(spot['latitude'].toString()) ?? 0.0,
              double.tryParse(spot['longitude'].toString()) ?? 0.0,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint("Java A*高级算法请求失败 ($strategy): $e");
    }

    if (nodesToConnect.length < 2) {
      nodesToConnect = [LatLng(_startSpot!.latitude, _startSpot!.longitude)];
      nodesToConnect.addAll(_waypoints.map((w) => LatLng(w.latitude, w.longitude)));
      nodesToConnect.add(LatLng(_endSpot!.latitude, _endSpot!.longitude));
    }

    List<LatLng> fullRealRoute = [];
    try {
      for (int i = 0; i < nodesToConnect.length - 1; i++) {
        LatLng start = nodesToConnect[i];
        LatLng end = nodesToConnect[i + 1];
        String cacheKey = '${start.latitude},${start.longitude}-${end.latitude},${end.longitude}';

        if (_amapSegmentCache.containsKey(cacheKey)) {
          fullRealRoute.addAll(_amapSegmentCache[cacheKey]!);
        } else {
          List<LatLng> segment = await AMapRouteApi.getRealWalkingRoute(start, end);
          _amapSegmentCache[cacheKey] = segment;
          fullRealRoute.addAll(segment);
        }
      }
    } catch (e) {
      fullRealRoute = nodesToConnect;
    }
    return fullRealRoute;
  }

  double _calculateTotalDistance(List<LatLng> points) {
    double totalDistance = 0.0;
    const double r = 6371000;

    for (int i = 0; i < points.length - 1; i++) {
      double lat1 = points[i].latitude * math.pi / 180;
      double lat2 = points[i+1].latitude * math.pi / 180;
      double deltaLat = (points[i+1].latitude - points[i].latitude) * math.pi / 180;
      double deltaLon = (points[i+1].longitude - points[i].longitude) * math.pi / 180;

      double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
          math.cos(lat1) * math.cos(lat2) *
              math.sin(deltaLon / 2) * math.sin(deltaLon / 2);
      double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      totalDistance += r * c;
    }
    return totalDistance;
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) return LatLngBounds(southwest: _swuCenter, northeast: _swuCenter);

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    if (maxLat - minLat < 0.001) {
      minLat -= 0.005; maxLat += 0.005;
    }
    if (maxLng - minLng < 0.001) {
      minLng -= 0.005; maxLng += 0.005;
    }

    double latDelta = maxLat - minLat;
    minLat -= latDelta * 0.7;

    // 💡 纵向扩展：南北各扩大到 29.79000 和 29.85000，横向保持不变
    const double limitSouthLat = 29.790000;
    const double limitNorthLat = 29.850000;
    const double limitWestLng = 106.397434;
    const double limitEastLng = 106.441554;

    minLat = math.max(limitSouthLat, minLat);
    maxLat = math.min(limitNorthLat, maxLat);
    minLng = math.max(limitWestLng, minLng);
    maxLng = math.min(limitEastLng, maxLng);

    // 终极安全防线：避免 C++ 底层死锁崩溃
    if (minLat >= maxLat) {
      minLat = limitSouthLat;
      maxLat = limitNorthLat;
    }
    if (minLng >= maxLng) {
      minLng = limitWestLng;
      maxLng = limitEastLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _resetRoute() {
    _routePlanGeneration++;
    setState(() {
      _startSpot = null;
      _endSpot = null;
      _waypoints.clear();
      _startController.text = '';
      _endController.text = '';
      _cachedPaths.clear();
      _polylines.clear();
      GuideCoordinationService.instance.clearRoute();
    });
    _fitCameraToAllSpots(animated: true);
  }

  void _zoom(bool zoomIn) {
    double newZoom = _currentCameraPosition.zoom + (zoomIn ? 1.0 : -1.0);
    _mapController?.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _currentCameraPosition.target, zoom: newZoom)), animated: true);
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = (_cachedPaths.isNotEmpty)
        ? 360.0 + (_waypoints.length * 50.0)
        : 280.0 + (_waypoints.length * 50.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('多目标校园导航', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          AMapWidget(
            mapType: MapType.normal,
            privacyStatement: const AMapPrivacyStatement(hasContains: true, hasShow: true, hasAgree: true),
            initialCameraPosition: _currentCameraPosition,
            markers: _allMarkers,
            polylines: Set<Polyline>.of(_polylines.values),
            compassEnabled: false,
            buildingsEnabled: false,
            labelsEnabled: _showLabels,
            minMaxZoomPreference: const MinMaxZoomPreference(14.0, 20.0),
            limitBounds: _mapLimitBounds,
            onMapCreated: _onMapCreated,
            onCameraMove: (position) => _currentCameraPosition = position,
          ),

          Positioned(
            top: 16, left: 16,
            child: _glassPanel(
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white.withValues(alpha: 0.82),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('地图分类图例', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.blue.shade900)),
                  const SizedBox(height: 8),
                  _buildLegendRow(240.0, '自然景观'),
                  _buildLegendRow(225.0, '教学设施'),
                  _buildLegendRow(210.0, '历史建筑'),
                  _buildLegendRow(195.0, '校园文化'),
                  _buildLegendRow(180.0, '生活服务'),
                ],
              ),
            ),
          ),

          Positioned(
            top: 16,
            right: 16,
            child: _glassPanel(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.white.withValues(alpha: 0.82),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showLabels ? Icons.visibility : Icons.visibility_off,
                    size: 16,
                    color: Colors.blue.shade800,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '地名',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.blue.shade900),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 24,
                    width: 40,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: Switch(
                        value: _showLabels,
                        activeThumbColor: Colors.blue.shade600,
                        onChanged: (val) => setState(() => _showLabels = val),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: 16,
            bottom: bottomPadding,
            child: Column(
              children: [
                _buildMapBtn(Icons.add, () => _zoom(true)),
                const SizedBox(height: 8),
                _buildMapBtn(Icons.remove, () => _zoom(false)),
                const SizedBox(height: 8),
                _buildMapBtn(Icons.gps_fixed, _useRealLocation, color: AppTheme.primary),
                const SizedBox(height: 8),
                _buildMapBtn(Icons.center_focus_strong, _centerOnUser, color: Colors.red.shade700),
              ],
            ),
          ),

          Positioned(
            left: 16, right: 16, bottom: 24,
            child: RepaintBoundary(child: _buildBottomNavPanel()),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavPanel() {
    final hasRoute = _cachedPaths.isNotEmpty;
    final statusText = hasRoute
        ? '已规划 ${_startSpot?.name ?? ''} → ${_endSpot?.name ?? ''}'
        : '点击地图大头针或输入起终点';
    return _glassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.all(12),
      color: Colors.white.withValues(alpha: 0.82),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hasRoute
                            ? [AppTheme.primary, const Color(0xFF3A86C5)]
                            : [const Color(0xFFC2DEF5), const Color(0xFF73B4E9)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasRoute ? Icons.directions_walk_rounded : Icons.explore_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '校园路线规划',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: hasRoute ? AppTheme.success : AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoadingRoute)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  GestureDetector(
                    onTap: _resetRoute,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.18)),
                      ),
                      child: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.danger),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _buildRouteDot(AppTheme.success),
                        const SizedBox(width: 8),
                        _buildSearchDropdown(isStart: true),
                      ],
                    ),
                    ..._waypoints.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          _buildRouteDot(AppTheme.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.warning.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '途经 ${entry.value.name}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textMain,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _waypoints.removeAt(entry.key));
                                      _triggerRouteWithDelay();
                                    },
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: AppTheme.textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRouteDot(AppTheme.danger),
                        const SizedBox(width: 8),
                        _buildSearchDropdown(isStart: false),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildIdentitySelector(),
              if (hasRoute) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildRouteOption(
                        '最短路程',
                        _pathTimeStrs['DISTANCE']!,
                        AppTheme.primary,
                        () {
                          setState(() => _currentStrategy = 'DISTANCE');
                          _drawCurrentRoute(autoZoom: true);
                        },
                        _currentStrategy == 'DISTANCE',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildRouteOption(
                        '最短时间',
                        _pathTimeStrs['TIME']!,
                        AppTheme.success,
                        () {
                          setState(() => _currentStrategy = 'TIME');
                          _drawCurrentRoute(autoZoom: true);
                        },
                        _currentStrategy == 'TIME',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildRouteOption(
                        '个性化',
                        _pathTimeStrs['PERSONALIZED']!,
                        const Color(0xFF8E44AD),
                        () {
                          setState(() => _currentStrategy = 'PERSONALIZED');
                          _drawCurrentRoute(autoZoom: true);
                        },
                        _currentStrategy == 'PERSONALIZED',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
    );
  }

  Widget _buildRouteDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildIdentitySelector() {
    const identities = {
      'FRESHMAN': '👩‍🎓 新生',
      'TOURIST': '🎒 游客',
      'ALUMNI': '🎓 校友',
    };
    return Row(
      children: identities.entries.map((entry) {
        final selected = _userIdentity == entry.key;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: entry.key != 'ALUMNI' ? 6 : 0,
            ),
            child: InkWell(
              onTap: () {
                setState(() => _userIdentity = entry.key);
                _triggerRouteWithDelay();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.35)
                        : AppTheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? AppTheme.darkBlue : AppTheme.textMain,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchDropdown({required bool isStart}) {
    final controller = isStart ? _startController : _endController;
    final hint = isStart ? '在地图点选或输入起点' : '在地图点选或输入终点';
    final fieldDecoration = InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textSub),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.65),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
    );

    return Expanded(
      child: Autocomplete<SpotModel>(
        optionsBuilder: (textEditingValue) {
          final query = textEditingValue.text.trim().toLowerCase();
          if (query.isEmpty) {
            return _allSpots.take(8);
          }
          return _allSpots
              .where((spot) => spot.name.toLowerCase().contains(query))
              .take(12);
        },
        displayStringForOption: (spot) => spot.name,
        onSelected: (spot) {
          controller.text = spot.name;
          setState(() {
            if (isStart) {
              _startSpot = spot;
            } else {
              _endSpot = spot;
            }
          });
          _triggerRouteWithDelay();
        },
        fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
          if (fieldController.text != controller.text) {
            fieldController.value = TextEditingValue(
              text: controller.text,
              selection: TextSelection.collapsed(offset: controller.text.length),
            );
          }
          return TextField(
            controller: fieldController,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMain),
            decoration: fieldDecoration,
            onSubmitted: (_) => onFieldSubmitted(),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220, minWidth: 180),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final spot = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                        spot.name,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
                      ),
                      subtitle: spot.category.isNotEmpty
                          ? Text(
                              spot.category,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSub),
                            )
                          : null,
                      onTap: () => onSelected(spot),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRouteOption(String title, String subtitle, Color color, VoidCallback onTap, bool isActive) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.55),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.35) : AppTheme.primary.withValues(alpha: 0.12),
            width: isActive ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isActive ? color : AppTheme.textMain,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 10,
                color: isActive ? AppTheme.textMain : AppTheme.textSub,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(double hue, String label) {
    Color displayColor;
    if (hue == 240.0) displayColor = Colors.blue.shade900;
    else if (hue == 225.0) displayColor = Colors.blue.shade700;
    else if (hue == 210.0) displayColor = Colors.blue.shade500;
    else if (hue == 195.0) displayColor = Colors.lightBlue.shade400;
    else if (hue == 180.0) displayColor = Colors.cyan.shade300;
    else displayColor = Colors.blue;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  Widget _buildMapBtn(IconData icon, VoidCallback onTap, {Color color = Colors.black87}) {
    return GestureDetector(
      onTap: onTap,
      child: _glassPanel(
        borderRadius: 14,
        padding: EdgeInsets.zero,
        color: Colors.white.withValues(alpha: 0.82),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

class _RoutePlanSnapshot {
  final SpotModel start;
  final SpotModel end;
  final List<SpotModel> waypoints;
  final String userIdentity;
  final String strategy;

  const _RoutePlanSnapshot({
    required this.start,
    required this.end,
    required this.waypoints,
    required this.userIdentity,
    required this.strategy,
  });
}