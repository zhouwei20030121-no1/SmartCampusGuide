import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  // 西南大学中心坐标（北碚校区）
  static const _swuCenter = LatLng(29.824, 106.608);

  static const _pois = [
    _CampusPoi('含弘门（1号门）', '西南大学主校门，常用入校点', Icons.flag, LatLng(29.8201, 106.6105)),
    _CampusPoi('学行门（2号门）', '天生路主入口', Icons.flag_outlined, LatLng(29.8268, 106.6005)),
    _CampusPoi('中心图书馆', '北区核心学习空间', Icons.local_library, LatLng(29.8260, 106.6075)),
    _CampusPoi('南区图书馆', '南区学习服务点', Icons.menu_book, LatLng(29.8185, 106.6120)),
    _CampusPoi('计算机与信息科学学院', '计科院 / 软件学院', Icons.computer, LatLng(29.8235, 106.6140)),
    _CampusPoi('中心体育馆', '校内体育场馆', Icons.sports_basketball, LatLng(29.8215, 106.6060)),
  ];

  _CampusPoi? _selectedPoi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF7FF),
      appBar: AppBar(
        title: const Text('校园地图'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textMain,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 高德瓦片地图
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _swuCenter,
              initialZoom: 16.0,
              minZoom: 12.0,
              maxZoom: 18.0,
              onTap: (_, __) => setState(() => _selectedPoi = null),
            ),
            children: [
              // 高德瓦片图层
              TileLayer(
                urlTemplate:
                    'https://wprd0{s}.is.autonavi.com/appmaptile?x={x}&y={y}&z={z}&lang=zh_cn&size=1&scl=1&style=7',
                subdomains: const ['1', '2', '3', '4'],
                userAgentPackageName: 'com.swu.smartCampusGuide',
                maxZoom: 18,
              ),
              // POI 标记
              MarkerLayer(
                markers: _pois.map((poi) {
                  final isSelected = _selectedPoi == poi;
                  return Marker(
                    point: poi.position,
                    width: isSelected ? 160 : 44,
                    height: isSelected ? 72 : 44,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPoi = poi),
                      child: isSelected
                          ? _buildSelectedMarker(poi)
                          : _buildMarker(poi),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // 底部 POI 列表（可滑出）
          DraggableScrollableSheet(
            initialChildSize: 0.15,
            minChildSize: 0.08,
            maxChildSize: 0.55,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x20000000),
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                  children: [
                    // 拖拽指示条
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 14),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      '校园地点',
                      style: TextStyle(
                        color: AppTheme.textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final poi in _pois) ...[
                      _PoiTile(
                        poi: poi,
                        onTap: () {
                          _mapController.move(poi.position, 17.0);
                          setState(() => _selectedPoi = poi);
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(_CampusPoi poi) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0x30000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(poi.icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildSelectedMarker(_CampusPoi poi) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x30000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            poi.name,
            style: const TextStyle(
              color: AppTheme.textMain,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Color(0x30000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Icon(poi.icon, color: Colors.white, size: 16),
        ),
      ],
    );
  }
}

class _PoiTile extends StatelessWidget {
  const _PoiTile({required this.poi, required this.onTap});

  final _CampusPoi poi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(poi.icon, color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poi.name,
                    style: const TextStyle(
                      color: AppTheme.textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    poi.description,
                    style: const TextStyle(
                      color: AppTheme.textSub,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSub, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CampusPoi {
  const _CampusPoi(this.name, this.description, this.icon, this.position);

  final String name;
  final String description;
  final IconData icon;
  final LatLng position;
}
