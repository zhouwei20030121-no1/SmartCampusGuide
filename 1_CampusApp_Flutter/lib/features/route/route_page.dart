// 文件路径: lib/features/route/route_page.dart

import 'dart:ui' show ImageFilter;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/network_client.dart';
import '../cache/cache_service.dart';
import '../spot/spot_model.dart';
import 'amap_route_api.dart';

class RoutePage extends StatefulWidget {
  const RoutePage({super.key});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  static const LatLng _swuCenter = LatLng(29.819000, 106.422000);

  AMapController? _mapController;
  final Map<String, Marker> _markers = {};

  // 所有景点的缓存（用于搜索和下拉）
  List<SpotModel> _allSpots = [];

  // 输入框控制器
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  // 路线规划核心状态
  final Map<String, Polyline> _polylines = {};
  SpotModel? _startSpot;
  SpotModel? _endSpot;
  bool _isLoadingRoute = false;

  // 缓存路线和动态时间文本
  List<LatLng>? _cachedShortPath;
  List<LatLng>? _cachedPopularPath;
  String _shortestTimeStr = '计算中...';
  String _popularTimeStr = '计算中...';

  CameraPosition _currentCameraPosition = const CameraPosition(
    target: _swuCenter, zoom: 15.0, tilt: 0.0, bearing: 0.0,
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
    final cachedRecords = await CacheService.getCachedSpots();
    if (cachedRecords.isNotEmpty) {
      final spots = cachedRecords.map((e) => SpotModel.fromJson(e)).toList();
      setState(() {
        _allSpots = spots;
      });
      _generateMarkers(spots);
    }
  }

  void _generateMarkers(List<SpotModel> spots) {
    final Map<String, Marker> newMarkers = {};
    for (var spot in spots) {
      double markerHue;
      switch (spot.category.trim()) {
        case '自然景观': markerHue = BitmapDescriptor.hueGreen; break;
        case '教学设施': markerHue = BitmapDescriptor.hueAzure; break;
        case '历史建筑': markerHue = BitmapDescriptor.hueOrange; break;
        case '校园文化': markerHue = BitmapDescriptor.hueViolet; break;
        case '生活服务': markerHue = BitmapDescriptor.hueCyan; break;
        default: markerHue = BitmapDescriptor.hueRed;
      }

      final marker = Marker(
        position: LatLng(spot.latitude, spot.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
        infoWindow: InfoWindow(title: spot.name, snippet: spot.description),
        onTap: (markerId) => _handleSpotSelection(spot),
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

  // 🌟 修改：优化地图选点防误触逻辑
  void _handleSpotSelection(SpotModel spot) {
    // 核心锁定逻辑：如果起点和终点都已经选好（已在规划或展示路线），
    // 直接 return 拦截点击事件。此时高德地图只会弹出自带的名字框，不会修改数据。
    if (_startSpot != null && _endSpot != null) {
      return;
    }

    setState(() {
      if (_startSpot == null) {
        _startSpot = spot;
        _startController.text = spot.name; // 同步到输入框
      } else if (_endSpot == null && spot.id != _startSpot!.id) {
        _endSpot = spot;
        _endController.text = spot.name; // 同步到输入框
        _checkAndTriggerRoute(); // 选好后自动寻路
      }
    });
  }

  // 检查起点终点是否齐全，齐全则规划路线
  void _checkAndTriggerRoute() {
    if (_startSpot != null && _endSpot != null && _startSpot!.id != _endSpot!.id) {
      // 改变目标，重置缓存
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
      final response = await NetworkClient.get('/route/plan/optimal', queryParameters: {
        'startId': _startSpot!.id,
        'endId': _endSpot!.id,
        'isPopularityFirst': !isShortest
      });

      if (response.data['code'] == 200) {
        List<dynamic> spotsData = response.data['data'];
        for (var spot in spotsData) {
          nodesToConnect.add(LatLng(
            double.tryParse(spot['latitude'].toString()) ?? 0.0,
            double.tryParse(spot['longitude'].toString()) ?? 0.0,
          ));
        }
      }
    } catch (e) {
      debugPrint("Java A*算法请求失败: $e");
    }

    if (nodesToConnect.length < 2) {
      nodesToConnect = [
        LatLng(_startSpot!.latitude, _startSpot!.longitude),
        LatLng(_endSpot!.latitude, _endSpot!.longitude)
      ];
    }

    List<LatLng> fullRealRoute = [];
    try {
      for (int i = 0; i < nodesToConnect.length - 1; i++) {
        List<LatLng> segment = await AMapRouteApi.getRealWalkingRoute(nodesToConnect[i], nodesToConnect[i + 1]);
        fullRealRoute.addAll(segment);
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

  Future<void> _fetchAndDrawRoute(bool isShortest, {bool autoZoom = false}) async {
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
              : '约$shortMin分钟\n${(shortDist/1000).toStringAsFixed(1)}公里';

          _popularTimeStr = popDist < 1000
              ? '约$popMin分钟\n${popDist.toInt()}米'
              : '约$popMin分钟\n${(popDist/1000).toStringAsFixed(1)}公里';
        });
      }
    }

    if (!mounted) return;

    List<LatLng> fullRealRoute = isShortest ? _cachedShortPath! : _cachedPopularPath!;

    setState(() {
      _isLoadingRoute = false;
      final polyline = Polyline(
        points: fullRealRoute,
        width: 8,
        color: isShortest ? Colors.blueAccent : Colors.redAccent,
      );
      _polylines['calculated_route'] = polyline;
    });

    if (autoZoom && fullRealRoute.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _mapController?.moveCamera(
          CameraUpdate.newLatLngBounds(
            _calculateBounds(fullRealRoute),
            100.0,
          ),
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
      minLat -= 0.001; maxLat += 0.001;
    }
    if (maxLng - minLng < 0.0001) {
      minLng -= 0.001; maxLng += 0.001;
    }

    // 视觉补偿：底部留给面板空间
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
      // 🌟 重置时恢复到初始居中视角，方便重新选点
      _mapController?.moveCamera(CameraUpdate.newCameraPosition(const CameraPosition(target: _swuCenter, zoom: 15.0)), animated: true);
    });
  }

  void _zoom(bool zoomIn) {
    double newZoom = _currentCameraPosition.zoom + (zoomIn ? 1.0 : -1.0);
    _mapController?.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _currentCameraPosition.target, zoom: newZoom)), animated: true);
  }

  void _resetPosition() {
    _mapController?.moveCamera(CameraUpdate.newCameraPosition(const CameraPosition(target: _swuCenter, zoom: 15.0)), animated: true);
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = (_cachedShortPath != null) ? 310.0 : 230.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('校园路线规划', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          // 1. 🌏 地图主体
          AMapWidget(
            mapType: MapType.normal,
            privacyStatement: const AMapPrivacyStatement(hasContains: true, hasShow: true, hasAgree: true),
            initialCameraPosition: _currentCameraPosition,
            markers: Set<Marker>.of(_markers.values),
            polylines: Set<Polyline>.of(_polylines.values),
            myLocationStyleOptions: MyLocationStyleOptions(true),

            compassEnabled: false,
            buildingsEnabled: false,
            labelsEnabled: false,
            minMaxZoomPreference: const MinMaxZoomPreference(14.0, 20.0),
            limitBounds: LatLngBounds(
              southwest: const LatLng(29.80649, 106.402434),
              northeast: const LatLng(29.835163, 106.436554),
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) => _currentCameraPosition = position,
          ),

          // 2. 🛠️ 左上角图例
          Positioned(
            top: 16, left: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('地图分类图例', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black87)),
                      const SizedBox(height: 8),
                      _buildLegendRow(BitmapDescriptor.hueGreen, '自然景观'),
                      _buildLegendRow(BitmapDescriptor.hueAzure, '教学设施'),
                      _buildLegendRow(BitmapDescriptor.hueOrange, '历史建筑'),
                      _buildLegendRow(BitmapDescriptor.hueViolet, '校园文化'),
                      _buildLegendRow(BitmapDescriptor.hueCyan, '生活服务'),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. 🛠️ 缩放与定位按钮
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
                _buildMapBtn(Icons.my_location, _resetPosition, color: AppTheme.primary),
              ],
            ),
          ),

          // 4. 🌟 常驻底部路线规划面板
          Positioned(
            left: 16, right: 16, bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
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
                          const Text('路线规划', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          if (_isLoadingRoute)
                            const Padding(
                                padding: EdgeInsets.only(left: 10),
                                child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            )
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _resetRoute,
                        icon: const Icon(Icons.refresh, size: 16, color: Colors.redAccent),
                        label: const Text('重置', style: TextStyle(color: Colors.redAccent)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 30)),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Icon(Icons.circle, size: 12, color: Colors.green),
                      const SizedBox(width: 8),
                      _buildSearchDropdown(isStart: true),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.red),
                      const SizedBox(width: 8),
                      _buildSearchDropdown(isStart: false),
                    ],
                  ),

                  if (_cachedShortPath != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildRouteOption('最短路程', _shortestTimeStr, Colors.blue, () => _fetchAndDrawRoute(true, autoZoom: true))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildRouteOption('体验最佳', _popularTimeStr, Colors.red, () => _fetchAndDrawRoute(false, autoZoom: true))),
                      ],
                    ),
                  ]
                ],
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
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
          }
      ),
    );
  }

  Widget _buildRouteOption(String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black87, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(double hue, String label) {
    Color displayColor;
    if (hue == BitmapDescriptor.hueGreen) displayColor = Colors.green;
    else if (hue == BitmapDescriptor.hueAzure) displayColor = Colors.blue;
    else if (hue == BitmapDescriptor.hueOrange) displayColor = Colors.orange;
    else if (hue == BitmapDescriptor.hueViolet) displayColor = Colors.purple;
    else if (hue == BitmapDescriptor.hueCyan) displayColor = Colors.cyan;
    else displayColor = Colors.red;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMapBtn(IconData icon, VoidCallback onTap, {Color color = Colors.black87}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}