import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import '../../core/theme/app_theme.dart';
import '../../features/cache/cache_service.dart';
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

  // 控制高德底图自带文字显示的开关
  bool _showLabels = true;

  CameraPosition _currentCameraPosition = const CameraPosition(
    target: _swuCenter,
    zoom: 15.0,
    tilt: 0.0,
    bearing: 0.0,
  );

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  Future<void> _initMapData() async {
    final cachedRecords = await CacheService.getCachedSpots();
    if (cachedRecords.isNotEmpty) {
      List<SpotModel> spots = cachedRecords.map((e) => SpotModel.fromJson(e)).toList();
      _generateMarkers(spots);
    }

    bool isNetworkSuccess = await CacheService.preloadSpots();

    if (isNetworkSuccess) {
      final latestRecords = await CacheService.getCachedSpots();
      List<SpotModel> latestSpots = latestRecords.map((e) => SpotModel.fromJson(e)).toList();
      _generateMarkers(latestSpots);
    }
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
        // 点击大头针触发详情弹窗
        onTap: (_) => _showSpotGlassDialog(spot),
      );

      newMarkers[spot.id.toString()] = marker;
    }

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
  }

  // 弹窗保持较低透明度 (alpha: 0.88)，确保文字清晰
  void _showSpotGlassDialog(SpotModel spot) {
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
                  border: Border.all(color: Colors.blue.shade300.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: Colors.blue.shade700, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            spot.name,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        spot.category,
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          spot.description.isNotEmpty ? spot.description : '暂无详细介绍',
                          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('我知道了', style: TextStyle(fontWeight: FontWeight.bold)),
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
            labelsEnabled: _showLabels,
            onMapCreated: (controller) => _mapController = controller,
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
                    color: Colors.blue.shade900.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.shade200.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.blue.shade900.withValues(alpha: 0.1), blurRadius: 20)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.map_outlined, size: 18, color: Colors.blue.shade800),
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
                    color: Colors.blue.shade900.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.blue.shade900.withValues(alpha: 0.1), blurRadius: 20)],
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

          // 缩放控件
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                _buildMapBtn(Icons.add, () => _zoom(true)),
                const SizedBox(height: 8),
                _buildMapBtn(Icons.remove, () => _zoom(false)),
                const SizedBox(height: 16),
                _buildMapBtn(Icons.my_location, _resetPosition, color: Colors.blue.shade800),
              ],
            ),
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900.withValues(alpha: 0.85)),
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
              color: Colors.blue.shade50.withValues(alpha: 0.6), // 恢复最初的 alpha: 0.6
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.shade200.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}