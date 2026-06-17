import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/network/network_client.dart';
import '../../core/theme/app_theme.dart';
import '../cache/cache_service.dart';
import '../location/location_service.dart';
import '../spot/spot_model.dart';
import 'amap_route_api.dart';

class RoutePage extends StatefulWidget {
  const RoutePage({
    super.key,
    this.initialStartId,
    this.initialEndId,
    this.initialStartName,
    this.initialStartAliases,
    this.initialDestinationName,
    this.initialDestinationAliases,
  });

  final int? initialStartId;
  final int? initialEndId;
  final String? initialStartName;
  final List<String>? initialStartAliases;
  final String? initialDestinationName;
  final List<String>? initialDestinationAliases;

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  static const _swuCenter = LatLng(29.8218, 106.4256);
  static const _tileUrlClean =
      'https://wprd0{s}.is.autonavi.com/appmaptile?x={x}&y={y}&z={z}&lang=zh_cn&size=1&scl=1&style=7&ltype=3';

  final MapController _mapController = MapController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  List<SpotModel> _allSpots = [];
  List<SpotModel> _routeSpots = [];
  List<LatLng> _routePoints = [];
  SpotModel? _startSpot;
  SpotModel? _endSpot;
  _RouteData? _shortestRoute;
  _RouteData? _popularRoute;
  bool _isLoadingSpots = true;
  bool _isLoadingRoute = false;
  bool _usePopularRoute = false;
  bool _showLabels = true;
  double _zoom = 16.0;

  @override
  void initState() {
    super.initState();
    _loadSpots();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _loadSpots() async {
    setState(() => _isLoadingSpots = true);
    final spots = <SpotModel>[];

    try {
      final cachedRecords = await CacheService.getCachedSpots();
      spots.addAll(cachedRecords.map((e) => SpotModel.fromJson(e)));
    } catch (_) {}

    try {
      await CacheService.preloadSpots();
      final latestRecords = await CacheService.getCachedSpots();
      spots
        ..clear()
        ..addAll(latestRecords.map((e) => SpotModel.fromJson(e)));
    } catch (_) {}

    if (spots.isEmpty) {
      try {
        final response = await NetworkClient.get(
          '/spot/list',
          queryParameters: {'page': 1, 'size': 200},
        );
        final records =
            response.data['data']?['records'] as List<dynamic>? ?? [];
        spots.addAll(
          records.map(
            (item) => SpotModel.fromJson(item as Map<String, dynamic>),
          ),
        );
      } catch (_) {}
    }

    final validSpots =
        spots
            .where(
              (spot) => _isValidCampusCoordinate(spot.latitude, spot.longitude),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    _allSpots = validSpots.isEmpty ? _fallbackRouteSpots : validSpots;

    _startSpot = _findInitialSpot(
      id: widget.initialStartId,
      name: widget.initialStartName,
      aliases: widget.initialStartAliases,
    );
    if (_startSpot == null) {
      final loc = LocationService();
      _startSpot = _findNearestSpotToLocation(loc.latitude, loc.longitude);
    }

    _endSpot = _findInitialSpot(
      id: widget.initialEndId,
      name: widget.initialDestinationName,
      aliases: widget.initialDestinationAliases,
    );

    if (_endSpot == null &&
        widget.initialDestinationName != null &&
        widget.initialDestinationName!.isNotEmpty) {
      final poiLatLng = await AMapRouteApi.searchPoiCoordinates(
        widget.initialDestinationName!,
      );
      if (poiLatLng != null) {
        _endSpot = _findNearestSpotToLocation(
          poiLatLng.latitude,
          poiLatLng.longitude,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _startController.text = _startSpot?.name ?? '';
      _endController.text = _endSpot?.name ?? '';
      _isLoadingSpots = false;
    });

    _focusInitialSelection();
    _checkAndTriggerRoute();
  }

  SpotModel? _findNearestSpotToLocation(double lat, double lng) {
    if (lat == 0.0 || lng == 0.0 || _allSpots.isEmpty) return null;
    SpotModel? nearest;
    double minDistance = double.infinity;
    for (final spot in _allSpots) {
      final dx = (spot.longitude - lng) * 111320 * 0.866;
      final dy = (spot.latitude - lat) * 111320;
      final dist = dx * dx + dy * dy;
      if (dist < minDistance) {
        minDistance = dist;
        nearest = spot;
      }
    }
    return nearest;
  }

  SpotModel? _findInitialSpot({int? id, String? name, List<String>? aliases}) {
    if (id != null) {
      for (final spot in _allSpots) {
        if (spot.id == id) return spot;
      }
    }
    if (name != null && name.isNotEmpty) {
      final possibleNames = [name, ...?aliases];
      final mappedSpot = _findMappedSpot(possibleNames);
      if (mappedSpot != null) return mappedSpot;

      for (final possibleName in possibleNames) {
        if (possibleName.isEmpty) continue;
        for (final spot in _allSpots) {
          if (_isSameOrAliasSpot(spot.name, possibleName)) {
            return spot;
          }
        }
      }
    }
    return null;
  }

  SpotModel? _findMappedSpot(List<String?> possibleNames) {
    for (final possibleName in possibleNames) {
      if (possibleName == null || possibleName.isEmpty) continue;
      final group = _findAliasGroup(possibleName);
      if (group == null) continue;
      for (final candidateName in group.names) {
        for (final spot in _allSpots) {
          if (_isDirectNameMatch(spot.name, candidateName)) {
            return spot;
          }
        }
      }
    }
    return null;
  }

  bool _isSameOrAliasSpot(String spotName, String possibleName) {
    if (_isDirectNameMatch(spotName, possibleName)) return true;
    final group = _findAliasGroup(possibleName);
    if (group == null) return false;
    return group.names.any((name) => _isDirectNameMatch(spotName, name));
  }

  bool _isDirectNameMatch(String spotName, String possibleName) {
    final normalizedSpot = _normalizeSpotName(spotName);
    final normalizedPossible = _normalizeSpotName(possibleName);
    if (normalizedSpot.isEmpty || normalizedPossible.isEmpty) return false;
    return normalizedSpot == normalizedPossible ||
        normalizedSpot.contains(normalizedPossible) ||
        normalizedPossible.contains(normalizedSpot);
  }

  _SpotAliasGroup? _findAliasGroup(String value) {
    final normalized = _normalizeSpotName(value);
    if (normalized.isEmpty) return null;
    for (final group in _spotAliasGroups) {
      if (group.normalizedNames.any(
        (alias) => alias == normalized || normalized.contains(alias),
      )) {
        return group;
      }
    }
    return null;
  }

  String _normalizeSpotName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('西南大学', '')
        .replaceAll('北碚校区', '')
        .replaceAll('（', '')
        .replaceAll('）', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
  }

  bool _isValidCampusCoordinate(double latitude, double longitude) {
    return latitude >= 29.75 &&
        latitude <= 29.90 &&
        longitude >= 106.35 &&
        longitude <= 106.50;
  }

  String _categoryOf(SpotModel spot) {
    final category = spot.category.trim();
    return category.isEmpty || category == 'default' ? '校园地点' : category;
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case '自然景观':
        return Colors.blue.shade900;
      case '教学设施':
        return Colors.blue.shade700;
      case '历史建筑':
        return Colors.blue.shade500;
      case '校园文化':
        return Colors.lightBlue.shade500;
      case '生活服务':
        return Colors.cyan.shade500;
      default:
        return AppTheme.primary;
    }
  }

  IconData _iconForSpot(SpotModel spot) {
    final text = '${spot.name}${spot.category}';
    if (text.contains('门')) return Icons.flag;
    if (text.contains('图书馆')) return Icons.local_library;
    if (text.contains('体育') || text.contains('运动')) {
      return Icons.sports_basketball;
    }
    if (text.contains('学院') || text.contains('教学')) return Icons.school;
    if (text.contains('食堂') || text.contains('餐')) return Icons.restaurant;
    if (text.contains('广场') || text.contains('园')) return Icons.park;
    return Icons.place;
  }

  void _focusInitialSelection() {
    final points = <LatLng>[
      if (_startSpot != null) _toPoint(_startSpot!),
      if (_endSpot != null) _toPoint(_endSpot!),
    ];
    if (points.length >= 2) {
      _fitPoints(points);
    } else if (points.length == 1) {
      _moveTo(points.first, zoom: 17.2);
    }
  }

  LatLng _toPoint(SpotModel spot) => LatLng(spot.latitude, spot.longitude);

  void _moveTo(LatLng point, {double zoom = 17.0}) {
    _mapController.move(point, zoom);
    setState(() => _zoom = zoom);
  }

  void _zoomBy(double delta) {
    final nextZoom = (_zoom + delta).clamp(12.0, 19.0);
    _mapController.move(_mapController.camera.center, nextZoom);
    setState(() => _zoom = nextZoom);
  }

  void _resetPosition() {
    if (_routePoints.length >= 2) {
      _fitPoints(_routePoints);
      return;
    }
    _mapController.move(_swuCenter, 16.0);
    setState(() => _zoom = 16.0);
  }

  void _fitPoints(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _moveTo(points.first);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(54, 92, 54, 310),
          maxZoom: 17.6,
        ),
      );
      _zoom = _mapController.camera.zoom;
    });
  }

  void _selectSpot(SpotModel spot, {required bool asStart}) {
    setState(() {
      if (asStart) {
        _startSpot = spot;
        _startController.text = spot.name;
      } else {
        _endSpot = spot;
        _endController.text = spot.name;
      }
      _shortestRoute = null;
      _popularRoute = null;
      _routePoints = [];
      _routeSpots = [];
    });
    _moveTo(_toPoint(spot));
    _checkAndTriggerRoute();
  }

  void _showSpotPicker(SpotModel spot) {
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
                width: MediaQuery.of(context).size.width * 0.84,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.22),
                    width: 1.4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _RouteMarkerDot(
                          color: _colorForCategory(_categoryOf(spot)),
                          icon: _iconForSpot(spot),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            spot.name,
                            style: const TextStyle(
                              color: AppTheme.textMain,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '选择这个地点在路线中的位置',
                      style: TextStyle(
                        color: AppTheme.textSub.withValues(alpha: 0.88),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _selectSpot(spot, asStart: true);
                            },
                            icon: const Icon(Icons.trip_origin, size: 18),
                            label: const Text('设为起点'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _selectSpot(spot, asStart: false);
                            },
                            icon: const Icon(Icons.location_on, size: 18),
                            label: const Text('设为终点'),
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
    if (_startSpot == null || _endSpot == null) return;
    if (_startSpot!.id == _endSpot!.id) return;
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    if (_startSpot == null || _endSpot == null) return;
    setState(() => _isLoadingRoute = true);

    final shortest = await _fetchRoute(isPopularityFirst: false);
    final popular = await _fetchRoute(isPopularityFirst: true);

    if (!mounted) return;
    setState(() {
      _shortestRoute = shortest;
      _popularRoute = popular;
      _isLoadingRoute = false;
    });
    _applyRoute(_usePopularRoute ? popular : shortest, autoZoom: true);
  }

  Future<_RouteData> _fetchRoute({required bool isPopularityFirst}) async {
    List<SpotModel> route = [];

    try {
      final response = await NetworkClient.get(
        '/route/plan/optimal',
        queryParameters: {
          'startId': _startSpot!.id,
          'endId': _endSpot!.id,
          'isPopularityFirst': isPopularityFirst,
        },
      );

      if (response.data['code'] == 200 && response.data['data'] is List) {
        route = (response.data['data'] as List)
            .map((item) => SpotModel.fromJson(item as Map<String, dynamic>))
            .where(
              (spot) => _isValidCampusCoordinate(spot.latitude, spot.longitude),
            )
            .toList();
      }
    } catch (_) {
      route = [];
    }

    if (route.length < 2) {
      route = [_startSpot!, _endSpot!];
    }

    final nodes = route.map(_toPoint).toList();
    final points = await _buildWalkingPath(nodes);
    final distance = _calculateTotalDistance(points);
    return _RouteData(
      spots: route,
      points: points,
      distance: distance,
      minutes: math.max(1, (distance / 80).ceil()),
    );
  }

  Future<List<LatLng>> _buildWalkingPath(List<LatLng> nodes) async {
    if (nodes.length < 2) return nodes;

    final realPath = <LatLng>[];
    for (int i = 0; i < nodes.length - 1; i++) {
      final segment = await AMapRouteApi.getRealWalkingRoute(
        nodes[i],
        nodes[i + 1],
      );
      if (segment.isEmpty) continue;
      if (realPath.isNotEmpty && realPath.last == segment.first) {
        realPath.addAll(segment.skip(1));
      } else {
        realPath.addAll(segment);
      }
    }

    return realPath.length >= 2 ? realPath : nodes;
  }

  void _applyRoute(_RouteData route, {bool autoZoom = false}) {
    setState(() {
      _routeSpots = route.spots;
      _routePoints = route.points;
    });
    if (autoZoom) _fitPoints(route.points);
  }

  double _calculateTotalDistance(List<LatLng> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final lat1 = a.latitude * math.pi / 180;
      final lat2 = b.latitude * math.pi / 180;
      final deltaLat = (b.latitude - a.latitude) * math.pi / 180;
      final deltaLon = (b.longitude - a.longitude) * math.pi / 180;
      final h =
          math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
          math.cos(lat1) *
              math.cos(lat2) *
              math.sin(deltaLon / 2) *
              math.sin(deltaLon / 2);
      total += 6371000 * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    }
    return total;
  }

  void _resetRoute() {
    setState(() {
      _startSpot = null;
      _endSpot = null;
      _routeSpots = [];
      _routePoints = [];
      _shortestRoute = null;
      _popularRoute = null;
      _usePopularRoute = false;
      _startController.clear();
      _endController.clear();
    });
    _mapController.move(_swuCenter, 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = _usePopularRoute ? _popularRoute : _shortestRoute;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '校园路线规划',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textMain,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _swuCenter,
              initialZoom: _zoom,
              minZoom: 12.0,
              maxZoom: 19.0,
              onPositionChanged: (position, hasGesture) {
                _zoom = position.zoom;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrlClean,
                subdomains: const ['1', '2', '3', '4'],
                userAgentPackageName: 'com.swu.smartCampusGuide',
                maxZoom: 19,
              ),
              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 7,
                      color: _usePopularRoute
                          ? Colors.redAccent
                          : AppTheme.primary,
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          Positioned(top: 16, right: 16, child: _buildLabelToggle()),
          Positioned(
            right: 16,
            bottom: selectedRoute == null ? 236 : 330,
            child: Column(
              children: [
                _MapActionButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                const SizedBox(height: 8),
                _MapActionButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                const SizedBox(height: 12),
                _MapActionButton(
                  icon: Icons.my_location,
                  color: AppTheme.primary,
                  onTap: _resetPosition,
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: _buildPlannerPanel(selectedRoute),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    return _allSpots.map((spot) {
      final isStart = _startSpot?.id == spot.id;
      final isEnd = _endSpot?.id == spot.id;
      final color = isStart
          ? Colors.green
          : isEnd
          ? Colors.redAccent
          : _colorForCategory(_categoryOf(spot));
      return Marker(
        point: _toPoint(spot),
        width: isStart || isEnd ? 126 : (_showLabels ? 96 : 44),
        height: isStart || isEnd ? 70 : (_showLabels ? 64 : 44),
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () => _showSpotPicker(spot),
          child: _RouteMapMarker(
            label: isStart
                ? '起点'
                : isEnd
                ? '终点'
                : (_showLabels ? spot.name : null),
            color: color,
            icon: isStart
                ? Icons.trip_origin
                : isEnd
                ? Icons.location_on
                : _iconForSpot(spot),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildLabelToggle() {
    return _GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _showLabels ? Icons.visibility : Icons.visibility_off,
            size: 16,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 6),
          const Text(
            '建筑名',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppTheme.textMain,
            ),
          ),
          Switch(
            value: _showLabels,
            activeThumbColor: AppTheme.primary,
            onChanged: (value) => setState(() => _showLabels = value),
          ),
        ],
      ),
    );
  }

  Widget _buildPlannerPanel(_RouteData? selectedRoute) {
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.directions, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '路线规划',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (_isLoadingSpots || _isLoadingRoute)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              TextButton.icon(
                onPressed: _resetRoute,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重置'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.circle, size: 12, color: Colors.green),
              const SizedBox(width: 8),
              _buildSpotDropdown(isStart: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
              const SizedBox(width: 6),
              _buildSpotDropdown(isStart: false),
            ],
          ),
          if (_shortestRoute != null && _popularRoute != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _RouteOption(
                    title: '最短路程',
                    summary: _shortestRoute!.summary,
                    color: AppTheme.primary,
                    selected: !_usePopularRoute,
                    onTap: () {
                      setState(() => _usePopularRoute = false);
                      _applyRoute(_shortestRoute!, autoZoom: true);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RouteOption(
                    title: '体验优先',
                    summary: _popularRoute!.summary,
                    color: Colors.redAccent,
                    selected: _usePopularRoute,
                    onTap: () {
                      setState(() => _usePopularRoute = true);
                      _applyRoute(_popularRoute!, autoZoom: true);
                    },
                  ),
                ),
              ],
            ),
          ],
          if (selectedRoute != null) ...[
            const SizedBox(height: 12),
            _buildRouteSteps(),
          ],
        ],
      ),
    );
  }

  Widget _buildSpotDropdown({required bool isStart}) {
    final controller = isStart ? _startController : _endController;
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return DropdownMenu<SpotModel>(
            width: constraints.maxWidth,
            controller: controller,
            hintText: isStart ? '在地图点选或输入起点' : '在地图点选或输入终点',
            menuHeight: 260,
            inputDecorationTheme: InputDecorationTheme(
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.62),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.14),
                ),
              ),
            ),
            dropdownMenuEntries: _allSpots.map((spot) {
              return DropdownMenuEntry<SpotModel>(
                value: spot,
                label: spot.name,
              );
            }).toList(),
            onSelected: (spot) {
              if (spot == null) return;
              _selectSpot(spot, asStart: isStart);
            },
          );
        },
      ),
    );
  }

  Widget _buildRouteSteps() {
    final spots = _routeSpots.take(5).toList();
    return Container(
      constraints: const BoxConstraints(maxHeight: 116),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: spots.length,
        separatorBuilder: (context, index) => Divider(
          color: AppTheme.primary.withValues(alpha: 0.08),
          height: 12,
        ),
        itemBuilder: (context, index) {
          final spot = spots[index];
          final isLast = index == spots.length - 1;
          return Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isLast ? Colors.redAccent : AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  spot.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RouteData {
  const _RouteData({
    required this.spots,
    required this.points,
    required this.distance,
    required this.minutes,
  });

  final List<SpotModel> spots;
  final List<LatLng> points;
  final double distance;
  final int minutes;

  String get summary {
    final distanceText = distance < 1000
        ? '${distance.toInt()}米'
        : '${(distance / 1000).toStringAsFixed(1)}公里';
    return '约$minutes分钟\n$distanceText';
  }
}

class _RouteMapMarker extends StatelessWidget {
  const _RouteMapMarker({required this.color, required this.icon, this.label});

  final Color color;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RouteMarkerDot(color: color, icon: icon),
        if (label != null) ...[
          const SizedBox(height: 3),
          Container(
            constraints: const BoxConstraints(maxWidth: 92),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0x18000000), blurRadius: 4),
              ],
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textMain,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RouteMarkerDot extends StatelessWidget {
  const _RouteMarkerDot({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 19),
    );
  }
}

class _RouteOption extends StatelessWidget {
  const _RouteOption({
    required this.title,
    required this.summary,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String summary;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.2),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              summary,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textMain,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.84)),
            boxShadow: const [
              BoxShadow(color: Color(0x16000000), blurRadius: 12),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.onTap,
    this.color = AppTheme.textMain,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GlassPanel(
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

class _SpotAliasGroup {
  final List<String> names;

  const _SpotAliasGroup(this.names);

  List<String> get normalizedNames => names
      .map(
        (name) => name
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '')
            .replaceAll('西南大学', '')
            .replaceAll('北碚校区', '')
            .replaceAll('（', '')
            .replaceAll('）', '')
            .replaceAll('(', '')
            .replaceAll(')', ''),
      )
      .where((name) => name.isNotEmpty)
      .toList();
}

const _spotAliasGroups = [
  _SpotAliasGroup([
    '物理科学与技术学院',
    '物理科学技术学院',
    '物理学院',
    '立惠楼（第13教学楼）',
    '立惠楼',
    '第13教学楼',
    '第十三教学楼',
    '13教',
    '十三教',
    'physics college',
    'physics',
  ]),
  _SpotAliasGroup([
    '计算机与信息科学学院 软件学院',
    '计算机与信息科学学院',
    '计算机科学学院',
    '计算机学院',
    '软件学院',
    '计科院',
    '明德楼',
    '第25教学楼',
    '第二十五教学楼',
    '25教',
    '二十五教',
    'computer college',
    'computer science college',
    'software college',
    'cis',
  ]),
  _SpotAliasGroup([
    '数学与统计学院',
    '数学统计学院',
    '数学学院',
    '数统院',
    '弘学楼',
    '第12教学楼',
    '第十二教学楼',
    '12教',
    '十二教',
  ]),
  _SpotAliasGroup([
    '新闻传媒学院',
    '新传院',
    '新闻学院',
    '传媒学院',
    '咏修楼',
    '第4教学楼',
    '第四教学楼',
    '4教',
    '四教',
  ]),
  _SpotAliasGroup([
    '生命科学学院',
    '生命科学院',
    '生科院',
    '白南楼',
    '第14教学楼',
    '第十四教学楼',
    '14教',
    '十四教',
  ]),
  _SpotAliasGroup(['学行门（2号门）', '学行门', '二号门', '2号门']),
];

List<SpotModel> get _fallbackRouteSpots {
  return [
    SpotModel(
      id: 33,
      name: '1号门（含弘门）',
      description: '西南大学主校门，常用入校点。',
      latitude: 29.828249,
      longitude: 106.434540,
      category: '校园文化',
    ),
    SpotModel(
      id: 34,
      name: '2号门（学行门）',
      description: '天生路主入口，靠近南樟林。',
      latitude: 29.813447,
      longitude: 106.421480,
      category: '校园文化',
    ),
    SpotModel(
      id: 36,
      name: '中心图书馆',
      description: '北区核心学习空间。',
      latitude: 29.820623,
      longitude: 106.424507,
      category: '教学设施',
    ),
    SpotModel(
      id: 37,
      name: '南区图书馆',
      description: '南区学习服务点。',
      latitude: 29.813498,
      longitude: 106.419011,
      category: '教学设施',
    ),
    SpotModel(
      id: 24,
      name: '计算机与信息科学学院 软件学院',
      description: '计科院 / 软件学院相关教学办公楼。',
      latitude: 29.822640,
      longitude: 106.424379,
      category: '教学设施',
    ),
    SpotModel(
      id: 13,
      name: '物理科学与技术学院',
      description: '位于立惠楼（第13教学楼）。',
      latitude: 29.820956,
      longitude: 106.421432,
      category: '教学设施',
    ),
    SpotModel(
      id: 39,
      name: '中心体育馆',
      description: '校内体育场馆。',
      latitude: 29.818364,
      longitude: 106.424483,
      category: '生活服务',
    ),
  ];
}
