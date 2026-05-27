import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../user/profile_page.dart'; // 💡 新增：引入刚刚写好的真实个人中心页面
import '../map/map_page.dart';      // 🌟 新增：引入真实的高德地图页面

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

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
              errorBuilder: (_, __, ___) =>
                  Container(color: AppTheme.pageBg),
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
                  alpha: (_currentIndex == 1 || _currentIndex == 2) ? 0.25 : 0.45,
                ),
              ),
            ),
          ),
          // 3. 主体内容（IndexedStack 保持各Tab状态）
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                _TabHome(),
                MapPage(),      // 🌟 修改：这里替换为了真实的地图页面
                _TabSmartAudio(),
                ProfilePage(), // 💡 修改：这里替换为了真实的个人中心页面
              ],
            ),
          ),
        ],
      ),
      // 4. 西小导悬浮球
      floatingActionButton: _buildXiXiaoDaoFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // 5. 底部导航
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ═══════════════════════════════════════════
  //  西小导 AI 悬浮球
  // ═══════════════════════════════════════════
  Widget _buildXiXiaoDaoFab(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.support_agent_rounded,
                  color: AppTheme.primary, size: 30),
              onPressed: () => _showChatSheet(context),
            ),
          ),
        ),
      ),
    );
  }

  void _showChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.55,
            color: Colors.white.withValues(alpha: 0.85),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('西小导 · AI 智能体',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkBlue)),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close,
                          color: AppTheme.textSub),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Expanded(
                  child: Center(
                    child: Text(
                      '在此对接大模型多轮连续对话\n与语音语义转译库。\n\n输入上下文语义可自动关联历史对话。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textSub,
                          fontSize: 13,
                          height: 1.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              onTap: (i) => setState(() => _currentIndex = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: const Color(0xFF64748B),
              selectedFontSize: 11,
              unselectedFontSize: 11,
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.home_filled), label: '首页'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.explore_outlined), label: '地图导览'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.headphones_rounded), label: '智能讲解'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline_rounded), label: '我的'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  TAB 0：首页 — 全局聚合入口
// ═══════════════════════════════════════════════════
class _TabHome extends StatelessWidget {
  const _TabHome();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopSearchBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(
                left: 16, right: 16, top: 10, bottom: 120),
            children: [
              // Banner
              _buildBanner(),
              const SizedBox(height: 20),
              // 金刚区 8宫格
              _buildGridNav(context),
              const SizedBox(height: 20),
              // 推荐卡片
              _buildRecommendCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopSearchBar() {
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    blurRadius: 6),
              ],
            ),
            child: const Center(
              child: Text('西大',
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      color: Colors.black45.withValues(alpha: 0.6),
                      size: 18),
                  const SizedBox(width: 8),
                  Text('搜索校园景点、服务设施...',
                      style: TextStyle(
                          color: Colors.black38.withValues(alpha: 0.6),
                          fontSize: 13)),
                ],
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
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/shouye.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, _) => Container(
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
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.8), width: 1.5),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 20,
        alignment: WrapAlignment.spaceAround,
        children: [
          _GridButton(
              icon: Icons.map_outlined,
              label: '校园地图',
              onTap: () => _switchTab(context, 1)),
          _GridButton(
              icon: Icons.route_outlined,
              label: '路线规划',
              onTap: () => _switchTab(context, 1)),
          _GridButton(
              icon: Icons.view_in_ar_rounded,
              label: 'AR 扫一扫',
              onTap: () => _navTo(context, '/ar')),
          _GridButton(
              icon: Icons.workspace_premium_outlined,
              label: '景点打卡',
              onTap: () => _switchTab(context, 3)),
          _GridButton(
              icon: Icons.auto_stories_outlined,
              label: '校园故事',
              onTap: () => _navTo(context, '/checkin')),
          _GridButton(
              icon: Icons.directions_bus_filled_outlined,
              label: '校车时刻',
              onTap: () {}),
          _GridButton(
              icon: Icons.cloud_download_outlined,
              label: '离线下载',
              onTap: () {}),
          _GridButton(
              icon: Icons.campaign_outlined,
              label: '校园公告',
              onTap: () {}),
        ],
      ),
    );
  }

  void _switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_HomePageState>();
    state?.setState(() => state._currentIndex = index);
  }

  void _navTo(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  Widget _buildRecommendCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.8), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📍 实时推荐建筑',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain)),
          const SizedBox(height: 16),
          _SpotTile('樟树林点位', '漫步天然氧吧，结合实时定位触发文化故事播报'),
          _SpotTile('第25教学楼', '计算机与信息科学学院，智能讲解核心围栏触发区'),
        ],
      ),
    );
  }

  Widget _SpotTile(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
            child: const Icon(Icons.pin_drop_rounded,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textMain)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSub),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  TAB 1：地图导览 — 空间检索+路线规划 (3.1.2 + 3.2.4)
// ═══════════════════════════════════════════════════
class _TabMapGuide extends StatelessWidget {
  const _TabMapGuide();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alt_route_rounded,
              size: 70,
              color: AppTheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          const Text('全局智能路线规划大地图',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSub)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('配置高德地图 + 全局路径重绘',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  TAB 2：智能讲解 — LBS地理围栏 + 音频 (3.1.3+3.1.4+3.1.5)
// ═══════════════════════════════════════════════════
class _TabSmartAudio extends StatelessWidget {
  const _TabSmartAudio();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 地图占位层
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.radar_rounded,
                  size: 70,
                  color: AppTheme.primary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              const Text('实时定位与位置感知讲解图盘',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('地理围栏核心检测中：触发半径 50米',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        // 顶部：自动讲解开关
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6)),
                ),
                child: const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_searching_rounded,
                            color: AppTheme.primary, size: 20),
                        SizedBox(width: 8),
                        Text('LBS 靠近建筑自动播报讲解',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textMain)),
                      ],
                    ),
                    // 开关（默认开启）
                    _GeoSwitch(),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 底部：音频播放控制器
        Positioned(
          bottom: 110,
          left: 16,
          right: 85,
          child: ClipRRect(
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
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color:
                        Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16),
                  ],
                ),
                child: Row(
                  children: [
                    // 建筑缩略图
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFC2DEF5),
                          Color(0xFF73B4E9)
                        ]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.white,
                          size: 22),
                    ),
                    const SizedBox(width: 12),
                    // 播报状态
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('正在感知：西南大学博物馆',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.textMain)),
                          SizedBox(height: 3),
                          Text('多语种 TTS 讲解就绪，点击播放',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primary)),
                        ],
                      ),
                    ),
                    // 播放按钮
                    GestureDetector(
                      onTap: () =>
                          HapticFeedback.mediumImpact(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GeoSwitch extends StatefulWidget {
  const _GeoSwitch();

  @override
  State<_GeoSwitch> createState() => _GeoSwitchState();
}

class _GeoSwitchState extends State<_GeoSwitch> {
  bool _on = true;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.85,
      child: Switch(
        value: _on,
        activeColor: AppTheme.primary,
        onChanged: (v) => setState(() => _on = v),
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
                    color: AppTheme.primary.withValues(alpha: 0.15)),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMain),
                maxLines: 1),
          ],
        ),
      ),
    );
  }
}