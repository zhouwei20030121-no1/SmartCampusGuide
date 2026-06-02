import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/network/network_client.dart';
import '../../core/theme/app_theme.dart';
import '../cache/cache_service.dart';
import '../spot/spot_model.dart';

class RoutePage extends StatefulWidget {
  const RoutePage({super.key});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  List<SpotModel> _allSpots = [];
  List<SpotModel> _routeSpots = [];
  SpotModel? _startSpot;
  SpotModel? _endSpot;
  bool _isLoadingRoute = false;
  String _distanceText = '';
  String _timeText = '';

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
    await CacheService.preloadSpots();
    final cachedRecords = await CacheService.getCachedSpots();
    if (!mounted) return;
    setState(() {
      _allSpots = cachedRecords.map((e) => SpotModel.fromJson(e)).toList();
    });
  }

  void _checkAndTriggerRoute() {
    if (_startSpot != null && _endSpot != null && _startSpot!.id != _endSpot!.id) {
      _fetchRoute();
    }
  }

  Future<void> _fetchRoute() async {
    setState(() {
      _isLoadingRoute = true;
      _routeSpots = [];
      _distanceText = '';
      _timeText = '';
    });

    List<SpotModel> route = [];
    try {
      final response = await NetworkClient.get(
        '/route/plan/optimal',
        queryParameters: {
          'startId': _startSpot!.id,
          'endId': _endSpot!.id,
          'isPopularityFirst': false,
        },
      );

      if (response.data['code'] == 200 && response.data['data'] is List) {
        route = (response.data['data'] as List)
            .map((item) => SpotModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      route = [];
    }

    if (route.length < 2) {
      route = [_startSpot!, _endSpot!];
    }

    final distance = _calculateTotalDistance(route);
    final minutes = math.max(1, (distance / 80).ceil());

    if (!mounted) return;
    setState(() {
      _routeSpots = route;
      _distanceText = distance < 1000
          ? '${distance.toInt()} 米'
          : '${(distance / 1000).toStringAsFixed(1)} 公里';
      _timeText = '约 $minutes 分钟';
      _isLoadingRoute = false;
    });
  }

  double _calculateTotalDistance(List<SpotModel> spots) {
    double total = 0;
    for (int i = 0; i < spots.length - 1; i++) {
      final a = spots[i];
      final b = spots[i + 1];
      final lat1 = a.latitude * math.pi / 180;
      final lat2 = b.latitude * math.pi / 180;
      final deltaLat = (b.latitude - a.latitude) * math.pi / 180;
      final deltaLon = (b.longitude - a.longitude) * math.pi / 180;
      final h = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
          math.cos(lat1) * math.cos(lat2) *
              math.sin(deltaLon / 2) * math.sin(deltaLon / 2);
      total += 6371000 * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    }
    return total;
  }

  void _resetRoute() {
    setState(() {
      _startSpot = null;
      _endSpot = null;
      _routeSpots = [];
      _distanceText = '';
      _timeText = '';
      _startController.clear();
      _endController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('校园路线规划', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      backgroundColor: const Color(0xFFEFF7FF),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildMapPlaceholder(),
          const SizedBox(height: 16),
          _buildPlannerCard(),
          if (_routeSpots.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildRouteResult(),
          ],
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      height: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8F5)),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.map, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('地图暂用兼容模式', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textMain)),
                    SizedBox(height: 4),
                    Text('为保障 iOS 与外网演示稳定，已移除原生地图依赖。', style: TextStyle(fontSize: 12, color: AppTheme.textSub)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _buildMiniStat(Icons.place, '景点数据', '${_allSpots.length} 个'),
              const SizedBox(width: 10),
              _buildMiniStat(Icons.route, '路径服务', '后端计算'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5FAFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSub)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textMain)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlannerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.directions, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('路线规划', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: _resetRoute,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.redAccent),
                label: const Text('重置', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              const Icon(Icons.location_on, size: 16, color: Colors.red),
              const SizedBox(width: 6),
              _buildSpotDropdown(isStart: false),
            ],
          ),
          if (_isLoadingRoute) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
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
            hintText: isStart ? '选择起点' : '选择终点',
            menuHeight: 260,
            dropdownMenuEntries: _allSpots.map((spot) {
              return DropdownMenuEntry<SpotModel>(
                value: spot,
                label: spot.name,
              );
            }).toList(),
            onSelected: (spot) {
              if (spot == null) return;
              setState(() {
                if (isStart) {
                  _startSpot = spot;
                } else {
                  _endSpot = spot;
                }
              });
              _checkAndTriggerRoute();
            },
          );
        },
      ),
    );
  }

  Widget _buildRouteResult() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_timeText · $_distanceText',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < _routeSpots.length; i++) _buildRouteStep(i, _routeSpots[i]),
        ],
      ),
    );
  }

  Widget _buildRouteStep(int index, SpotModel spot) {
    final isLast = index == _routeSpots.length - 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isLast ? Colors.redAccent : AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            if (!isLast)
              Container(width: 2, height: 34, color: AppTheme.primary.withValues(alpha: 0.22)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spot.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textMain)),
                if (spot.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(spot.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
