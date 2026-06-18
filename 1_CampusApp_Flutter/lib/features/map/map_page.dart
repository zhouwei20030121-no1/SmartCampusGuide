import 'dart:ui' show ImageFilter;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/network_client.dart';
import '../../core/router/app_router.dart';
import '../../features/cache/cache_service.dart';
import '../route/route_plan_args.dart';
import '../spot/spot_model.dart';
import 'map_user_location_controller.dart';

class MapPage extends StatefulWidget {
  final bool isTabVisible;

  const MapPage({super.key, this.isTabVisible = true});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const LatLng _swuCenter = LatLng(29.819000, 106.422000);

  AMapController? _mapController;
  final Map<String, Marker> _markers = {};
  List<SpotModel> _allSpots = [];
  SpotModel? _startSpot;
  SpotModel? _endSpot;
  final List<SpotModel> _waypoints = [];
  late final MapUserLocationController _userLocation = MapUserLocationController.shared;
  late final VoidCallback _userLocationListener;

  // 控制高德底图自带文字显示的开关
  bool _showLabels = true;
  Set<Marker> _allMarkersSet = const {};

  CameraPosition _currentCameraPosition = const CameraPosition(
    target: _swuCenter,
    zoom: 15.0,
    tilt: 0.0,
    bearing: 0.0,
  );

  @override
  void dispose() {
    _userLocation.detach(_userLocationListener);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabVisible && !oldWidget.isTabVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _userLocation.syncFromService(force: true);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _userLocationListener = () {
      if (!mounted) return;
      setState(_syncAllMarkers);
    };
    _userLocation.attach(_userLocationListener);
    _syncAllMarkers();
    _initMapData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _userLocation.syncFromService(force: true);
    });
  }

  void _syncAllMarkers() {
    _allMarkersSet = {..._markers.values, _userLocation.userMarker};
  }

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

  Future<void> _initMapData() async {
    final cachedRecords = await CacheService.getCachedSpots();
    if (cachedRecords.isNotEmpty && mounted) {
      final spots = cachedRecords.map((e) => SpotModel.fromJson(e)).toList();
      setState(() => _allSpots = spots);
      _generateMarkers(spots);
    }

    // 与首页「附近景点推荐」一致：直接从后端拉完整数据（含图片路径）
    try {
      final res = await NetworkClient.get('/spot/list', queryParameters: {
        'page': 1,
        'size': 1000,
      });
      if (res.data['code'] == 200 && mounted) {
        final records = res.data['data']['records'] as List;
        final spots = records
            .map((e) => SpotModel.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() => _allSpots = spots);
        _generateMarkers(spots);
        await CacheService.preloadSpots();
      }
    } catch (e) {
      debugPrint('地图页获取景点失败: $e');
    }
  }

  SpotModel? _findSpotById(int id) {
    for (final spot in _allSpots) {
      if (spot.id == id) return spot;
    }
    return null;
  }

  String _resolveSpotImageUrl(SpotModel spot) {
    String displayImageUrl = spot.coverImage.isNotEmpty
        ? spot.coverImage
        : (spot.images.isNotEmpty ? spot.images.first : '');
    if (displayImageUrl.isNotEmpty && !displayImageUrl.startsWith('http')) {
      displayImageUrl = '${NetworkClient.baseUrl}$displayImageUrl';
    }
    return displayImageUrl;
  }

  Widget _buildSpotDialogImage(SpotModel spot) {
    final displayImageUrl = _resolveSpotImageUrl(spot);
    if (displayImageUrl.isEmpty) {
      return _buildSpotImagePlaceholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: displayImageUrl,
        width: double.infinity,
        height: 150,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildSpotImagePlaceholder(),
      ),
    );
  }

  void _generateMarkers(List<SpotModel> spots) {
    final Map<String, Marker> newMarkers = {};

    for (var spot in spots) {
      double markerHue;
      // 采用深蓝到浅蓝的渐变色系
      switch (spot.category.trim()) {
        case '自然景观':
          markerHue = 240.0; // 深蓝 (深邃)
          break;
        case '教学设施':
          markerHue = 225.0; // 宝蓝 (稳重)
          break;
        case '历史建筑':
          markerHue = 210.0; // 湛蓝 (经典)
          break;
        case '校园文化':
          markerHue = 195.0; // 浅蓝 (活泼)
          break;
        case '生活服务':
          markerHue = 180.0; // 青蓝/亮蓝 (明快)
          break;
        default:
          markerHue = 210.0;
      }

      final marker = Marker(
        position: LatLng(spot.latitude, spot.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
        // 点击大头针触发详情弹窗（用 id 查完整数据，确保图片路径可用）
        onTap: (_) => _showSpotGlassDialog(spot.id),
      );

      newMarkers[spot.id.toString()] = marker;
    }

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
      _syncAllMarkers();
    });
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

  bool get _canAutoPlanRoute =>
      _startSpot != null &&
      _endSpot != null &&
      _startSpot!.id != _endSpot!.id;

  String get _routeSelectionSummary {
    if (_startSpot == null && _endSpot == null && _waypoints.isEmpty) {
      return '点击大头针选择起点、终点或途经点';
    }
    final parts = <String>[];
    if (_startSpot != null) parts.add('起点：${_startSpot!.name}');
    for (final wp in _waypoints) {
      parts.add('途经：${wp.name}');
    }
    if (_endSpot != null) parts.add('终点：${_endSpot!.name}');
    return parts.join(' · ');
  }

  void _setStartSpot(SpotModel spot) {
    setState(() {
      _startSpot = spot;
      _waypoints.removeWhere((w) => w.id == spot.id);
      if (_endSpot?.id == spot.id) _endSpot = null;
    });
  }

  void _setEndSpot(SpotModel spot) {
    setState(() {
      _endSpot = spot;
      _waypoints.removeWhere((w) => w.id == spot.id);
      if (_startSpot?.id == spot.id) _startSpot = null;
    });
  }

  void _addWaypoint(SpotModel spot) {
    if (_startSpot?.id == spot.id || _endSpot?.id == spot.id) return;
    if (_waypoints.any((w) => w.id == spot.id)) return;
    setState(() => _waypoints.add(spot));
  }

  void _resetRouteSelection() {
    setState(() {
      _startSpot = null;
      _endSpot = null;
      _waypoints.clear();
    });
  }

  void _openRoutePage() {
    Navigator.pushNamed(
      context,
      AppRouter.routePlan,
      arguments: RoutePlanArgs(
        startId: _startSpot?.id,
        endId: _endSpot?.id,
        waypointIds: _waypoints.map((e) => e.id).toList(),
        autoPlan: _canAutoPlanRoute,
      ).toMap(),
    );
  }

  // 弹窗：展示图片、文字，并可设为起点/终点/途经点
  void _showSpotGlassDialog(int spotId) {
    final spot = _findSpotById(spotId);
    if (spot == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (dialogContext) => Center(
        child: Material(
          color: Colors.transparent,
          child: _glassPanel(
            borderRadius: 16,
            padding: const EdgeInsets.all(14),
            color: Colors.white.withValues(alpha: 0.92),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(dialogContext).size.width * 0.85,
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.72,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSpotDialogImage(spot),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primary],
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
                                spot.category.isNotEmpty ? spot.category : '校园景点',
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
                          onTap: () => Navigator.pop(dialogContext),
                          child: const Icon(Icons.close, size: 18, color: AppTheme.textSub),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      spot.description.isNotEmpty ? spot.description : '暂无详细介绍',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMain, height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpotDialogAction(
                            label: '设为起点',
                            icon: Icons.trip_origin,
                            color: AppTheme.success,
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _setStartSpot(spot);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _setEndSpot(spot);
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
                        color: AppTheme.warning,
                        accent: true,
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _addWaypoint(spot);
                        },
                      ),
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

  Widget _buildSpotImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: AppTheme.lightBlue.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.photo_outlined, color: AppTheme.primary, size: 40),
    );
  }

  Widget _buildSpotDialogAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool accent = false,
  }) {
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

  Widget _buildRouteSelectionPanel() {
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
                    colors: _canAutoPlanRoute
                        ? [AppTheme.primary, AppTheme.primary]
                        : [AppTheme.primary, AppTheme.primary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _canAutoPlanRoute ? Icons.directions_walk_rounded : Icons.explore_outlined,
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
                      '路线预选',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _canAutoPlanRoute
                          ? '已选 ${_startSpot!.name} → ${_endSpot!.name}'
                          : _routeSelectionSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: _canAutoPlanRoute ? AppTheme.success : AppTheme.primary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (_startSpot != null || _endSpot != null || _waypoints.isNotEmpty)
                GestureDetector(
                  onTap: _resetRouteSelection,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_startSpot != null)
                  _buildRouteSelectionRow('起点', _startSpot!.name, AppTheme.success),
                for (final wp in _waypoints)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _buildRouteSelectionRow('途经', wp.name, AppTheme.warning),
                  ),
                if (_endSpot != null)
                  Padding(
                    padding: EdgeInsets.only(top: (_startSpot != null || _waypoints.isNotEmpty) ? 6 : 0),
                    child: _buildRouteSelectionRow('终点', _endSpot!.name, AppTheme.danger),
                  ),
                if (_startSpot == null && _endSpot == null && _waypoints.isEmpty)
                  const Text(
                    '点击地图大头针选择起点、终点或途经点',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSub, height: 1.4),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: _openRoutePage,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(_canAutoPlanRoute ? Icons.navigation_rounded : Icons.route_rounded, size: 18),
              label: Text(
                _canAutoPlanRoute ? '开始规划路线' : '前往路线规划',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSelectionRow(String label, String name, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '$label：',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMain),
          ),
        ),
      ],
    );
  }


  void _zoom(bool zoomIn) {
    double newZoom = _currentCameraPosition.zoom + (zoomIn ? 1.0 : -1.0);
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentCameraPosition.target,
          zoom: newZoom,
          tilt: 0.0,
          bearing: _currentCameraPosition.bearing,
        ),
      ),
      animated: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AMapWidget(
            mapType: MapType.normal,
            privacyStatement: const AMapPrivacyStatement(hasContains: true, hasShow: true, hasAgree: true),
            initialCameraPosition: _currentCameraPosition,
            markers: _allMarkersSet,
            compassEnabled: false,
            limitBounds: CampusBounds.interaction,
            minMaxZoomPreference: const MinMaxZoomPreference(14.0, 20.0),
            buildingsEnabled: false,
            labelsEnabled: _showLabels,
            onMapCreated: (controller) {
              _mapController = controller;
              _userLocation.syncFromService(force: true);
            },
            onCameraMove: (CameraPosition position) {
              _currentCameraPosition = position;
            },
          ),

          // 图例面板 (恢复了原来的高透明度 alpha: 0.15)
          Positioned(
            top: 50,
            left: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(color: AppTheme.primary.withValues(alpha: 0.1), blurRadius: 20)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.map_outlined, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            '西大纯净版导览图',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: AppTheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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

          // 右上角原生底图标注显示开关 (恢复高透明度)
          Positioned(
            top: 50,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.1), blurRadius: 20)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showLabels ? Icons.visibility : Icons.visibility_off,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '地名',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        height: 24,
                        width: 40,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: Switch(
                            value: _showLabels,
                            activeThumbColor: AppTheme.primary,
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

          // 缩放与定位控件
          Positioned(
            right: 16,
            bottom: 210,
            child: Column(
              children: [
                _buildMapBtn(Icons.add, () => _zoom(true)),
                const SizedBox(height: 8),
                _buildMapBtn(Icons.remove, () => _zoom(false)),
                const SizedBox(height: 8),
                _buildMapBtn(Icons.gps_fixed, _useRealLocation, color: AppTheme.primary),
                const SizedBox(height: 8),
                _buildMapBtn(Icons.center_focus_strong, _centerOnUser, color: Colors.red.shade700),
                const SizedBox(height: 8),
                _buildMapBtn(Icons.route_rounded, _openRoutePage, color: AppTheme.primary),
              ],
            ),
          ),

          // 路线预选面板
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: RepaintBoundary(child: _buildRouteSelectionPanel()),
          ),
        ],
      ),
    );
  }

  // 匹配大头针颜色的渐变蓝图例
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
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: displayColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: displayColor.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 1))
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBtn(IconData icon, VoidCallback onTap, {Color color = Colors.black87}) {
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
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.24), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}
