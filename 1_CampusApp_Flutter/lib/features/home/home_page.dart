// lib/features/home/home_page.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

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
      final res = await NetworkClient.dio.get('/spot/list', queryParameters: {'page': 1, 'size': 100});
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
    spotsWithDistance.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

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
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
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
                  Text('📍 附近景点推荐', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                  SizedBox(height: 2),
                  Text('基于当前实时定位', style: TextStyle(fontSize: 11, color: AppTheme.textSub)),
                ],
              ),
              // 全部景点跳转按钮
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/spot/list'),
                child: const Text('全部景点 >', style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2))),

          if (!_isLoading && _closestSpots.isEmpty)
            const Center(child: Text('暂无附近景点', style: TextStyle(color: AppTheme.textSub))),

          // 动态渲染 3 个真实景点
          ..._closestSpots.map((item) {
            final SpotModel spot = item['spot'];
            String distStr = (item['distance'] as double).toStringAsFixed(0);
            return _spotTile(
                '${spot.name} (距您约${distStr}米)',
                spot.description.isNotEmpty ? spot.description : '暂无简介',
                    () {
                  // 此时传入的绝对是后端的真实 ID
                  Navigator.pushNamed(context, '/spot/detail', arguments: {'spotId': spot.id});
                }
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
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: const Color(0xCCFAFADB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white),
              ),
              child: const Icon(Icons.pin_drop_rounded, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMain)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSub), maxLines: 1, overflow: TextOverflow.ellipsis),
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
  final LocationService _loc = LocationService();
  bool _playing = false;
  String _guideText = '';
  bool _loadingGuide = false;

  String? _triggeredSpot;

  static const _spots = [
    '中心图书馆',
    '第八教学楼',
    '行署楼',
    '田家炳教育书院',
    '共青团花园',
    '校史馆',
    '樟树林',
    '楠园(第四运动场)',
    '竹园',
    '中心体育馆',
    '药学院',
    '音乐学院',
  ];

  @override
  void initState() {
    super.initState();
    _loc.addListener(_handleLocationChanged);
  }

  void _handleLocationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _loc.removeListener(_handleLocationChanged);
    _loc.dispose();
    super.dispose();
  }

  void _triggerGuide(String spot) {
    setState(() {
      _triggeredSpot = spot;
      _playing = true;
    });
    _fetchGuideContent(spot);
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
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBar(),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: _spots.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final spot = _spots[index];
                final active = spot == _triggeredSpot;
                return GestureDetector(
                  onTap: () => _triggerGuide(spot),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: active
                          ? AppTheme.primary.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: active
                            ? AppTheme.primary.withValues(alpha: 0.38)
                            : Colors.white.withValues(alpha: 0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: active ? AppTheme.primary : const Color(0xFFEAF5FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            active ? Icons.volume_up : Icons.place,
                            color: active ? Colors.white : AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spot,
                                style: const TextStyle(
                                  color: AppTheme.textMain,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '点击触发 AI 智能讲解',
                                style: TextStyle(color: AppTheme.textSub, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppTheme.textSub),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _buildAudioPlayer(_triggeredSpot),
        ],
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
          child: Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _triggeredSpot != null ? AppTheme.success : AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _triggeredSpot != null
                    ? '正在讲解「$_triggeredSpot」'
                    : '地图模块暂用列表模式，点击景点测试智能讲解服务',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _triggeredSpot != null ? AppTheme.success : AppTheme.darkBlue,
                ),
              ),
            ),
          ]),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasContent
                        ? [AppTheme.primary, const Color(0xFF3A86C5)]
                        : [const Color(0xFFC2DEF5), const Color(0xFF73B4E9)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(hasContent ? Icons.volume_up : Icons.headphones, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(hasContent ? '正在讲解：$spot' : '等待选择景点...',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMain)),
                  const SizedBox(height: 3),
                  Text(hasContent ? (_playing ? 'AI语音讲解播放中' : '已暂停') : '列表模式可直接测试后端讲解',
                      style: TextStyle(fontSize: 11, color: hasContent ? AppTheme.success : AppTheme.primary)),
                ]),
              ),
              GestureDetector(
                onTap: () => hasContent ? setState(() => _playing = !_playing) : null,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasContent ? (_playing ? AppTheme.warning : AppTheme.success) : AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasContent ? (_playing ? Icons.pause_rounded : Icons.play_arrow_rounded) : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ]),
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
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : Text(
                            _guideText.isNotEmpty ? _guideText : _getGuideText(spot),
                            style: const TextStyle(fontSize: 13, color: AppTheme.textMain, height: 1.6),
                          ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  String _getGuideText(String spot) {
    const texts = {
      '中心图书馆': '欢迎来到西南大学中心图书馆！这里是西南地区最大的高校图书馆之一，馆藏丰富，环境优雅。配备了阅览区、自习区、电子阅览室等多个功能区域，是同学们学习、研究的最佳场所。',
      '第八教学楼': '您看到的是西南大学第八教学楼，是校园内最繁忙的教学楼之一。每天都有大量师生在这里上课、自习，充满了浓厚的学术氛围。配备了现代化的多媒体教室。',
      '樟树林': '您已进入西南大学著名的樟树林！这片茂密的樟树林是校园内最具特色的自然景观。阳光透过枝叶洒下斑驳光影，是散步、晨读的绝佳去处，也是无数学子留下美好回忆的地方。',
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
    return texts[spot] ?? '欢迎来到$spot！这里是西南大学校园内的重要地点。请跟随AI导游的讲解，慢慢探索这片美丽的校园，感受百年学府的深厚底蕴与独特魅力。';
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
