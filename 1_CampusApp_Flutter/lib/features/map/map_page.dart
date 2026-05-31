import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import '../../core/theme/app_theme.dart';
import '../../features/cache/cache_service.dart'; // 🌟 引入离线缓存服务
import '../spot/spot_model.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const LatLng _swuCenter = LatLng(29.819000, 106.422000);

  AMapController? _mapController;
  final Map<String, Marker> _markers = {};

  CameraPosition _currentCameraPosition = const CameraPosition(
    target: _swuCenter,
    zoom: 15.0,
    tilt: 0.0,
    bearing: 0.0,
  );

  @override
  void initState() {
    super.initState();
    _initMapData(); // 🌟 触发本地优先的数据加载策略
  }

  // 🌟 核心落地逻辑：离线缓存优先 + 弱网静默更新
  Future<void> _initMapData() async {
    // 1. 【极速呈现】优先从 SQLite 离线数据库读取数据
    final cachedRecords = await CacheService.getCachedSpots();
    if (cachedRecords.isNotEmpty) {
      List<SpotModel> spots = cachedRecords.map((e) => SpotModel.fromJson(e)).toList();
      _generateMarkers(spots);
      debugPrint('已从 SQLite 本地加载 ${spots.length} 个离线景点数据');
    }

    // 2. 【静默更新】后台悄悄发请求拉取最新数据（即使用户断网，此步骤报错也不会影响第1步呈现的地图）
    bool isNetworkSuccess = await CacheService.preloadSpots();

    // 3. 【无缝热刷】如果网络请求成功且把新数据写进了 SQLite，重新读取本地并刷新页面
    if (isNetworkSuccess) {
      final latestRecords = await CacheService.getCachedSpots();
      List<SpotModel> latestSpots = latestRecords.map((e) => SpotModel.fromJson(e)).toList();
      _generateMarkers(latestSpots);
      debugPrint('已通过网络更新并缓存最新的景点数据');
    }
  }

  // 批量生成高德地图 Marker 并刷新界面
  void _generateMarkers(List<SpotModel> spots) {
    final Map<String, Marker> newMarkers = {};

    for (var spot in spots) {
      double markerHue;

      // 严格匹配数据库中的分类名称
      switch (spot.category.trim()) {
        case '自然景观':
          markerHue = BitmapDescriptor.hueGreen;
          break;
        case '教学设施':
          markerHue = BitmapDescriptor.hueAzure;
          break;
        case '历史建筑':
          markerHue = BitmapDescriptor.hueOrange;
          break;
        case '校园文化':
          markerHue = BitmapDescriptor.hueViolet;
          break;
        case '生活服务':
          markerHue = BitmapDescriptor.hueCyan;
          break;
        default:
          markerHue = BitmapDescriptor.hueRed; // 兜底颜色
      }

      final marker = Marker(
        position: LatLng(spot.latitude, spot.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
        infoWindow: InfoWindow(
          title: spot.name,
          snippet: spot.description,
        ),
      );

      newMarkers[spot.id.toString()] = marker;
    }

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
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

  void _resetPosition() {
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _swuCenter, zoom: 15.0, tilt: 0.0, bearing: 0.0),
      ),
      animated: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌏 地图主体
          AMapWidget(
            mapType: MapType.normal,
            privacyStatement: const AMapPrivacyStatement(hasContains: true, hasShow: true, hasAgree: true),
            initialCameraPosition: _currentCameraPosition,
            markers: Set<Marker>.of(_markers.values),
            myLocationStyleOptions: MyLocationStyleOptions(true),
            compassEnabled: false,
            limitBounds: LatLngBounds(
              southwest: const LatLng(29.80649, 106.402434),
              northeast: const LatLng(29.835163, 106.436554),
            ),
            minMaxZoomPreference: const MinMaxZoomPreference(14.0, 20.0),
            buildingsEnabled: false,
            labelsEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (CameraPosition position) {
              _currentCameraPosition = position;
            },
          ),

          // 🛠️ 蓝色透明毛玻璃图例面板 (左上角)
          Positioned(
            top: 50,
            left: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.map_outlined, size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 6),
                          Text(
                            '西大纯净版导览图',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Colors.blue.shade900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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

          // 🛠️ 放大缩小/复位控件
          Positioned(
            right: 16,
            bottom: 120,
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
        ],
      ),
    );
  }

  // 动态颜色图例行组件
  Widget _buildLegendRow(double hue, String label) {
    Color displayColor;
    if (hue == BitmapDescriptor.hueGreen) {
      displayColor = Colors.green;
    } else if (hue == BitmapDescriptor.hueAzure) {
      displayColor = Colors.blue;
    } else if (hue == BitmapDescriptor.hueOrange) {
      displayColor = Colors.orange;
    } else if (hue == BitmapDescriptor.hueViolet) {
      displayColor = Colors.purple;
    } else if (hue == BitmapDescriptor.hueCyan) {
      displayColor = Colors.cyan;
    } else {
      displayColor = Colors.red;
    }

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
                BoxShadow(
                  color: displayColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                )
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade900.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBtn(IconData icon, VoidCallback onTap, {Color color = Colors.black87}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}