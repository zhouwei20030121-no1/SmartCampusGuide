// lib/features/home/home_page.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../user/profile_page.dart';
import '../map/map_page.dart';
import '../location/location_service.dart';
import '../../core/network/network_client.dart';
import '../spot/spot_model.dart'; // 引入数据模型

const Color _schoolBlue = Color(0xFF023D83);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _xiaoDaoFabSize = 58;
  static const double _xiaoDaoBottomReserve = 0;

  int _currentIndex = 0;
  Offset? _xiaoDaoFabOffset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // 1. 背景图
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: AppTheme.pageBg),
            ),
          ),
          // 2. 毛玻璃蒙版（地图/讲解页降低模糊，方便看地图）
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: (_currentIndex == 1 || _currentIndex == 2) ? 4.0 : 12.0,
                sigmaY: (_currentIndex == 1 || _currentIndex == 2) ? 4.0 : 12.0,
              ),
              child: Container(
                color: const Color(0xFFE0F2FE).withValues(
                  alpha: (_currentIndex == 1 || _currentIndex == 2)
                      ? 0.25
                      : 0.45,
                ),
              ),
            ),
          ),
          // 3. 主体内容（IndexedStack 保持各Tab状态）
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _TabHome(
                  onTabSelected: (index) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    setState(() => _currentIndex = index);
                  },
                ),
                const MapPage(),
                const _TabSmartAudio(),
                const ProfilePage(),
              ],
            ),
          ),
          // 4. 西小导悬浮球，可拖拽避免遮挡页面内容
          _buildDraggableXiXiaoDaoFab(context),
        ],
      ),
      // 5. 底部导航
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ═══════════════════════════════════════════
  //  西小导 AI 悬浮球
  // ═══════════════════════════════════════════
  Widget _buildDraggableXiXiaoDaoFab(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final safePadding = MediaQuery.of(context).padding;
          final defaultOffset = Offset(
            constraints.maxWidth - _xiaoDaoFabSize - 16,
            constraints.maxHeight -
                _xiaoDaoFabSize -
                safePadding.bottom -
                _xiaoDaoBottomReserve,
          );
          final currentOffset = _clampXiaoDaoOffset(
            _xiaoDaoFabOffset ?? defaultOffset,
            constraints,
            safePadding,
          );

          return Stack(
            children: [
              Positioned(
                left: currentOffset.dx,
                top: currentOffset.dy,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {
                    _xiaoDaoFabOffset = currentOffset;
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      final latestOffset = _xiaoDaoFabOffset ?? currentOffset;
                      _xiaoDaoFabOffset = _clampXiaoDaoOffset(
                        latestOffset + details.delta,
                        constraints,
                        safePadding,
                      );
                    });
                  },
                  onTap: () => _showChatSheet(context),
                  child: _buildXiXiaoDaoFab(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Offset _clampXiaoDaoOffset(
    Offset offset,
    BoxConstraints constraints,
    EdgeInsets safePadding,
  ) {
    const edgePadding = 12.0;
    final minX = edgePadding;
    final maxX = math.max(
      minX,
      constraints.maxWidth - _xiaoDaoFabSize - edgePadding,
    );
    final minY = safePadding.top + edgePadding;
    final maxY = math.max(
      minY,
      constraints.maxHeight -
          _xiaoDaoFabSize -
          safePadding.bottom -
          _xiaoDaoBottomReserve,
    );

    return Offset(offset.dx.clamp(minX, maxX), offset.dy.clamp(minY, maxY));
  }

  Widget _buildXiXiaoDaoFab() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: _xiaoDaoFabSize,
          height: _xiaoDaoFabSize,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _schoolBlue.withValues(alpha: 0.25),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            color: _schoolBlue,
            size: 30,
          ),
        ),
      ),
    );
  }

  void _showChatSheet(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.pushNamed(context, '/chat');
  }

  // ═══════════════════════════════════════════
  //  底部导航栏
  // ═══════════════════════════════════════════
  Widget _buildBottomNav() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: Colors.white.withValues(alpha: 0.92),
          child: SafeArea(
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) {
                ScaffoldMessenger.of(context).clearSnackBars();
                setState(() => _currentIndex = i);
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: const Color(0xFF64748B),
              selectedFontSize: 11,
              unselectedFontSize: 11,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_filled),
                  label: '首页',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore_outlined),
                  label: '地图导览',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.headphones_rounded),
                  label: '智能讲解',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  label: '我的',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  TAB 0：首页 — 动态拉取数据库 + 实时定位最近 3 个
// ═══════════════════════════════════════════════════
class _TabHome extends StatefulWidget {
  final ValueChanged<int> onTabSelected;

  const _TabHome({required this.onTabSelected});

  @override
  State<_TabHome> createState() => _TabHomeState();
}

class _TabHomeState extends State<_TabHome> {
  final LocationService _loc = LocationService();

  List<SpotModel> _allSpots = [];
  List<Map<String, dynamic>> _closestSpots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loc.addListener(_updateClosestSpots);
    _loc.startTracking(); // 启动队友写的心跳和位置模拟
    _fetchAllSpotsFromDB();
  }

  @override
  void dispose() {
    _loc.removeListener(_updateClosestSpots);
    super.dispose();
  }

  // 从后端获取所有景点的真实数据，确保 ID 绝对正确
  Future<void> _fetchAllSpotsFromDB() async {
    try {
      final res = await NetworkClient.dio.get(
        '/spot/list',
        queryParameters: {'page': 1, 'size': 100},
      );
      if (res.data['code'] == 200) {
        final records = res.data['data']['records'] as List;
        _allSpots = records.map((e) => SpotModel.fromJson(e)).toList();
        _updateClosestSpots(); // 数据拉取成功后，立刻计算一次距离
      }
    } catch (e) {
      debugPrint('首页获取景点失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 核心：实时距离计算与排序算法
  void _updateClosestSpots() {
    if (_allSpots.isEmpty) return;

    double currentLat = _loc.latitude != 0.0 ? _loc.latitude : 29.820;
    double currentLng = _loc.longitude != 0.0 ? _loc.longitude : 106.425;

    // 遍历数据库真实数据，利用经纬度估算距离
    List<Map<String, dynamic>> spotsWithDistance = _allSpots.map((spot) {
      double dx = (currentLng - spot.longitude) * 111320 * 0.866;
      double dy = (currentLat - spot.latitude) * 111320;
      double distance = math.sqrt(dx * dx + dy * dy);
      return {
        'spot': spot, // 存放真实的 SpotModel 对象
        'distance': distance,
      };
    }).toList();

    // 升序排序
    spotsWithDistance.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
    );

    // 截取距离最近的 3 个
    if (mounted) {
      setState(() {
        _closestSpots = spotsWithDistance.take(3).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopSearchBar(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: 120,
            ),
            children: [
              // Banner
              _buildBanner(),
              const SizedBox(height: 20),
              // 金刚区 8宫格
              _buildGridNav(context),
              const SizedBox(height: 20),
              // 动态精选推荐卡片
              _buildDynamicRecommendCard(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/校徽.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Text(
                    '西大',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).clearSnackBars();
                Navigator.pushNamed(context, '/search');
              },
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Colors.black45.withValues(alpha: 0.6),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '搜索校园景点、服务设施...',
                      style: TextStyle(
                        color: Colors.black38.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/shouye.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, _, _) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF73B4E9), Color(0xFF3A86C5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 20,
        alignment: WrapAlignment.spaceAround,
        children: [
          _GridButton(
            icon: Icons.map_outlined,
            label: '校园地图',
            onTap: () => widget.onTabSelected(1),
          ),
          _GridButton(
            icon: Icons.route_outlined,
            label: '路线规划',
            onTap: () => Navigator.pushNamed(context, '/route'),
          ),
          _GridButton(
            icon: Icons.document_scanner_outlined,
            label: 'AI 探校',
            onTap: () => Navigator.pushNamed(context, '/ai_vision'),
          ),
          _GridButton(
            icon: Icons.workspace_premium_outlined,
            label: '景点打卡',
            onTap: () => widget.onTabSelected(3),
          ),
          _GridButton(
            icon: Icons.auto_stories_outlined,
            label: '校园故事',
            onTap: () => Navigator.pushNamed(context, '/checkin'),
          ),
          _GridButton(
            icon: Icons.directions_bus_filled_outlined,
            label: '校车时刻',
            onTap: () => Navigator.pushNamed(context, '/bus'),
          ),
          _GridButton(
            icon: Icons.cloud_download_outlined,
            label: '离线下载',
            onTap: () {},
          ),
          _GridButton(
            icon: Icons.campaign_outlined,
            label: '校园公告',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // 动态渲染推荐卡片 + “全部景点”选项
  Widget _buildDynamicRecommendCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📍 附近景点推荐',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '基于当前实时定位',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSub),
                  ),
                ],
              ),
              // 全部景点跳转按钮
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/spot/list'),
                child: const Text(
                  '全部景点 >',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

          if (!_isLoading && _closestSpots.isEmpty)
            const Center(
              child: Text('暂无附近景点', style: TextStyle(color: AppTheme.textSub)),
            ),

          // 动态渲染 3 个真实景点
          ..._closestSpots.map((item) {
            final SpotModel spot = item['spot'];
            String distStr = (item['distance'] as double).toStringAsFixed(0);
            return _spotTile(
              '${spot.name} (距您约${distStr}米)',
              spot.description.isNotEmpty ? spot.description : '暂无简介',
              () {
                // 此时传入的绝对是后端的真实 ID
                Navigator.pushNamed(
                  context,
                  '/spot/detail',
                  arguments: {'spotId': spot.id},
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _spotTile(String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xCCFAFADB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white),
              ),
              child: const Icon(
                Icons.pin_drop_rounded,
                color: AppTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSub,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  TAB 2：智能讲解 — LBS地理围栏 + 音频 (3.1.3+3.1.4+3.1.5)
// ═══════════════════════════════════════════════════
// ─── 地理围栏智能讲解（保留图钉拖拽方便模拟器测试）───
class _TabSmartAudio extends StatefulWidget {
  const _TabSmartAudio();

  @override
  State<_TabSmartAudio> createState() => _TabSmartAudioState();
}

class _TabSmartAudioState extends State<_TabSmartAudio> {
  static const MethodChannel _ttsChannel = MethodChannel(
    'smart_campus_guide/tts',
  );

  static const _swuCenter = LatLng(29.8218, 106.4256);
  static const _tileUrlClean =
      'https://wprd0{s}.is.autonavi.com/appmaptile?x={x}&y={y}&z={z}&lang=zh_cn&size=1&scl=1&style=7&ltype=3';
  static const _guideTriggerRadiusMeters = 80.0;

  final MapController _mapController = MapController();
  final LocationService _loc = LocationService();
  bool _playing = false;
  String _guideText = '';
  bool _loadingGuide = false;
  final String _language = 'zh';
  final String _voice = 'gentle_guide';
  double _zoom = 16.6;

  String? _triggeredSpot;

  // 智能讲解地图标点的后端景点（/spot/list 全量，含准确坐标与讲解词）
  List<SpotModel> _backendSpots = [];

  // 后端景点为空时的兜底点位（手工硬编码，仅离线/加载失败时使用）
  static const _fallbackGuideSpots = [
    _GuideSpot('中心图书馆', LatLng(29.8240, 106.4310), Icons.local_library),
    _GuideSpot('第八教学楼', LatLng(29.8190, 106.4236), Icons.school),
    _GuideSpot('行署楼', LatLng(29.8197, 106.4244), Icons.account_balance),
    _GuideSpot('田家炳教育书院', LatLng(29.8185, 106.4260), Icons.school_outlined),
    _GuideSpot('共青团花园', LatLng(29.8210, 106.4270), Icons.park),
    _GuideSpot('校史馆', LatLng(29.8208, 106.4249), Icons.museum),
    _GuideSpot('樟树林', LatLng(29.8220, 106.4280), Icons.forest),
    _GuideSpot('楠园(第四运动场)', LatLng(29.8172, 106.4216), Icons.sports_soccer),
    _GuideSpot('竹园', LatLng(29.8232, 106.4218), Icons.yard),
    _GuideSpot('中心体育馆', LatLng(29.8164, 106.4267), Icons.sports_basketball),
    _GuideSpot('药学院', LatLng(29.8252, 106.4288), Icons.science),
    _GuideSpot('音乐学院', LatLng(29.8195, 106.4293), Icons.music_note),
  ];

  // 智能讲解的地图标点：优先用后端 /spot/list 全量景点（准确坐标 + 讲解词），
  // 后端为空时回退到兜底点位。按 _allSpots 长度缓存，避免每帧重建 74 个对象。
  List<_GuideSpot>? _guideSpotsCache;
  int _guideSpotsCacheKey = -1;
  List<_GuideSpot> get _spots {
    if (_backendSpots.isEmpty) return _fallbackGuideSpots;
    if (_guideSpotsCache != null && _guideSpotsCacheKey == _backendSpots.length) {
      return _guideSpotsCache!;
    }
    final list = <_GuideSpot>[];
    for (final s in _backendSpots) {
      if (s.latitude < 29.75 ||
          s.latitude > 29.90 ||
          s.longitude < 106.35 ||
          s.longitude > 106.50) {
        continue; // 过滤无效/越界坐标
      }
      list.add(_GuideSpot(
        s.name,
        LatLng(s.latitude, s.longitude),
        _guideIconForCategory(s.category),
      ));
    }
    _guideSpotsCache = list.isEmpty ? _fallbackGuideSpots : list;
    _guideSpotsCacheKey = _backendSpots.length;
    return _guideSpotsCache!;
  }

  IconData _guideIconForCategory(String category) {
    switch (category) {
      case '教学设施':
        return Icons.school;
      case '校园文化':
        return Icons.museum;
      case '生活服务':
        return Icons.storefront;
      case '历史建筑':
        return Icons.account_balance;
      case '自然景观':
        return Icons.park;
      default:
        return Icons.location_on;
    }
  }

  @override
  void initState() {
    super.initState();
    _loc.addListener(_handleLocationChanged);
    _fetchGuideSpots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loc.startTracking();
    });
  }

  // 从后端 /spot/list 拉取全量景点作为智能讲解的地图标点（替代原 12 个硬编码点）
  Future<void> _fetchGuideSpots() async {
    try {
      final res = await NetworkClient.dio.get(
        '/spot/list',
        queryParameters: {'page': 1, 'size': 200},
      );
      if (res.data['code'] == 200) {
        final records = res.data['data']?['records'] as List? ?? [];
        final spots = records
            .map((e) => SpotModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _backendSpots = spots;
            _guideSpotsCache = null; // 失效缓存，让 getter 用新数据重建
            _guideSpotsCacheKey = -1;
          });
        }
      }
    } catch (e) {
      debugPrint('智能讲解加载景点失败: $e');
    }
  }

  void _handleLocationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stopGuideSpeech();
    _loc.removeListener(_handleLocationChanged);
    super.dispose();
  }

  void _triggerGuide(String spotName, {LatLng? position, double? distance}) {
    final shouldFetchGuide = spotName != _triggeredSpot;
    _stopGuideSpeech();
    if (position != null) {
      _moveUserTo(position, triggerNearest: false, clearGuide: false);
      _centerOn(position);
    }
    setState(() {
      _triggeredSpot = spotName;
      _playing = true;
    });
    if (shouldFetchGuide) {
      _fetchGuideContent(spotName);
    } else {
      _playGuide(spotName);
    }
  }

  void _moveUserTo(
    LatLng position, {
    bool triggerNearest = true,
    bool clearGuide = true,
  }) {
    _loc.latitude = position.latitude;
    _loc.longitude = position.longitude;
    _stopGuideSpeech();
    if (clearGuide) {
      setState(() {
        _playing = false;
        _guideText = '';
      });
    }
    if (triggerNearest) {
      _triggerNearestSpot(position);
    }
  }

  void _triggerNearestSpot(LatLng position) {
    final nearest = _nearestGuideSpot(position);
    if (nearest == null) return;
    final distance = _distanceInMeters(position, nearest.position);
    if (distance <= _guideTriggerRadiusMeters) {
      _triggerGuide(nearest.name, distance: distance);
      return;
    }
    setState(() {
      _triggeredSpot = null;
      _playing = false;
      _guideText = '';
    });
    _showTtsNotice('附近 ${distance.toStringAsFixed(0)} 米内没有可触发的讲解点');
  }

  _GuideSpot? _nearestGuideSpot(LatLng position) {
    _GuideSpot? nearest;
    var bestDistance = double.infinity;
    for (final spot in _spots) {
      final distance = _distanceInMeters(position, spot.position);
      if (distance < bestDistance) {
        nearest = spot;
        bestDistance = distance;
      }
    }
    return nearest;
  }

  double _distanceInMeters(LatLng a, LatLng b) {
    final dx = (a.longitude - b.longitude) * 111320 * 0.866;
    final dy = (a.latitude - b.latitude) * 111320;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _centerOn(LatLng position, {double zoom = 17.0}) {
    _mapController.move(position, zoom);
    setState(() => _zoom = zoom);
  }

  void _centerOnUser() {
    _centerOn(LatLng(_loc.latitude, _loc.longitude));
  }

  void _zoomBy(double delta) {
    final nextZoom = (_zoom + delta).clamp(12.0, 19.0);
    _mapController.move(_mapController.camera.center, nextZoom);
    setState(() => _zoom = nextZoom);
  }

  Future<void> _fetchGuideContent(String spot) async {
    setState(() {
      _loadingGuide = true;
      _guideText = '';
    });
    try {
      final res = await NetworkClient.dio.get(
        '/ai/guide/generate',
        queryParameters: {'spotName': spot, 'persona': '新生'},
      );
      if (res.data['code'] == 200) {
        setState(() => _guideText = res.data['data']['text'] ?? '');
      }
    } catch (_) {
      setState(() => _guideText = _getGuideText(spot));
    } finally {
      if (mounted) setState(() => _loadingGuide = false);
    }
    if (mounted && _triggeredSpot == spot && _playing) {
      _playGuide(spot);
    }
  }

  String _currentGuideText(String spot) {
    final generated = _guideText.trim();
    return generated.isNotEmpty ? generated : _getGuideText(spot);
  }

  Future<bool> _speakGuideText(String text) async {
    final content = text.trim();
    if (content.isEmpty) return false;
    try {
      final result = await _ttsChannel.invokeMapMethod<String, dynamic>(
        'speak',
        {'text': content, 'voice': _voice, 'language': _language},
      );
      if (result?['ok'] == true) return true;
      _showTtsNotice(result?['reason']?.toString() ?? 'TTS 播放失败');
    } on MissingPluginException {
      _showTtsNotice('TTS 通道未生效，请停止 App 后重新 Run');
    } catch (e) {
      _showTtsNotice('TTS 播放失败：$e');
      debugPrint('TTS 播放失败: $e');
    }
    return false;
  }

  Future<void> _stopGuideSpeech() async {
    try {
      await _ttsChannel.invokeMethod('stop');
    } catch (e) {
      debugPrint('TTS 停止失败: $e');
    }
  }

  Future<void> _playGuide(String spot) async {
    setState(() => _playing = true);
    final ok = await _speakGuideText(_currentGuideText(spot));
    if (!mounted || _triggeredSpot != spot) return;
    if (!ok) setState(() => _playing = false);
  }

  Future<void> _pauseGuide() async {
    await _stopGuideSpeech();
    if (mounted) setState(() => _playing = false);
  }

  void _showTtsNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _swuCenter,
            initialZoom: _zoom,
            minZoom: 12.0,
            maxZoom: 19.0,
            onTap: (_, point) => _moveUserTo(point),
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
              // 高 DPI 屏请求高清瓦片，避免地图模糊
              retinaMode: RetinaMode.isHighDensity(context),
            ),
            MarkerLayer(
              markers: [
                for (final spot in _spots)
                  Marker(
                    point: spot.position,
                    width: spot.name == _triggeredSpot ? 150 : 104,
                    height: spot.name == _triggeredSpot ? 76 : 62,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _triggerGuide(
                        spot.name,
                        position: spot.position,
                        distance: 0,
                      ),
                      child: _SmartGuideMarker(
                        spot: spot,
                        active: spot.name == _triggeredSpot,
                      ),
                    ),
                  ),
                Marker(
                  point: LatLng(_loc.latitude, _loc.longitude),
                  width: 34,
                  height: 34,
                  child: const _UserLocationDot(),
                ),
              ],
            ),
          ],
        ),
        Positioned(top: 16, left: 16, right: 72, child: _buildStatusBar()),
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              _mapButton(Icons.add, () => _zoomBy(1), tooltip: '放大'),
              const SizedBox(height: 8),
              _mapButton(Icons.remove, () => _zoomBy(-1), tooltip: '缩小'),
              const SizedBox(height: 8),
              _mapButton(Icons.my_location, _centerOnUser, tooltip: '居中当前位置'),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 108,
          child: _buildAudioPlayer(_triggeredSpot),
        ),
      ],
    );
  }

  Widget _mapButton(
    IconData icon,
    VoidCallback onTap, {
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _triggeredSpot != null
                      ? AppTheme.success
                      : AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _triggeredSpot != null
                      ? '正在讲解「$_triggeredSpot」'
                      : '点击地图移动位置，或点击建筑标点触发智能讲解',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _triggeredSpot != null
                        ? AppTheme.success
                        : AppTheme.darkBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(String? spot) {
    final hasContent = spot != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
              ),
            ],
          ),
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
                        colors: hasContent
                            ? [AppTheme.primary, const Color(0xFF3A86C5)]
                            : [
                                const Color(0xFFC2DEF5),
                                const Color(0xFF73B4E9),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasContent ? Icons.volume_up : Icons.headphones,
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
                        Text(
                          hasContent ? '正在讲解：$spot' : '等待选择景点...',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasContent
                              ? (_playing ? 'AI语音讲解播放中' : '已暂停')
                              : '点击地图上的建筑标点开始讲解',
                          style: TextStyle(
                            fontSize: 11,
                            color: hasContent
                                ? AppTheme.success
                                : AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (!hasContent) return;
                      if (_playing) {
                        _pauseGuide();
                      } else {
                        _playGuide(spot);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasContent
                            ? (_playing ? AppTheme.warning : AppTheme.success)
                            : AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasContent
                            ? (_playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded)
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasContent)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(10),
                      child: _loadingGuide
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Text(
                              _guideText.isNotEmpty
                                  ? _guideText
                                  : _getGuideText(spot),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMain,
                                height: 1.6,
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGuideText(String spot) {
    const texts = {
      '中心图书馆':
          '欢迎来到西南大学中心图书馆！这里是西南地区最大的高校图书馆之一，馆藏丰富，环境优雅。配备了阅览区、自习区、电子阅览室等多个功能区域，是同学们学习、研究的最佳场所。',
      '第八教学楼':
          '您看到的是西南大学第八教学楼，是校园内最繁忙的教学楼之一。每天都有大量师生在这里上课、自习，充满了浓厚的学术氛围。配备了现代化的多媒体教室。',
      '樟树林':
          '您已进入西南大学著名的樟树林！这片茂密的樟树林是校园内最具特色的自然景观。阳光透过枝叶洒下斑驳光影，是散步、晨读的绝佳去处，也是无数学子留下美好回忆的地方。',
      '校史馆': '欢迎来到西南大学校史馆！这里记录着学校百余年的辉煌历程，从创立之初到如今的蓬勃发展，每一件展品都承载着西大人的记忆与荣光。',
      '行署楼': '行署楼是西南大学的标志性建筑之一，具有重要的历史价值和独特的建筑风格。它见证了学校的发展和变迁，是了解校园历史文化的必访之地。',
      '共青团花园': '共青团花园是校园内一处美丽的园林景观，四季花开，景色宜人。这里是同学们休闲放松、社团活动的好去处。',
      '楠园(第四运动场)': '楠园及第四运动场是学生生活与运动的重要区域。这里有完善的运动设施和舒适的住宿环境，是校园生活的重要组成部分。',
      '竹园': '竹园是西南大学内一处宁静优雅的生活区，环境清幽，绿竹成荫。这里是同学们课余休憩的理想场所。',
      '药学院': '您来到的是药学院。西南大学药学学科实力雄厚，拥有先进的实验设备和优秀的师资队伍，为医药事业培养了大量优秀人才。',
      '音乐学院': '欢迎来到音乐学院！这里充满了艺术的气息，是培养音乐人才的重要基地。悠扬琴声和动人歌声是这里最美的风景。',
      '中心体育馆': '中心体育馆是校园体育活动的核心场所，承办过多次大型体育赛事和校园活动，是西大学子挥洒汗水、展现青春活力的地方。',
      '田家炳教育书院': '田家炳教育书院是西南大学重要的教育基地，以著名慈善家田家炳先生命名，承载着教书育人的崇高使命。',
    };
    return texts[spot] ??
        '欢迎来到$spot！这里是西南大学校园内的重要地点。请跟随AI导游的讲解，慢慢探索这片美丽的校园，感受百年学府的深厚底蕴与独特魅力。';
  }
}

class _GuideSpot {
  final String name;
  final LatLng position;
  final IconData icon;

  const _GuideSpot(this.name, this.position, this.icon);
}

class _SmartGuideMarker extends StatelessWidget {
  final _GuideSpot spot;
  final bool active;

  const _SmartGuideMarker({required this.spot, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.success : AppTheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: active ? 44 : 38,
          height: active ? 44 : 38,
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
          child: Icon(
            active ? Icons.volume_up_rounded : spot.icon,
            color: Colors.white,
            size: active ? 21 : 18,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          constraints: BoxConstraints(maxWidth: active ? 140 : 98),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0x18000000), blurRadius: 4),
            ],
          ),
          child: Text(
            active ? '讲解中：${spot.name}' : spot.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: active ? 11 : 10,
              fontWeight: FontWeight.w900,
              color: AppTheme.textMain,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8)],
      ),
      child: Center(
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  金刚区按钮组件
// ═══════════════════════════════════════════════════
class _GridButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GridButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMain,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
