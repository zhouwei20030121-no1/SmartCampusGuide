import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

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
          _buildBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopHeader(),
                Expanded(child: _buildBodyContent()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── 背景层 ───
  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: AppTheme.pageBg),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: const Color(0xFFE0F2FE).withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }

  // ─── 顶部：校徽 + 搜索框 ───
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 左侧校徽
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8),
              ],
            ),
            child: const Center(
              child: Text('西大',
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          // 搜索框
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.8)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search,
                      color: Colors.black54.withValues(alpha: 0.7),
                      size: 20),
                  const SizedBox(width: 8),
                  Text('搜索校园景点、服务...',
                      style: TextStyle(
                          color: Colors.black54.withValues(alpha: 0.7),
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 主体内容 ───
  Widget _buildBodyContent() {
    if (_currentIndex != 0) {
      return Center(
        child: Text('正在开发中...',
            style: TextStyle(
                fontSize: 18,
                color: AppTheme.darkBlue.withValues(alpha: 0.6))),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(
          left: 16, right: 16, top: 10, bottom: 120),
      children: [
        // Banner
        _buildBanner(),
        const SizedBox(height: 24),
        // 金刚区
        _buildGridNav(),
        const SizedBox(height: 24),
        // 热门推荐
        _buildHotSpots(),
      ],
    );
  }

  // ─── Banner 轮播占位 ───
  Widget _buildBanner() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.85),
            AppTheme.lightBlue.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: const Center(
        child: Text('西大风光 Banner',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── 金刚区（小程序风格宫格导航） ──
  Widget _buildGridNav() {
    final items = [
      (_GridItem(Icons.map_outlined, '校园地图')),
      (_GridItem(Icons.camera_alt_outlined, '景点打卡')),
      (_GridItem(Icons.directions_bus_outlined, '校车时刻')),
      (_GridItem(Icons.restaurant_outlined, '食堂服务')),
      (_GridItem(Icons.menu_book_outlined, '图书馆')),
      (_GridItem(Icons.event_outlined, '校园活动')),
      (_GridItem(Icons.support_agent_outlined, '智能导览')),
      (_GridItem(Icons.qr_code_scanner_outlined, 'AR扫一扫')),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 24,
        alignment: WrapAlignment.spaceAround,
        children: items.map((item) => _buildGridButton(item)).toList(),
      ),
    );
  }

  Widget _buildGridButton(_GridItem item) {
    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(height: 8),
            Text(item.label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textMain)),
          ],
        ),
      ),
    );
  }

  // ─── 热门推荐 ───
  Widget _buildHotSpots() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📍 热门推荐',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain)),
          const SizedBox(height: 16),
          _buildSpotTile('樟树林', '漫步天然氧吧，感受百年学府底蕴'),
          _buildSpotTile('三号运动场', '挥洒汗水，体验活力校园风情'),
          _buildSpotTile('东方红广场', '学校核心地标，伟人雕像前打卡'),
        ],
      ),
    );
  }

  Widget _buildSpotTile(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.lightBlue.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.landscape, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textMain)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSub),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 底部导航栏（吸底 + 加白） ───
  Widget _buildBottomNav() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: Colors.white.withValues(alpha: 0.92),
          child: SafeArea(
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: Colors.black45,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded), label: '首页'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.map_rounded), label: '我的行程'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.record_voice_over), label: '智能语音'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.view_in_ar), label: 'AR导览'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridItem {
  final IconData icon;
  final String label;
  const _GridItem(this.icon, this.label);
}
