import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/network/network_client.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../cache/cache_service.dart';
import '../location/location_service.dart';
import '../spot/spot_model.dart';
import 'campus_vector_map_layer.dart';
import 'user_location_marker.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _swuCenter = LatLng(29.8218, 106.4256);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _activeCategories = {};
  List<SpotModel> _allSpots = [];
  SpotModel? _selectedSpot;
  bool _loading = false;
  bool _showLabels = true;
  double _zoom = 16.0;

  @override
  void initState() {
    super.initState();
    _loadSpots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSpots() async {
    setState(() => _loading = true);
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
        final res = await NetworkClient.dio.get(
          '/spot/list',
          queryParameters: {'page': 1, 'size': 200},
        );
        final records = (res.data['data']?['records'] as List<dynamic>? ?? []);
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

    if (!mounted) return;
    setState(() {
      _allSpots = validSpots.isEmpty ? _fallbackSpots : validSpots;
      _activeCategories
        ..clear()
        ..addAll(_allSpots.map((spot) => _categoryOf(spot)));
      _loading = false;
    });
  }

  bool _isValidCampusCoordinate(double latitude, double longitude) {
    return latitude >= 29.75 &&
        latitude <= 29.90 &&
        longitude >= 106.35 &&
        longitude <= 106.50;
  }

  List<SpotModel> get _visibleSpots {
    final keyword = _searchController.text.trim();
    return _allSpots.where((spot) {
      final category = _categoryOf(spot);
      final categoryVisible =
          _activeCategories.isEmpty || _activeCategories.contains(category);
      final keywordVisible =
          keyword.isEmpty ||
          spot.name.contains(keyword) ||
          spot.description.contains(keyword) ||
          spot.category.contains(keyword);
      return categoryVisible && keywordVisible;
    }).toList();
  }

  List<String> get _categories {
    final categories = _allSpots.map(_categoryOf).toSet().toList()..sort();
    return categories;
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
        return Colors.lightBlue.shade400;
      case '生活服务':
        return Colors.cyan.shade400;
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

  void _moveToSpot(SpotModel spot, {double zoom = 17.2}) {
    final point = LatLng(spot.latitude, spot.longitude);
    _mapController.move(point, zoom);
    setState(() {
      _selectedSpot = spot;
      _zoom = zoom;
    });
  }

  void _zoomBy(double delta) {
    final nextZoom = (_zoom + delta).clamp(12.0, 19.0);
    _mapController.move(_mapController.camera.center, nextZoom);
    setState(() => _zoom = nextZoom);
  }

  void _resetPosition() {
    final location = LocationService();
    if (location.latitude != 0.0 && location.longitude != 0.0) {
      _mapController.move(LatLng(location.latitude, location.longitude), 17.0);
      setState(() {
        _selectedSpot = null;
        _zoom = 17.0;
      });
      return;
    }
    _mapController.move(_swuCenter, 16.0);
    setState(() {
      _selectedSpot = null;
      _zoom = 16.0;
    });
  }

  void _showSpotDialog(SpotModel spot) {
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
                constraints: const BoxConstraints(maxHeight: 520),
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
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _colorForCategory(
                              _categoryOf(spot),
                            ).withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _iconForSpot(spot),
                            color: _colorForCategory(_categoryOf(spot)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            spot.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textMain,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          icon: Icons.category,
                          label: _categoryOf(spot),
                          color: _colorForCategory(_categoryOf(spot)),
                        ),
                        _InfoPill(
                          icon: Icons.pin_drop,
                          label:
                              '${spot.latitude.toStringAsFixed(5)}, ${spot.longitude.toStringAsFixed(5)}',
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          spot.description.isNotEmpty
                              ? spot.description
                              : '暂无详细介绍',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMain,
                            height: 1.65,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pushNamed(
                                context,
                                AppRouter.routePlan,
                                arguments: {'startId': spot.id},
                              );
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
                              Navigator.pushNamed(
                                context,
                                AppRouter.routePlan,
                                arguments: {'endId': spot.id},
                              );
                            },
                            icon: const Icon(Icons.directions, size: 18),
                            label: const Text('去这里'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(
                            context,
                            AppRouter.spotDetail,
                            arguments: {'spotId': spot.id},
                          );
                        },
                        icon: const Icon(Icons.article_outlined),
                        label: const Text('查看景点详情'),
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

  @override
  Widget build(BuildContext context) {
    final visibleSpots = _visibleSpots;
    return Scaffold(
      backgroundColor: const Color(0xFFEFF7FF),
      appBar: AppBar(
        title: const Text('校园地图'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textMain,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '刷新景点',
            onPressed: _loading ? null : _loadSpots,
            icon: const Icon(Icons.refresh),
          ),
        ],
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
              onTap: (tapPosition, point) =>
                  setState(() => _selectedSpot = null),
              onPositionChanged: (position, hasGesture) {
                _zoom = position.zoom;
              },
            ),
            children: [
              const CampusVectorMapLayer(),
              MarkerLayer(
                markers: visibleSpots.map((spot) {
                  final selected = _selectedSpot?.id == spot.id;
                  return Marker(
                    point: LatLng(spot.latitude, spot.longitude),
                    width: selected ? 170 : (_showLabels ? 96 : 44),
                    height: selected ? 76 : (_showLabels ? 64 : 44),
                    // 图标紧贴坐标点，名字在图标下方（marker 整体位于坐标点下方）
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedSpot = spot);
                        _showSpotDialog(spot);
                      },
                      child: selected
                          ? _SelectedMapMarker(
                              spot: spot,
                              color: _colorForCategory(_categoryOf(spot)),
                              icon: _iconForSpot(spot),
                            )
                          : _MapMarker(
                              label: _showLabels ? spot.name : null,
                              color: _colorForCategory(_categoryOf(spot)),
                              icon: _iconForSpot(spot),
                            ),
                    ),
                  );
                }).toList(),
              ),
              ListenableBuilder(
                listenable: LocationService(),
                builder: (context, _) {
                  final loc = LocationService();
                  if (loc.latitude == 0.0 || loc.longitude == 0.0) {
                    return const SizedBox.shrink();
                  }
                  return MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(loc.latitude, loc.longitude),
                        width: 46,
                        height: 46,
                        child: UserLocationMarker(
                          headingDegrees: loc.headingDegrees,
                          showHeading: loc.headingAvailable,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          Positioned(top: 14, left: 14, right: 14, child: _buildSearchPanel()),
          Positioned(top: 92, left: 14, right: 14, child: _buildCategoryBar()),
          Positioned(top: 154, right: 14, child: _buildLabelToggle()),
          Positioned(
            right: 14,
            bottom: 122,
            child: Column(
              children: [
                _MapActionButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                const SizedBox(height: 8),
                _MapActionButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                const SizedBox(height: 12),
                _MapActionButton(
                  icon: Icons.my_location,
                  onTap: _resetPosition,
                  color: AppTheme.primary,
                ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.18,
            minChildSize: 0.09,
            maxChildSize: 0.58,
            builder: (context, scrollController) {
              return _buildSpotSheet(scrollController, visibleSpots);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return _GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: '搜索景点、学院、校门...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
          isDense: true,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final allSelected = _activeCategories.length == _categories.length;
            return _CategoryChip(
              label: '全部',
              selected: allSelected,
              color: AppTheme.primary,
              onTap: () {
                setState(() {
                  if (allSelected) {
                    _activeCategories.clear();
                  } else {
                    _activeCategories
                      ..clear()
                      ..addAll(_categories);
                  }
                });
              },
            );
          }
          final category = _categories[index - 1];
          return _CategoryChip(
            label: category,
            selected: _activeCategories.contains(category),
            color: _colorForCategory(category),
            onTap: () {
              setState(() {
                if (_activeCategories.contains(category)) {
                  _activeCategories.remove(category);
                } else {
                  _activeCategories.add(category);
                }
              });
            },
          );
        },
      ),
    );
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

  Widget _buildSpotSheet(
    ScrollController scrollController,
    List<SpotModel> visibleSpots,
  ) {
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  '校园地点',
                  style: TextStyle(
                    color: AppTheme.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '${visibleSpots.length} 个',
                  style: const TextStyle(color: AppTheme.textSub, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (visibleSpots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  '暂无匹配地点',
                  style: TextStyle(color: AppTheme.textSub),
                ),
              ),
            ),
          for (final spot in visibleSpots) ...[
            _SpotTile(
              spot: spot,
              color: _colorForCategory(_categoryOf(spot)),
              icon: _iconForSpot(spot),
              onTap: () => _moveToSpot(spot),
              onDetail: () => Navigator.pushNamed(
                context,
                AppRouter.spotDetail,
                arguments: {'spotId': spot.id},
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.color, required this.icon, this.label});

  final Color color;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
        ),
        if (label != null) ...[
          const SizedBox(height: 3),
          Container(
            constraints: const BoxConstraints(maxWidth: 92),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
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
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectedMapMarker extends StatelessWidget {
  const _SelectedMapMarker({
    required this.spot,
    required this.color,
    required this.icon,
  });

  final SpotModel spot;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapMarker(color: color, icon: icon),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x30000000), blurRadius: 8),
            ],
          ),
          child: Text(
            spot.name,
            style: const TextStyle(
              color: AppTheme.textMain,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.88) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.38)),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8)],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
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
            color: Colors.white.withValues(alpha: 0.72),
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

class _SpotTile extends StatelessWidget {
  const _SpotTile({
    required this.spot,
    required this.color,
    required this.icon,
    required this.onTap,
    required this.onDetail,
  });

  final SpotModel spot;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spot.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSub,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '详情',
              onPressed: onDetail,
              icon: const Icon(Icons.article_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

List<SpotModel> get _fallbackSpots {
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
      id: 39,
      name: '中心体育馆',
      description: '校内体育场馆。',
      latitude: 29.818364,
      longitude: 106.424483,
      category: '生活服务',
    ),
  ];
}
