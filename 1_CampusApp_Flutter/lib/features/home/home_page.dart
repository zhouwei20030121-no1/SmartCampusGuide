// lib/features/home/home_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';
import '../user/profile_page.dart';
import '../map/map_page.dart';
import '../map/map_user_location_controller.dart';
import '../location/location_service.dart';
import '../../core/network/network_client.dart';
import '../guide/guide_coordination_service.dart';
import '../route/amap_route_api.dart';
import '../spot/spot_model.dart';
import '../story/campus_story_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
                MapPage(isTabVisible: _currentIndex == 1),
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
  Set<int> _checkedSpotIds = {};
  bool _isLoading = true;
  // 新增天气状态：'晴天' 或 '雨天'
  String _currentWeather = '晴天';
  String _getSpotImageUrl(SpotModel spot) {
    String imageUrl = '';

    if (spot.coverImage.isNotEmpty) {
      imageUrl = spot.coverImage;
    } else if (spot.images.isNotEmpty) {
      imageUrl = spot.images.first;
    }

    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = '${NetworkClient.baseUrl}$imageUrl';
    }

    return imageUrl;
  }

  Timer? _weatherTimer; // 类成员

  @override
  void initState() {
    super.initState();

    _loc.addListener(_updateClosestSpots);
    _loc.startTracking();

    _initRecommendData();

    // 页面启动立即获取一次天气
    _fetchRealWeather();

    // 每30分钟刷新一次天气
    _weatherTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _fetchRealWeather(),
    );
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    _loc.removeListener(_updateClosestSpots);
    super.dispose();
  }

  // 真实天气获取逻辑
  Future<void> _fetchRealWeather() async {
    try {
      // 调用高德 Web 服务天气查询接口
      final res = await Dio().get(
        'https://restapi.amap.com/v3/weather/weatherInfo',
        queryParameters: {
          'key': AMapRouteApi.webApiKey, // 复用你现有的高德 Web API Key
          'city': '500109', // 重庆市北碚区的 adcode
          'extensions': 'base', // base 表示获取实时天气
        },
      );

      if (res.data['status'] == '1' &&
          res.data['lives'] != null &&
          res.data['lives'].isNotEmpty) {
        // 提取实况天气字符串，如 "晴", "多云", "小雨"
        final String weatherStr = res.data['lives'][0]['weather'].toString();
        debugPrint('当前北碚区天气: $weatherStr');

        if (mounted) {
          setState(() {
            // 粗略映射逻辑：只要包含“雨”或“雪”，就走雨天室内推荐；其他（晴、阴、多云）走自然景观推荐
            if (weatherStr.contains('雨') || weatherStr.contains('雪')) {
              _currentWeather = '雨天';
            } else {
              _currentWeather = '晴天';
            }
          });
          _updateClosestSpots();
        }
      }
    } catch (e) {
      debugPrint('获取天气信息失败: $e');
      // 失败时保留我们在顶部的默认值（通常是 '晴天'），不影响整个页面的渲染
    }
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

  // 加载用户打卡历史
  Future<void> _loadCheckinHistory() async {
    try {
      final res = await NetworkClient.dio.get(
        '/checkin/history/${NetworkClient.currentUserId}',
      );

      if (res.data['code'] == 200) {
        final List records = res.data['data'] ?? [];

        _checkedSpotIds = records
            .map<int>((e) => (e['spotId'] ?? 0) as int)
            .toSet();
      }
    } catch (e) {
      debugPrint('获取打卡历史失败: $e');
    }
  }

  // 初始化推荐数据
  Future<void> _initRecommendData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    // 并发拉取基础数据和用户行为数据
    await Future.wait([
      _fetchAllSpotsFromDB(),
      _loadCheckinHistory(),
      _fetchRealWeather(),
    ]);

    // 此时 _allSpots 和 _checkedSpotIds 均已就绪，再执行综合计算
    if (mounted) {
      _updateClosestSpots();
      setState(() => _isLoading = false);
    }
  }

  // 核心：多因子个性化推荐算法（距离+热度+打卡+时间+景点属性）
  void _updateClosestSpots() {
    if (_allSpots.isEmpty) return;
    debugPrint('当前天气状态=$_currentWeather');

    final rawLat = _loc.latitude != 0.0
        ? _loc.latitude
        : CampusBounds.defaultCenter.latitude;
    final rawLng = _loc.longitude != 0.0
        ? _loc.longitude
        : CampusBounds.defaultCenter.longitude;
    final recommendationCenter = CampusBounds.clampToCampus(
      LatLng(rawLat, rawLng),
    );
    final currentLat = recommendationCenter.latitude;
    final currentLng = recommendationCenter.longitude;

    final validSpots = _allSpots.where((spot) {
      return spot.longitude != 0.0 && spot.latitude != 0.0;
    }).toList();

    final maxVisitCount = validSpots.isEmpty
        ? 1
        : validSpots.map((e) => e.visitCount).reduce((a, b) => a > b ? a : b);

    final hour = DateTime.now().hour;

    final scoredSpots = validSpots.map((spot) {
      double dx = (currentLng - spot.longitude) * 111320 * 0.866;
      double dy = (currentLat - spot.latitude) * 111320;
      double distance = math.sqrt(dx * dx + dy * dy);

      // ===================
      // 1 距离因子
      // ===================
      double distanceScore = distance > 1000 ? 0 : (1000 - distance) / 1000;

      // ===================
      // 2 热度因子
      // ===================
      double popularityScore = spot.visitCount / maxVisitCount;

      // ===================
      // 3 打卡因子
      // ===================
      double checkinScore = _checkedSpotIds.contains(spot.id) ? 0.2 : 1.0;

      // ===================
      // 4 时间因子
      // ===================
      double timeScore = 0;

      bool mealTime = (hour >= 11 && hour <= 13) || (hour >= 17 && hour <= 19);

      if (mealTime && spot.name.contains("食堂")) {
        timeScore = 1;
      }

      // ===================
      // 5 天气因子(先默认晴天)
      // ===================
      double weatherScore = 0;

      if (_currentWeather == '晴天' && spot.category.contains("自然景观")) {
        // 晴天偏好室外风景
        weatherScore = 1.0;
      } else if (_currentWeather == '雨天' &&
          (spot.category.contains("生活服务") || spot.category.contains("教学设施"))) {
        // 雨天偏好室内建筑
        weatherScore = 1.0;
      }

      // ===================
      // 综合评分
      // ===================
      double score =
          distanceScore * 0.35 +
          popularityScore * 0.25 +
          checkinScore * 0.20 +
          timeScore * 0.10 +
          weatherScore * 0.10;

      return {"spot": spot, "distance": distance, "score": score};
    }).toList();

    scoredSpots.sort(
      (a, b) => (b["score"] as double).compareTo(a["score"] as double),
    );

    if (mounted) {
      setState(() {
        _closestSpots = scoredSpots.take(3).toList();
      });
    }
  }

  // 传入 distance 参数，让推荐理由更加动态多元
  String _recommendReason(SpotModel spot, double distance) {
    final hour = DateTime.now().hour;
    bool mealTime = (hour >= 11 && hour <= 13) || (hour >= 17 && hour <= 19);

    // 优先级 1：餐饮时间最高
    if (mealTime && spot.name.contains("食堂")) {
      return "🍜 用餐时间推荐";
    }

    // 优先级 2：极近距离
    if (distance < 200) {
      return "📍 就在您附近不到200米";
    }

    // 优先级 3：天气场景推荐
    if (_currentWeather == '雨天' &&
        (spot.category.contains("生活服务") || spot.category.contains("教学设施"))) {
      return "☔ 雨天室内好去处";
    }
    if (_currentWeather == '晴天' && spot.category.contains("自然景观")) {
      return "☀️ 天气晴朗，去感受自然";
    }

    // 优先级 4：热度与打卡结合
    if (!_checkedSpotIds.contains(spot.id) && spot.visitCount >= 300) {
      return "🎯 热门未打卡地";
    }

    // 优先级 5：基础未打卡提醒
    if (!_checkedSpotIds.contains(spot.id)) {
      return "✨ 探索校园新角落";
    }

    // 优先级 6：兜底热度
    if (spot.visitCount >= 50) {
      return "🔥 校园高频访问";
    }

    return "💡 智能精选推荐";
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
              bottom: 220,
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
                colors: [Color(0xFF2A5794), Color(0xFF01306B)],
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
            onTap: () => Navigator.pushNamed(context, '/checkin'),
          ),
          _GridButton(
            icon: Icons.auto_stories_outlined,
            label: '校园故事',
            onTap: () => Navigator.pushNamed(context, '/story'),
          ),
          _GridButton(
            icon: Icons.directions_bus_filled_outlined,
            label: '校车时刻',
            onTap: () => Navigator.pushNamed(context, '/bus'),
          ),
          _GridButton(
            icon: Icons.cloud_download_outlined,
            label: '离线下载',
            onTap: () => Navigator.pushNamed(context, '/offline_download'),
          ),
          _GridButton(
            icon: Icons.campaign_outlined,
            label: '校园公告',
            // 🌟 修复：跳转到公告列表页
            onTap: () => Navigator.pushNamed(context, '/announcement'),
          ),
        ],
      ),
    );
  }

  // 动态渲染推荐卡片 + "全部景点"选项
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
                    '✨ 智能景点推荐',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '综合距离、热度、打卡与场景推荐',
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
            final double dist = item['distance'] as double; // 取出计算好的距离
            String distStr = dist.toStringAsFixed(0);

            return _spotTile(
              spot,
              '${spot.name} (距您约${distStr}米)',
              '${_recommendReason(spot, dist)} · ${spot.description}',
              () {
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

  Widget _spotTile(
    SpotModel spot,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Builder(
              builder: (_) {
                final imageUrl = _getSpotImageUrl(spot);

                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 54,
                            height: 54,
                            color: const Color(0xCCFAFADB),
                            child: const Icon(
                              Icons.image_not_supported,
                              color: AppTheme.primary,
                            ),
                          ),
                        )
                      : Container(
                          width: 54,
                          height: 54,
                          color: const Color(0xCCFAFADB),
                          child: const Icon(
                            Icons.image,
                            color: AppTheme.primary,
                          ),
                        ),
                );
              },
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
// ─── 地理围栏智能讲解（使用高德底图 POI，点击地图即可模拟移动）───
class _TabSmartAudio extends StatefulWidget {
  const _TabSmartAudio();

  @override
  State<_TabSmartAudio> createState() => _TabSmartAudioState();
}

class _TabSmartAudioState extends State<_TabSmartAudio> {
  static const MethodChannel _ttsChannel = MethodChannel(
    'smart_campus_guide/tts',
  );

  final AudioPlayer _audioPlayer = AudioPlayer();
  final LocationService _loc = LocationService();
  StreamSubscription<void>? _audioCompleteSub;
  int _playbackSerial = 0;
  bool _playing = false;
  String _guideText = '';
  bool _loadingGuide = false;
  bool _loadingStory = false;
  String _persona = '新生';
  String _language = 'zh';
  String _voice = 'gentle_guide';
  String _guideMode = 'standard';
  double _speechRate = 1.0;
  bool _checkingIn = false;
  String _checkinNotice = '';
  bool _submittingFeedback = false;
  String _feedbackNotice = '';
  bool _loadingComments = false;
  final List<Map<String, dynamic>> _spotComments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _lookingUpPoi = false;
  String _poiLookupNotice = '';
  int _poiLookupSeq = 0;
  Timer? _dwellTimer;
  String? _pendingSpot;
  LatLng? _pendingSpotPos;
  double _pendingDistance = 999;
  DateTime? _pendingSince;
  int _pendingRemainingSeconds = 0;
  bool _pendingFromDemo = false;
  String _triggerNotice = '';
  String _routePriorityNotice = '';
  bool _followRealLocation = false;
  final Map<String, DateTime> _spotCooldownUntil = {};

  static const double _guideTriggerRadiusMeters = 50;
  static const int _dwellSeconds = 12;
  static const double _fastPassingSpeedMps = 1.8;
  static const int _cooldownMinutes = 30;
  static const double _routeDeviationMeters = 80;

  // 高德地图
  AMapController? _mapCtrl;
  static const _swuCenter = LatLng(29.820, 106.425);
  static final LatLngBounds _campusBounds = LatLngBounds(
    southwest: const LatLng(29.80649, 106.402434),
    northeast: const LatLng(29.835163, 106.436554),
  );
  static const _blockedPoiKeywords = [
    '咖啡',
    '瑞幸',
    '星巴克',
    '奶茶',
    '茶饮',
    '甜品',
    '餐厅',
    '饭店',
    '小吃',
    '面馆',
    '火锅',
    '烧烤',
    '超市',
    '便利',
    '商店',
    '店铺',
    '药房',
    '银行',
    '营业厅',
    '快递',
    '菜鸟',
    '驿站',
    '物流',
    '取件',
    '寄件',
    '商铺',
    '商家',
    '购物',
    '售卖',
  ];
  static const _blockedPoiTypes = ['餐饮服务', '购物服务', '生活服务', '金融保险服务'];
  // 用户模拟位置（点击地图移动，初始放在校园中心）
  LatLng _userPos = _swuCenter;
  late Marker _userMarker;

  String? _selectedPoiName;
  LatLng? _selectedPoiPos;
  String? _triggeredSpot;
  String _nearbySpot = '';
  double _nearbyDist = 999;

  @override
  void initState() {
    super.initState();
    _userMarker = _buildUserMarker(_userPos);
    _loc.addListener(_handleLocationChanged);
  }

  void _handleLocationChanged() {
    if (mounted) {
      if (_followRealLocation && !_loc.isManualMode) {
        final pos = LatLng(_loc.latitude, _loc.longitude);
        _userPos = pos;
        _userMarker = _buildUserMarker(pos);
        _evaluateRoutePriority(pos);
        _triggerNearestPoi(pos, fromDemo: false, autoCenter: false);
      }
      setState(() {});
    }
  }

  /// 点击高德 POI → 将模拟位置移动到该地名，并触发讲解。
  void _onPoiTouched(AMapPoi poi) {
    final pos = poi.latLng;
    final name = poi.name?.trim();
    if (pos == null || name == null || name.isEmpty) return;
    if (!_campusBounds.contains(pos)) {
      _showPoiNotice('请在西南大学北碚校区范围内选择位置');
      return;
    }
    if (!_isAllowedCampusPoiName(name)) {
      _showPoiNotice('商家店铺不参与智能讲解，请选择校内建筑或场所');
      return;
    }

    _selectedPoiName = name;
    _selectedPoiPos = pos;
    _moveUserTo(pos);
    _centerCameraOnUser(pos);
    _handleNearbyCandidate(name, pos, distance: 0, fromDemo: true);
  }

  /// 点击普通地图区域 → 移动"我的位置"，并用高德周边搜索识别最近地名。
  void _onMapTapped(LatLng pos) {
    if (!_campusBounds.contains(pos)) {
      _showPoiNotice('请在西南大学北碚校区范围内选择位置');
      return;
    }
    _moveUserTo(pos);
    _centerCameraOnUser(pos);
    _triggerNearestPoi(pos, fromDemo: true);
  }

  void _moveUserTo(LatLng pos) {
    _loc.updateLocation(pos.latitude, pos.longitude);
    _followRealLocation = false;
    _stopGuideSpeech();
    _cancelDwellTimer();

    setState(() {
      _userPos = pos;
      _userMarker = _userMarker.copyWith(positionParam: pos);
      _triggeredSpot = null;
      _playing = false;
      _guideText = '';
      _routePriorityNotice = '';
    });
  }

  void _triggerGuide(String spot, {double? distance, bool autoPlay = true}) {
    final shouldFetchGuide = spot != _triggeredSpot;
    _stopGuideSpeech();
    _cancelDwellTimer();

    setState(() {
      _nearbySpot = spot;
      _nearbyDist = distance ?? 0;
      _poiLookupNotice = '';
      _triggeredSpot = spot;
      _playing = autoPlay;
      _checkinNotice = '';
      _feedbackNotice = '';
      _triggerNotice = '';
      _pendingSpot = null;
      _pendingSince = null;
      _pendingRemainingSeconds = 0;
      _spotCooldownUntil[spot] = DateTime.now().add(
        const Duration(minutes: _cooldownMinutes),
      );
    });

    _autoCheckin(spot);
    _fetchComments(spot);
    if (shouldFetchGuide) {
      _fetchGuideContent(spot);
    } else {
      if (autoPlay) _playGuide(spot);
    }
  }

  void _handleNearbyCandidate(
    String spot,
    LatLng pos, {
    required double distance,
    required bool fromDemo,
  }) {
    _evaluateRoutePriority(pos);

    final cooldownUntil = _spotCooldownUntil[spot];
    if (cooldownUntil != null && cooldownUntil.isAfter(DateTime.now())) {
      final minutes = cooldownUntil.difference(DateTime.now()).inMinutes + 1;
      setState(() {
        _nearbySpot = spot;
        _nearbyDist = distance;
        _poiLookupNotice = '「$spot」刚刚讲解过，约 $minutes 分钟后可再次自动触发';
      });
      return;
    }

    if (!fromDemo && _loc.speedMps >= _fastPassingSpeedMps) {
      setState(() {
        _nearbySpot = spot;
        _nearbyDist = distance;
        _poiLookupNotice = '已靠近「$spot」，但你移动较快，先不自动触发讲解';
      });
      return;
    }

    _pendingSpot = spot;
    _pendingSpotPos = pos;
    _pendingDistance = distance;
    _pendingFromDemo = fromDemo;
    _pendingSince = DateTime.now();
    _pendingRemainingSeconds = fromDemo ? 0 : _dwellSeconds;

    setState(() {
      _nearbySpot = spot;
      _nearbyDist = distance;
      _triggerNotice = fromDemo
          ? '已模拟靠近「$spot」，可以开始讲解'
          : '已靠近「$spot」，停留 $_dwellSeconds 秒后可播放讲解';
      _poiLookupNotice = '';
    });

    if (fromDemo) return;
    _startDwellCountdown();
  }

  void _startDwellCountdown() {
    _cancelDwellTimer();
    _dwellTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final pending = _pendingSpot;
      final pendingPos = _pendingSpotPos;
      final since = _pendingSince;
      if (pending == null || pendingPos == null || since == null) {
        timer.cancel();
        return;
      }

      final currentDistance = _distanceInMeters(_userPos, pendingPos);
      if (currentDistance > _guideTriggerRadiusMeters) {
        _cancelDwellTimer();
        setState(() {
          _triggerNotice = '已离开「$pending」范围，讲解未触发';
          _pendingSpot = null;
          _pendingRemainingSeconds = 0;
        });
        return;
      }

      if (_loc.speedMps >= _fastPassingSpeedMps) {
        _cancelDwellTimer();
        setState(() {
          _triggerNotice = '移动速度较快，已暂停「$pending」自动讲解';
          _pendingSpot = null;
          _pendingRemainingSeconds = 0;
        });
        return;
      }

      final elapsed = DateTime.now().difference(since).inSeconds;
      final remaining = math.max(0, _dwellSeconds - elapsed);
      setState(() {
        _pendingRemainingSeconds = remaining;
        _triggerNotice = remaining == 0
            ? '已在「$pending」附近停留，可以播放讲解'
            : '已靠近「$pending」，继续停留 $remaining 秒';
      });
      if (remaining == 0) {
        _cancelDwellTimer();
      }
    });
  }

  void _cancelDwellTimer() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
  }

  void _evaluateRoutePriority(LatLng pos) {
    final guideState = GuideCoordinationService.instance;
    if (!guideState.hasActiveRoute) {
      _routePriorityNotice = '';
      return;
    }
    final routeDistance = guideState.distanceToActiveRoute(pos);
    if (routeDistance > _routeDeviationMeters) {
      _routePriorityNotice =
          '你已偏离${guideState.routeLabel}约${routeDistance.toStringAsFixed(0)}米，可继续播放附近景点讲解';
    } else {
      _routePriorityNotice = '';
    }
  }

  Future<void> _autoCheckin(String spot, {bool manual = false}) async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    try {
      final res = await NetworkClient.dio.post(
        '/checkin/by-spot-name',
        data: {'userId': NetworkClient.currentUserId, 'spotName': spot},
      );
      final ok = res.data['code'] == 200;
      final spotName = res.data['data']?['spotName']?.toString() ?? spot;
      if (!mounted) return;
      setState(() {
        _checkinNotice = ok
            ? '已打卡：$spotName'
            : (res.data['message'] ?? res.data['msg'] ?? '打卡失败').toString();
      });
      if (manual) {
        _showTtsNotice(_checkinNotice);
      }
    } catch (e) {
      debugPrint('鑷姩鎵撳崱澶辫触: $e');
      if (mounted) {
        setState(() => _checkinNotice = '未匹配到可打卡景点');
      }
    } finally {
      if (mounted) {
        setState(() => _checkingIn = false);
      }
    }
  }

  double _distanceInMeters(LatLng a, LatLng b) {
    final dx = (a.longitude - b.longitude) * 111320 * 0.866;
    final dy = (a.latitude - b.latitude) * 111320;
    return math.sqrt(dx * dx + dy * dy);
  }

  Future<void> _triggerNearestPoi(
    LatLng pos, {
    required bool fromDemo,
    bool autoCenter = true,
  }) async {
    final seq = ++_poiLookupSeq;
    setState(() {
      _lookingUpPoi = true;
      _poiLookupNotice = '';
    });

    try {
      final res = await Dio().get(
        'https://restapi.amap.com/v3/place/around',
        queryParameters: {
          'key': AMapRouteApi.webApiKey,
          'location': '${pos.longitude},${pos.latitude}',
          'radius': 180,
          'offset': 25,
          'page': 1,
          'sortrule': 'distance',
          'extensions': 'base',
        },
      );
      if (!mounted || seq != _poiLookupSeq) return;

      final pois = res.data['pois'];
      if (pois is List && pois.isNotEmpty) {
        Map? candidate;
        for (final poi in pois.whereType<Map>()) {
          if (_isCampusPoi(poi)) {
            candidate = poi;
            break;
          }
        }
        if (candidate == null) {
          _showPoiNotice('附近没有识别到可讲解的校内建筑或场所');
          return;
        }

        final name = candidate['name']!.toString().trim();
        final distance = double.tryParse(
          candidate['distance']?.toString() ?? '',
        );
        final poiPos =
            _parseAmapLocation(candidate['location']?.toString()) ?? pos;
        _selectedPoiName = name;
        _selectedPoiPos = poiPos;
        if (autoCenter) {
          _centerCameraOnUser(pos);
        }
        _handleNearbyCandidate(
          name,
          poiPos,
          distance: distance ?? _distanceInMeters(pos, poiPos),
          fromDemo: fromDemo,
        );
      }
    } catch (e) {
      debugPrint('高德周边地名识别失败: $e');
    } finally {
      if (mounted && seq == _poiLookupSeq) {
        setState(() => _lookingUpPoi = false);
      }
    }
  }

  bool _isCampusPoi(Map poi) {
    final name = poi['name']?.toString().trim();
    if (name == null || name.isEmpty) return false;
    final type = poi['type']?.toString() ?? '';
    if (_containsAny(name, _blockedPoiKeywords)) return false;
    if (_containsAny(type, _blockedPoiTypes)) return false;
    return true;
  }

  bool _isAllowedCampusPoiName(String name) {
    if (_containsAny(name, _blockedPoiKeywords)) return false;
    return true;
  }

  bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }

  void _showPoiNotice(String notice) {
    _stopGuideSpeech();
    _cancelDwellTimer();
    setState(() {
      _lookingUpPoi = false;
      _poiLookupNotice = notice;
      _triggeredSpot = null;
      _pendingSpot = null;
      _pendingSince = null;
      _pendingRemainingSeconds = 0;
      _playing = false;
      _guideText = '';
    });
  }

  LatLng? _parseAmapLocation(String? location) {
    if (location == null || location.isEmpty) return null;
    final parts = location.split(',');
    if (parts.length != 2) return null;
    final lng = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  void _centerCameraOnUser(LatLng pos, {bool animated = true}) {
    _mapCtrl?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: pos, zoom: 17, tilt: 0, bearing: 0),
      ),
      animated: animated,
    );
  }

  Future<void> _useRealLocation() async {
    _followRealLocation = true;
    _cancelDwellTimer();
    await _loc.startTracking();
    final pos = LatLng(_loc.latitude, _loc.longitude);
    if (_loc.realLocationAvailable && _campusBounds.contains(pos)) {
      setState(() {
        _userPos = pos;
        _userMarker = _buildUserMarker(pos);
        _poiLookupNotice = '已切换到真实定位';
      });
      _centerCameraOnUser(pos);
      _triggerNearestPoi(pos, fromDemo: false);
    } else {
      setState(() {
        _followRealLocation = false;
        _poiLookupNotice = '真实定位暂不可用，已保留地图演示模式';
      });
    }
  }

  Marker _buildUserMarker(LatLng pos) {
    return Marker(
      position: pos,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: '我的位置', snippet: '可拖动，也可点击地图移动'),
      draggable: true,
      onDragEnd: (_, position) {
        _moveUserTo(position);
        _triggerNearestPoi(position, fromDemo: true);
      },
    );
  }

  String _currentGuideText(String spot) {
    final generated = _sanitizeGuideText(_guideText);
    return generated.isNotEmpty
        ? generated
        : _sanitizeGuideText(_getGuideText(spot));
  }

  Future<bool> _speakGuideText(String text, int playbackSerial) async {
    final content = _sanitizeGuideText(text);
    if (content.isEmpty) return false;
    final voice = _voice;
    final language = _language;
    final rate = _speechRate;
    try {
      final res = await NetworkClient.aiDio.post(
        '/api/tts/synthesize',
        data: {
          'text': content,
          'voice': voice,
          'language': language,
          'rate': rate,
        },
      );
      final payload = res.data['data'];
      final audioUrl = payload is Map ? payload['url']?.toString() : null;
      if (audioUrl != null && audioUrl.isNotEmpty) {
        if (!mounted || playbackSerial != _playbackSerial) return false;
        await _stopGuideSpeech(invalidate: false);
        if (!mounted || playbackSerial != _playbackSerial) return false;
        await _audioPlayer.setReleaseMode(ReleaseMode.stop);
        _audioCompleteSub?.cancel();
        _audioCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted && playbackSerial == _playbackSerial) {
            setState(() => _playing = false);
          }
        });
        await _audioPlayer.play(UrlSource(_resolveTtsAudioUrl(audioUrl)));
        return true;
      }
    } catch (e) {
      debugPrint('云端 TTS 播放失败，回退系统 TTS: $e');
    }

    if (!mounted || playbackSerial != _playbackSerial) return false;
    await _stopGuideSpeech(invalidate: false);
    if (!mounted || playbackSerial != _playbackSerial) return false;
    try {
      final result = await _ttsChannel.invokeMapMethod<String, dynamic>(
        'speak',
        {'text': content, 'voice': voice, 'language': language, 'rate': rate},
      );
      if (result?['ok'] == true) {
        return true;
      }
      _showTtsNotice(result?['reason']?.toString() ?? 'TTS 播放失败');
    } catch (e) {
      _showTtsNotice('TTS 通道未生效，请停止 App 后重新 Run');
      debugPrint('TTS 播放失败: $e');
    }
    return false;
  }

  String _sanitizeGuideText(String text) {
    return text
        .replaceAll(RegExp(r'[（(][^（）()]{0,120}[）)]'), '')
        .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'[*#>`_~]+'), '')
        .replaceAll(
          RegExp(
            r'(脚步声|手指|指向|转身|微笑|笑意|镜头|旁白|动作|语气|停顿|音效|音乐|掌声|轻声|大声|慢速|快速)[^。！？\n]{0,80}[。！？]?',
          ),
          '',
        )
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim()
        .replaceAll(RegExp(r'^[，,。；;\s]+|[，,。；;\s]+$'), '');
  }

  String _resolveTtsAudioUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = NetworkClient.aiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    final path = url.startsWith('/') ? url : '/$url';
    return '$base$path';
  }

  Future<void> _stopGuideSpeech({bool invalidate = true}) async {
    if (invalidate) _playbackSerial++;
    _audioCompleteSub?.cancel();
    _audioCompleteSub = null;
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('云端 TTS 停止失败: $e');
    }
    try {
      await _ttsChannel.invokeMethod('stop');
    } catch (e) {
      debugPrint('TTS 停止失败: $e');
    }
  }

  Future<void> _playGuide(String spot) async {
    final playbackSerial = ++_playbackSerial;
    await _stopGuideSpeech(invalidate: false);
    if (!mounted || playbackSerial != _playbackSerial) return;
    setState(() => _playing = true);
    final ok = await _speakGuideText(_currentGuideText(spot), playbackSerial);
    if (mounted && !ok) {
      setState(() => _playing = false);
    }
  }

  Future<void> _pauseGuide() async {
    setState(() => _playing = false);
    await _stopGuideSpeech();
  }

  void _showTtsNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _stopGuideSpeech();
    _cancelDwellTimer();
    _audioPlayer.dispose();
    _commentController.dispose();
    _loc.removeListener(_handleLocationChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 高德地图
        AMapWidget(
          mapType: MapType.normal,
          privacyStatement: const AMapPrivacyStatement(
            hasContains: true,
            hasShow: true,
            hasAgree: true,
          ),
          initialCameraPosition: const CameraPosition(
            target: _swuCenter,
            zoom: 17,
            tilt: 0,
            bearing: 0,
          ),
          markers: {_userMarker}.toSet(),
          onMapCreated: (c) {
            _mapCtrl = c;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _centerCameraOnUser(_userPos, animated: false);
            });
          },
          onTap: _onMapTapped,
          onPoiTouched: _onPoiTouched,
          touchPoiEnabled: true,
          minMaxZoomPreference: const MinMaxZoomPreference(16.0, 20.0),
          buildingsEnabled: true,
          labelsEnabled: true,
        ),
        // 缩放按钮（右上角）
        Positioned(
          right: 16,
          top: 80,
          child: Column(
            children: [
              _zoomBtn(
                Icons.add,
                () => _mapCtrl?.moveCamera(CameraUpdate.zoomIn()),
                tooltip: '放大',
              ),
              const SizedBox(height: 6),
              _zoomBtn(
                Icons.remove,
                () => _mapCtrl?.moveCamera(CameraUpdate.zoomOut()),
                tooltip: '缩小',
              ),
              const SizedBox(height: 6),
              _zoomBtn(Icons.gps_fixed, _useRealLocation, tooltip: '真实定位'),
              const SizedBox(height: 6),
              _zoomBtn(
                Icons.center_focus_strong,
                () => _mapCtrl?.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _userPos,
                      zoom: 17,
                      tilt: 0,
                      bearing: 0,
                    ),
                  ),
                ),
                tooltip: '回到当前位置',
              ),
            ],
          ),
        ),
        // 顶部状态条
        Positioned(top: 16, left: 16, right: 66, child: _buildStatusBar()),
        // 触发横幅
        if (_pendingSpot != null)
          Positioned(
            top: 76,
            left: 16,
            right: 16,
            child: _buildPendingBanner(_pendingSpot!),
          )
        else if (_triggeredSpot != null)
          Positioned(
            top: 76,
            left: 16,
            right: 16,
            child: _buildTriggerBanner(_triggeredSpot!),
          ),
        // 底部音频
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          bottom: 110,
          left: 16,
          right: _playing ? 16 : 85,
          child: _buildAudioPlayer(_triggeredSpot),
        ),
      ],
    );
  }

  Widget _zoomBtn(
    IconData icon,
    VoidCallback onTap, {
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
      ),
    );
  }

  Future<void> _fetchGuideContent(String spot) async {
    setState(() {
      _loadingGuide = true;
      _guideText = '';
    });
    var text = '';
    try {
      final res = await NetworkClient.dio.post(
        '/ai/guide/dynamic',
        data: {
          'spotName': spot,
          'persona': _persona,
          'language': _language,
          'voice': _voice,
          'style': _guideMode,
          'guideMode': _guideMode,
          'environment': {
            'client': 'mobile_app',
            'scene': 'smart_audio_guide',
            'triggerMode': _pendingFromDemo ? 'manual_demo' : _loc.locationMode,
            'speedMps': _loc.speedMps,
            'distanceMeters': _nearbyDist,
          },
        },
      );
      if (res.data['code'] == 200) {
        text = (res.data['data']['text'] ?? '').toString().trim();
      }
    } catch (_) {}
    if (text.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _guideText = _sanitizeGuideText(text);
        _loadingGuide = false;
      });
      if (_triggeredSpot == spot && _playing) {
        await _playGuide(spot);
        return;
      }
      return;
    }
    try {
      final res = await NetworkClient.dio.get(
        '/ai/guide/generate',
        queryParameters: {
          'spotName': spot,
          'persona': _persona,
          'language': _language,
        },
      );
      if (res.data['code'] == 200) {
        text = (res.data['data']['text'] ?? '').toString().trim();
      }
    } catch (_) {
      text = _getGuideText(spot);
    } finally {
      if (!mounted) return;
      if (text.isEmpty) {
        text = _getGuideText(spot);
      }
      setState(() {
        _guideText = _sanitizeGuideText(text);
        _loadingGuide = false;
      });
      if (_triggeredSpot == spot && _playing) {
        await _playGuide(spot);
      }
    }
  }

  Future<void> _openStoryDialog(String spot) async {
    setState(() => _loadingStory = true);
    final stories = <Map<String, dynamic>>[];
    try {
      final res = await NetworkClient.dio.get(
        '/ai/story/list',
        queryParameters: {
          'spotName': spot,
          'language': _language,
          'page': 1,
          'size': 30,
        },
      );
      final records = res.data['data']?['records'];
      if (records is List) {
        stories.addAll(
          records.whereType<Map>().map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
      }
    } catch (e) {
      debugPrint('校园故事列表加载失败: $e');
    } finally {
      if (mounted) setState(() => _loadingStory = false);
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.58,
        minChildSize: 0.36,
        maxChildSize: 0.88,
        builder: (context, controller) => Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_stories_outlined,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$spot 的校园故事',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: stories.isEmpty
                    ? ListView(
                        controller: controller,
                        children: const [
                          SizedBox(height: 42),
                          Icon(
                            Icons.auto_stories_outlined,
                            size: 48,
                            color: AppTheme.primary,
                          ),
                          SizedBox(height: 12),
                          Text(
                            '这个地点暂时还没有校园故事。你可以在"我的-写校园故事"里补充一段，其他人讲解时也会看到。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: AppTheme.textSub,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: controller,
                        itemCount: stories.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final story = stories[index];
                          final title =
                              (story['title'] ?? story['spotName'] ?? '校园故事')
                                  .toString();
                          final content =
                              (story['storyContent'] ?? story['story'] ?? '')
                                  .toString();
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CampusStoryDetailPage(story: story),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    content,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.55,
                                      color: AppTheme.textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchComments(String spot) async {
    setState(() => _loadingComments = true);
    try {
      final res = await NetworkClient.dio.get(
        '/comment/spot-name',
        queryParameters: {'spotName': spot},
      );
      final data = res.data['data'];
      if (res.data['code'] == 200 && data is List) {
        if (!mounted) return;
        setState(() {
          _spotComments
            ..clear()
            ..addAll(
              data.whereType<Map>().map(
                (item) => Map<String, dynamic>.from(item),
              ),
            );
        });
      }
    } catch (e) {
      debugPrint('评论加载失败: $e');
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _submitComment(String spot) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      _showTtsNotice('请输入评论内容');
      return;
    }
    try {
      final res = await NetworkClient.dio.post(
        '/comment/by-spot-name',
        data: {
          'userId': NetworkClient.currentUserId,
          'spotName': spot,
          'content': content,
          'rating': 5,
        },
      );
      if (res.data['code'] == 200) {
        _commentController.clear();
        _showTtsNotice('评论已提交，审核通过后会展示');
        _fetchComments(spot);
      } else {
        _showTtsNotice(
          (res.data['message'] ?? res.data['msg'] ?? '评论提交失败').toString(),
        );
      }
    } catch (e) {
      debugPrint('评论提交失败: $e');
      _showTtsNotice('评论提交失败，请检查后端服务');
    }
  }

  Future<void> _submitGuideFeedback(String spot, String feedback) async {
    if (_submittingFeedback) return;
    setState(() => _submittingFeedback = true);
    try {
      final res = await NetworkClient.dio.post(
        '/stats/guide-feedback',
        data: {
          'userId': NetworkClient.currentUserId,
          'spotName': spot,
          'feedback': feedback,
          'persona': _persona,
          'language': _language,
          'guideMode': _guideMode,
        },
      );
      if (!mounted) return;
      setState(() {
        _feedbackNotice = res.data['code'] == 200
            ? '已收到反馈：$feedback'
            : '反馈提交失败';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _feedbackNotice = '反馈提交失败，稍后再试');
    } finally {
      if (mounted) setState(() => _submittingFeedback = false);
    }
  }

  Widget _buildFeedbackSection(String spot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tips_and_updates_outlined,
                size: 16,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                '讲解反馈',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain,
                ),
              ),
              const Spacer(),
              if (_submittingFeedback)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _smallFeedbackChip(spot, '有用'),
              _smallFeedbackChip(spot, '太长'),
              _smallFeedbackChip(spot, '不准确'),
              _smallFeedbackChip(spot, '想听历史'),
              _smallFeedbackChip(spot, '想听实用信息'),
            ],
          ),
          if (_feedbackNotice.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _feedbackNotice,
              style: const TextStyle(fontSize: 11, color: AppTheme.success),
            ),
          ],
        ],
      ),
    );
  }

  Widget _smallFeedbackChip(String spot, String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      onPressed: _submittingFeedback
          ? null
          : () => _submitGuideFeedback(spot, label),
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.12)),
    );
  }

  Widget _buildStatusBar() {
    final modeLabel = _loc.locationMode == 'real'
        ? 'GPS ${_loc.accuracyMeters > 0 ? '±${_loc.accuracyMeters.toStringAsFixed(0)}m' : ''}'
        : _loc.locationMode == 'manual_demo'
        ? '手动演示'
        : '演示模式';
    final statusText = _triggeredSpot != null
        ? '已进入「$_triggeredSpot」范围'
        : _pendingSpot != null
        ? _triggerNotice
        : _lookingUpPoi
        ? '正在识别附近高德地名...'
        : _poiLookupNotice.isNotEmpty
        ? _poiLookupNotice
        : _nearbySpot.isNotEmpty
        ? '距$_nearbySpot约${_nearbyDist.toStringAsFixed(0)}米 · $modeLabel'
        : '拖动我的位置或点击地图模拟，也可点 GPS 使用真实定位';
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
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
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _triggeredSpot != null
                        ? AppTheme.success
                        : AppTheme.darkBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                modeLabel,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTriggerBanner(String spot) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '已进入「$spot」范围，讲解已触发',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMain,
                    fontSize: 14,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _stopGuideSpeech();
                  setState(() {
                    _triggeredSpot = null;
                    _playing = false;
                  });
                },
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppTheme.textSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingBanner(String spot) {
    final ready = _pendingFromDemo || _pendingRemainingSeconds == 0;
    final subtitle = _routePriorityNotice.isNotEmpty
        ? '$_routePriorityNotice，是否播放「$spot」？'
        : ready
        ? '是否播放「$spot」的智能讲解？'
        : '请在附近停留 $_pendingRemainingSeconds 秒，避免路过误触发';
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                ready ? Icons.play_circle_outline : Icons.hourglass_top_rounded,
                color: ready ? AppTheme.success : AppTheme.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '靠近「$spot」',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMain,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSub,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  _cancelDwellTimer();
                  setState(() {
                    _pendingSpot = null;
                    _triggerNotice = '';
                  });
                },
                child: const Text('稍后'),
              ),
              FilledButton(
                onPressed: ready
                    ? () => _triggerGuide(spot, distance: _pendingDistance)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
                child: const Text('播放'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideOptions(String spot, bool expanded) {
    if (!expanded) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          _optionRow([
            _optionMenu(
              icon: Icons.person_outline,
              value: _persona,
              items: const {'新生': '新生', '校友': '校友', '游客': '游客'},
              onChanged: (value) {
                setState(() => _persona = value);
                _fetchGuideContent(spot);
              },
            ),
            _optionMenu(
              icon: Icons.translate,
              value: _languageLabel(_language),
              items: const {
                'zh': '中文',
                'en': 'EN',
                'ja': '日本語',
                'fr': 'FR',
                'ko': '한국어',
              },
              onChanged: (value) {
                setState(() => _language = value);
                _fetchGuideContent(spot);
              },
            ),
          ]),
          const SizedBox(height: 8),
          _optionRow([
            _optionMenu(
              icon: Icons.record_voice_over_outlined,
              value: _voiceLabel(_voice),
              items: const {
                'gentle_guide': '阳光女声',
                'young_female': '温柔女声',
                'young_male': '朝气男声',
                'calm_male': '京腔男声',
              },
              onChanged: (value) {
                setState(() => _voice = value);
                if (_playing) {
                  _playGuide(spot);
                }
              },
            ),
            _optionMenu(
              icon: Icons.tune_rounded,
              value: _guideModeLabel(_guideMode),
              items: const {
                'standard': '标准讲解',
                'deep': '深度讲解',
                'story': '趣味故事',
                'practical': '实用信息',
              },
              onChanged: (value) {
                setState(() => _guideMode = value);
                _fetchGuideContent(spot);
              },
            ),
          ]),
          const SizedBox(height: 8),
          _optionRow([
            _optionMenu(
              icon: Icons.speed_rounded,
              value:
                  '${_speechRate.toStringAsFixed(_speechRate == 1.0 ? 0 : 2)}x',
              items: const {'0.8': '0.8x', '1.0': '1.0x', '1.25': '1.25x'},
              onChanged: (value) {
                setState(() => _speechRate = double.tryParse(value) ?? 1.0);
                if (_playing) _playGuide(spot);
              },
            ),
            _actionChip(
              icon: Icons.flag_outlined,
              label: _checkingIn ? '打卡中' : '打卡',
              onTap: _checkingIn
                  ? null
                  : () => _autoCheckin(spot, manual: true),
            ),
          ]),
          const SizedBox(height: 8),
          _optionRow([
            _actionChip(
              icon: Icons.more_time_rounded,
              label: '讲详细点',
              onTap: () {
                setState(() => _guideMode = 'deep');
                _fetchGuideContent(spot);
              },
            ),
            _actionChip(
              icon: Icons.swap_calls_rounded,
              label: '换个角度',
              onTap: () {
                setState(() {
                  _guideMode = _persona == '新生' ? 'practical' : 'standard';
                  _persona = _persona == '游客' ? '校友' : '游客';
                });
                _fetchGuideContent(spot);
              },
            ),
          ]),
          const SizedBox(height: 8),
          _optionRow([
            _actionChip(
              icon: Icons.theater_comedy_outlined,
              label: '讲个故事',
              onTap: () {
                setState(() => _guideMode = 'story');
                _fetchGuideContent(spot);
              },
            ),
            _actionChip(
              icon: Icons.auto_stories_outlined,
              label: _loadingStory ? '加载中' : '校园故事',
              onTap: _loadingStory ? null : () => _openStoryDialog(spot),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _optionRow(List<Widget> children) {
    return Row(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }

  Widget _optionMenu({
    required IconData icon,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    return PopupMenuButton<String>(
      tooltip: value,
      onSelected: onChanged,
      itemBuilder: (context) => items.entries
          .map(
            (entry) =>
                PopupMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      child: Container(
        height: 32,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: AppTheme.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 32,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(
            alpha: onTap == null ? 0.08 : 0.14,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: AppTheme.success),
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

  Widget _buildCommentSection(String spot) {
    final recent = _spotComments.take(3).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 16,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                '历史互动评论',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain,
                ),
              ),
              const Spacer(),
              if (_loadingComments)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            const Text(
              '还没有审核通过的评论，来留下第一段校园记忆吧。',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSub,
                height: 1.5,
              ),
            )
          else
            ...recent.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '"${item['content'] ?? ''}"',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMain,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  minLines: 1,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: '写下你的校园感想',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.72),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '提交评论',
                onPressed: () => _submitComment(spot),
                icon: const Icon(Icons.send_rounded),
                color: AppTheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _voiceLabel(String voice) {
    return switch (voice) {
      'young_male' => '朝气男声',
      'young_female' => '温柔女声',
      'calm_male' => '京腔男声',
      _ => '阳光女声',
    };
  }

  String _guideModeLabel(String mode) {
    return switch (mode) {
      'deep' => '深度讲解',
      'story' => '趣味故事',
      'practical' => '实用信息',
      _ => '标准讲解',
    };
  }

  String _languageLabel(String language) {
    return switch (language) {
      'en' => 'EN',
      'ja' => '日本語',
      'fr' => 'FR',
      'ko' => '한국어',
      _ => '中文',
    };
  }

  Widget _buildAudioPlayer(String? spot) {
    final hasContent = spot != null;
    final expanded = hasContent && _playing;
    final textHeight = expanded
        ? math.min(260.0, MediaQuery.of(context).size.height * 0.30)
        : 75.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
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
                            ? [AppTheme.primary, const Color(0xFF01306B)]
                            : [
                                const Color(0xFFB8C9E0),
                                const Color(0xFF2A5794),
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
                          hasContent ? '正在讲解：$spot' : '等待选择地图地名...',
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
                              : '点击高德地名或地图位置模拟移动',
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
                    onTap: hasContent
                        ? () {
                            if (_playing) {
                              _pauseGuide();
                            } else {
                              _playGuide(spot!);
                            }
                          }
                        : null,
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
              if (hasContent) _buildGuideOptions(spot, expanded),
              if (hasContent)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(top: 10),
                  height: textHeight,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(expanded ? 14 : 10),
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
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _guideText.isNotEmpty
                                      ? _guideText
                                      : _getGuideText(spot),
                                  style: TextStyle(
                                    fontSize: expanded ? 14 : 13,
                                    color: AppTheme.textMain,
                                    height: 1.65,
                                  ),
                                ),
                                if (_checkinNotice.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 16,
                                        color: AppTheme.success,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _checkinNotice,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.success,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (expanded) ...[
                                  const SizedBox(height: 12),
                                  _buildCommentSection(spot),
                                  const SizedBox(height: 12),
                                  _buildFeedbackSection(spot),
                                ],
                              ],
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
