import 'dart:ui' show ImageFilter;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/network_client.dart';
import '../cache/cache_service.dart';
import '../guide/guide_coordination_service.dart';
import '../location/location_service.dart';
import '../spot/spot_model.dart';
import 'amap_route_api.dart';

class RoutePage extends StatefulWidget {
  final String? initialStartName;
  final List<String>? initialStartAliases;
  final String? initialDestinationName;
  final List<String>? initialDestinationAliases;

  const RoutePage({
    super.key,
    this.initialStartName,
    this.initialStartAliases,
    this.initialDestinationName,
    this.initialDestinationAliases,
  });

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  static const LatLng _swuCenter = LatLng(29.819000, 106.422000);

  AMapController? _mapController;
  final Map<String, Marker> _markers = {};
  final LocationService _locationService = LocationService();

  List<SpotModel> _allSpots = [];
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  final Map<String, Polyline> _polylines = {};
  SpotModel? _startSpot;
  SpotModel? _endSpot;
  bool _isLoadingRoute = false;

  bool _showLabels = true;

  List<LatLng>? _cachedShortPath;
  List<LatLng>? _cachedPopularPath;
  String _shortestTimeStr = '计算中...';
  String _popularTimeStr = '计算中...';

  CameraPosition _currentCameraPosition = const CameraPosition(
    target: _swuCenter,
    zoom: 15.0,
    tilt: 0.0,
    bearing: 0.0,
  );

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _loadMapData() async {
    var cachedRecords = await CacheService.getCachedSpots();
    if (cachedRecords.isEmpty) {
      await CacheService.preloadSpots();
      cachedRecords = await CacheService.getCachedSpots();
    }
    if (cachedRecords.isNotEmpty) {
      final spots = cachedRecords.map((e) => SpotModel.fromJson(e)).toList();
      setState(() {
        _allSpots = spots;
      });
      _generateMarkers(spots);
      _applyInitialStart(spots);
      _applyDefaultStart(spots);
      _applyInitialDestination(spots);
    }
  }

  void _applyInitialStart(List<SpotModel> spots) {
    final startName = widget.initialStartName?.trim();
    if (startName == null || startName.isEmpty || _startSpot != null) {
      return;
    }
    final candidates = <String>[
      startName,
      ...?widget.initialStartAliases,
      ..._knownAliasesFor(startName),
    ].where((item) => item.trim().isNotEmpty).toSet().toList();
    final matched = _findSpotByAliases(spots, candidates);
    if (matched == null) return;
    setState(() {
      _startSpot = matched;
      _startController.text = matched.name;
    });
  }

  void _applyDefaultStart(List<SpotModel> spots) {
    if (_startSpot != null) return;

    final defaultStart = _locationService.isTracking
        ? _nearestSpotToCurrentLocation(spots)
        : _findSpotByAliases(spots, const ['学行门（2号门）', '学行门', '二号门', '2号门']);

    if (defaultStart == null) return;

    setState(() {
      _startSpot = defaultStart;
      _startController.text = defaultStart.name;
    });
  }

  void _applyInitialDestination(List<SpotModel> spots) {
    final destinationName = widget.initialDestinationName?.trim();
    if (destinationName == null ||
        destinationName.isEmpty ||
        _endSpot != null) {
      return;
    }

    final candidates = <String>[
      destinationName,
      ...?widget.initialDestinationAliases,
      ..._knownAliasesFor(destinationName),
    ].where((item) => item.trim().isNotEmpty).toSet().toList();
    final normalizedTargets = candidates.map(_normalizeSpotName).toSet();

    SpotModel? matched;
    for (final spot in spots) {
      final normalizedName = _normalizeSpotName(spot.name);
      if (normalizedTargets.any(
        (target) =>
            normalizedName == target ||
            normalizedName.contains(target) ||
            target.contains(normalizedName),
      )) {
        matched = spot;
        break;
      }
    }

    matched ??= _syntheticSpotFor(candidates);
    setState(() {
      final selectedSpot = matched;
      if (selectedSpot != null &&
          !_allSpots.any((spot) => spot.id == selectedSpot.id)) {
        _allSpots = [..._allSpots, selectedSpot];
        _markers[selectedSpot.id.toString()] = Marker(
          position: LatLng(selectedSpot.latitude, selectedSpot.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(210.0),
          onTap: (_) => _handleSpotSelection(selectedSpot),
        );
      }
      _endSpot = selectedSpot;
      _endController.text = selectedSpot?.name ?? destinationName;
    });
    _checkAndTriggerRoute();
  }

  SpotModel? _nearestSpotToCurrentLocation(List<SpotModel> spots) {
    final currentLat = _locationService.latitude;
    final currentLng = _locationService.longitude;
    if (!_isValidCoordinate(currentLat, currentLng)) {
      return _findSpotByAliases(spots, const ['学行门（2号门）', '学行门', '二号门', '2号门']);
    }

    SpotModel? nearest;
    double nearestDistance = double.infinity;
    for (final spot in spots) {
      if (!_isValidCoordinate(spot.latitude, spot.longitude)) continue;
      final distance = _distanceBetween(
        LatLng(currentLat, currentLng),
        LatLng(spot.latitude, spot.longitude),
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = spot;
      }
    }
    return nearest ??
        _findSpotByAliases(spots, const ['学行门（2号门）', '学行门', '二号门', '2号门']);
  }

  SpotModel? _findSpotByAliases(List<SpotModel> spots, List<String> aliases) {
    final normalizedAliases = aliases.map(_normalizeSpotName).toSet();
    for (final spot in spots) {
      final normalizedName = _normalizeSpotName(spot.name);
      if (normalizedAliases.any(
        (alias) =>
            normalizedName == alias ||
            normalizedName.contains(alias) ||
            alias.contains(normalizedName),
      )) {
        return spot;
      }
    }
    return null;
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude != 0.0 && longitude != 0.0;
  }

  List<String> _knownAliasesFor(String destinationName) {
    final normalized = _normalizeSpotName(destinationName);
    if (normalized.contains('二教') ||
        normalized.contains('2教') ||
        normalized.contains('兰华楼') ||
        normalized.contains('西塔学院')) {
      return const ['兰华楼（第2教学楼）', '兰华楼', '第2教学楼', '第二教学楼', '2教', '西塔学院'];
    }
    if (normalized.contains('二号门') ||
        normalized.contains('2号门') ||
        normalized.contains('学行门')) {
      return const ['学行门（2号门）', '学行门', '二号门', '2号门'];
    }
    if (normalized.contains('计算机') ||
        normalized.contains('软件学院') ||
        normalized.contains('明德楼') ||
        normalized.contains('二十五教') ||
        normalized.contains('25教') ||
        normalized.contains('computer') ||
        normalized.contains('software')) {
      return const ['计算机与信息科学学院 软件学院', '计算机学院', '软件学院', '明德楼', '第25教学楼', '25教'];
    }
    return const [];
  }

  SpotModel? _syntheticSpotFor(List<String> candidates) {
    final normalizedText = candidates.map(_normalizeSpotName).join(' ');
    if (normalizedText.contains('二教') ||
        normalizedText.contains('2教') ||
        normalizedText.contains('兰华楼') ||
        normalizedText.contains('西塔学院')) {
      return SpotModel(
        id: -2002,
        name: '兰华楼（第2教学楼）',
        description: '兰华楼现为西塔学院使用。',
        latitude: 29.824500,
        longitude: 106.424316,
        category: '教学设施',
      );
    }
    return null;
  }

  String _normalizeSpotName(String value) {
    final normalized = value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('西南大学', '')
        .replaceAll('北碚校区', '')
        .replaceAll('（', '')
        .replaceAll('）', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .toLowerCase();
    return normalized
        .replaceAll('教学楼', '教')
        .replaceAll('第', '')
        .replaceAll('两', '二')
        .replaceAllMapped(
          RegExp(r'\d+'),
          (match) => _numberToChinese(match.group(0)!),
        );
  }

  String _numberToChinese(String value) {
    const digits = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    final number = int.tryParse(value);
    if (number == null) return value;
    if (number < 10) return digits[number];
    if (number == 10) return '十';
    if (number < 20) return '十${digits[number % 10]}';
    if (number < 100) {
      final ten = number ~/ 10;
      final unit = number % 10;
      return unit == 0 ? '${digits[ten]}十' : '${digits[ten]}十${digits[unit]}';
    }
    return value;
  }

  void _generateMarkers(List<SpotModel> spots) {
    final Map<String, Marker> newMarkers = {};
    for (var spot in spots) {
      double markerHue;
      // 采用深蓝到浅蓝的渐变色系
      switch (spot.category.trim()) {
        case '自然景观':
          markerHue = 240.0;
          break;
        case '教学设施':
          markerHue = 225.0;
          break;
        case '历史建筑':
          markerHue = 210.0;
          break;
        case '校园文化':
          markerHue = 195.0;
          break;
        case '生活服务':
          markerHue = 180.0;
          break;
        default:
          markerHue = 210.0;
      }

      final marker = Marker(
        position: LatLng(spot.latitude, spot.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
        onTap: (_) => _handleSpotSelection(spot),
      );
      newMarkers[spot.id.toString()] = marker;
    }
    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });
    }
  }

  void _handleSpotSelection(SpotModel spot) {
    if (_startSpot != null && _endSpot != null) return;
    _showRouteSpotGlassDialog(spot);
  }

  // 路线弹窗保持低透明度 alpha: 0.88
  void _showRouteSpotGlassDialog(SpotModel spot) {
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.82,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.blue.shade300.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      spot.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '准备前往这里还是从这里出发？',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _startSpot = spot;
                                _startController.text = spot.name;
                              });
                              _checkAndTriggerRoute();
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.blue.shade600,
                                width: 1.5,
                              ),
                              foregroundColor: Colors.blue.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '设为起点',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _endSpot = spot;
                                _endController.text = spot.name;
                              });
                              _checkAndTriggerRoute();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '设为终点',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _checkAndTriggerRoute() {
    if (_startSpot != null &&
        _endSpot != null &&
        _startSpot!.id != _endSpot!.id) {
      _cachedShortPath = null;
      _cachedPopularPath = null;
      _shortestTimeStr = '计算中...';
      _popularTimeStr = '计算中...';
      _fetchAndDrawRoute(true, autoZoom: true);
    }
  }

  Future<List<LatLng>> _getRoutePath(bool isShortest) async {
    List<LatLng> nodesToConnect = [];
    try {
      final response = await NetworkClient.get(
        '/route/plan/optimal',
        queryParameters: {
          'startId': _startSpot!.id,
          'endId': _endSpot!.id,
          'isPopularityFirst': !isShortest,
        },
      );

      if (response.data['code'] == 200) {
        List<dynamic> spotsData = response.data['data'];
        for (var spot in spotsData) {
          nodesToConnect.add(
            LatLng(
              double.tryParse(spot['latitude'].toString()) ?? 0.0,
              double.tryParse(spot['longitude'].toString()) ?? 0.0,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Java A*算法请求失败: $e");
    }

    if (nodesToConnect.length < 2) {
      nodesToConnect = [
        LatLng(_startSpot!.latitude, _startSpot!.longitude),
        LatLng(_endSpot!.latitude, _endSpot!.longitude),
      ];
    }

    List<LatLng> fullRealRoute = [];
    try {
      for (int i = 0; i < nodesToConnect.length - 1; i++) {
        List<LatLng> segment = await AMapRouteApi.getRealWalkingRoute(
          nodesToConnect[i],
          nodesToConnect[i + 1],
        );
        fullRealRoute.addAll(segment);
      }
    } catch (e) {
      fullRealRoute = nodesToConnect;
    }
    return fullRealRoute;
  }

  double _calculateTotalDistance(List<LatLng> points) {
    double totalDistance = 0.0;

    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += _distanceBetween(points[i], points[i + 1]);
    }
    return totalDistance;
  }

  double _distanceBetween(LatLng start, LatLng end) {
    const double r = 6371000;
    final double lat1 = start.latitude * math.pi / 180;
    final double lat2 = end.latitude * math.pi / 180;
    final double deltaLat = (end.latitude - start.latitude) * math.pi / 180;
    final double deltaLon = (end.longitude - start.longitude) * math.pi / 180;

    final double a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  Future<void> _fetchAndDrawRoute(
    bool isShortest, {
    bool autoZoom = false,
  }) async {
    if (_startSpot == null || _endSpot == null) return;

    setState(() {
      _isLoadingRoute = true;
      _polylines.clear();
    });

    if (_cachedShortPath == null || _cachedPopularPath == null) {
      _cachedShortPath = await _getRoutePath(true);
      _cachedPopularPath = await _getRoutePath(false);

      double shortDist = _calculateTotalDistance(_cachedShortPath!);
      int shortMin = (shortDist / 80).ceil();
      double popDist = _calculateTotalDistance(_cachedPopularPath!);
      int popMin = (popDist / 80).ceil();

      if (mounted) {
        setState(() {
          _shortestTimeStr = shortDist < 1000
              ? '约$shortMin分钟\n${shortDist.toInt()}米'
              : '约$shortMin分钟\n${(shortDist / 1000).toStringAsFixed(1)}公里';

          _popularTimeStr = popDist < 1000
              ? '约$popMin分钟\n${popDist.toInt()}米'
              : '约$popMin分钟\n${(popDist / 1000).toStringAsFixed(1)}公里';
        });
      }
    }

    if (!mounted) return;

    List<LatLng> fullRealRoute = isShortest
        ? _cachedShortPath!
        : _cachedPopularPath!;

    setState(() {
      _isLoadingRoute = false;
      final polyline = Polyline(
        points: fullRealRoute,
        width: 8,
        color: isShortest ? Colors.blueAccent : Colors.redAccent,
      );
      _polylines['calculated_route'] = polyline;
    });
    GuideCoordinationService.instance.setActiveRoute(
      points: fullRealRoute,
      routeLabel: isShortest ? '最短路线' : '体验最佳路线',
      destination: _endSpot?.name ?? '',
    );

    if (autoZoom && fullRealRoute.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _mapController?.moveCamera(
          CameraUpdate.newLatLngBounds(_calculateBounds(fullRealRoute), 100.0),
          animated: true,
        );
      });
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
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

    if (maxLat - minLat < 0.0001) {
      minLat -= 0.001;
      maxLat += 0.001;
    }
    if (maxLng - minLng < 0.0001) {
      minLng -= 0.001;
      maxLng += 0.001;
    }

    double latDelta = maxLat - minLat;
    minLat -= latDelta * 0.7;

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _resetRoute() {
    setState(() {
      _startSpot = null;
      _endSpot = null;
      _startController.text = '';
      _endController.text = '';
      _cachedShortPath = null;
      _cachedPopularPath = null;
      _polylines.clear();
      GuideCoordinationService.instance.clearRoute();
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          const CameraPosition(target: _swuCenter, zoom: 15.0),
        ),
        animated: true,
      );
    });
  }

  void _zoom(bool zoomIn) {
    double newZoom = _currentCameraPosition.zoom + (zoomIn ? 1.0 : -1.0);
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentCameraPosition.target, zoom: newZoom),
      ),
      animated: true,
    );
  }

  void _resetPosition() {
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _swuCenter, zoom: 15.0),
      ),
      animated: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = (_cachedShortPath != null) ? 310.0 : 230.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '校园路线规划',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          AMapWidget(
            mapType: MapType.normal,
            privacyStatement: const AMapPrivacyStatement(
              hasContains: true,
              hasShow: true,
              hasAgree: true,
            ),
            initialCameraPosition: _currentCameraPosition,
            markers: Set<Marker>.of(_markers.values),
            polylines: Set<Polyline>.of(_polylines.values),
            myLocationStyleOptions: MyLocationStyleOptions(true),
            compassEnabled: false,
            buildingsEnabled: false,
            labelsEnabled: _showLabels, // 绑定开关
            minMaxZoomPreference: const MinMaxZoomPreference(14.0, 20.0),
            limitBounds: LatLngBounds(
              southwest: const LatLng(29.80649, 106.402434),
              northeast: const LatLng(29.835163, 106.436554),
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) => _currentCameraPosition = position,
          ),

          // 图例面板 (恢复 alpha: 0.15)
          Positioned(
            top: 16,
            left: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.shade200.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade900.withValues(alpha: 0.1),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '地图分类图例',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
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
            ),
          ),

          // 右上角原生底图标注显示开关 (恢复 alpha: 0.15)
          Positioned(
            top: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.blue.shade200.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade900.withValues(alpha: 0.1),
                        blurRadius: 20,
                      ),
                    ],
                  ),
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        height: 24,
                        width: 40,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: Switch(
                            value: _showLabels,
                            activeColor: Colors.blue.shade600,
                            onChanged: (val) {
                              setState(() {
                                _showLabels = val;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                const SizedBox(height: 16),
                _buildMapBtn(
                  Icons.my_location,
                  _resetPosition,
                  color: Colors.blue.shade800,
                ),
              ],
            ),
          ),

          // 底部导航面板恢复最初透明度 alpha: 0.75
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.directions, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              const Text(
                                '路线规划',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_isLoadingRoute)
                                const Padding(
                                  padding: EdgeInsets.only(left: 10),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _resetRoute,
                            icon: const Icon(
                              Icons.refresh,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            label: const Text(
                              '重置',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(60, 30),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 12,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _buildSearchDropdown(isStart: true),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          _buildSearchDropdown(isStart: false),
                        ],
                      ),
                      if (_cachedShortPath != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildRouteOption(
                                '最短路程',
                                _shortestTimeStr,
                                Colors.blue,
                                () => _fetchAndDrawRoute(true, autoZoom: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildRouteOption(
                                '体验最佳',
                                _popularTimeStr,
                                Colors.red,
                                () => _fetchAndDrawRoute(false, autoZoom: true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchDropdown({required bool isStart}) {
    final controller = isStart ? _startController : _endController;
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return DropdownMenu<SpotModel>(
            width: constraints.maxWidth,
            controller: controller,
            hintText: isStart ? '在地图点选或输入起点' : '在地图点选或输入终点',
            menuHeight: 250,
            inputDecorationTheme: InputDecorationTheme(
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.blue.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.blue.withValues(alpha: 0.1),
                ),
              ),
            ),
            dropdownMenuEntries: _allSpots.map((spot) {
              return DropdownMenuEntry<SpotModel>(
                value: spot,
                label: spot.name,
              );
            }).toList(),
            onSelected: (SpotModel? spot) {
              if (spot != null) {
                setState(() {
                  if (isStart) {
                    _startSpot = spot;
                  } else {
                    _endSpot = spot;
                  }
                });
                _checkAndTriggerRoute();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildRouteOption(
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: Colors.black87,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 匹配大头针的渐变蓝配色图例
  Widget _buildLegendRow(double hue, String label) {
    Color displayColor;
    if (hue == 240.0)
      displayColor = Colors.blue.shade900;
    else if (hue == 225.0)
      displayColor = Colors.blue.shade700;
    else if (hue == 210.0)
      displayColor = Colors.blue.shade500;
    else if (hue == 195.0)
      displayColor = Colors.lightBlue.shade400;
    else if (hue == 180.0)
      displayColor = Colors.cyan.shade300;
    else
      displayColor = Colors.blue;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: displayColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBtn(
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.black87,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(
                alpha: 0.6,
              ), // 恢复 alpha: 0.6
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.blue.shade200.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}
