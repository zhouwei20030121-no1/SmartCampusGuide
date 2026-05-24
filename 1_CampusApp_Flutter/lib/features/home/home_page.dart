import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;
  static const _tabLabels = ['首页', '我的行程', '智能语音', 'AR导览'];
  static const _tabIcons = [Icons.home_rounded, Icons.map_rounded, Icons.mic_rounded, Icons.view_in_ar_rounded];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            _buildBackground(),
            _buildHeader(),
            _buildContent(),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ─── 背景层：图片 + 双层模糊蒙版 ───
  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/images/bg.jpg', fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x72E0F2FE),
                      Color(0x4DBAE6FD),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── 顶部标题 ───
  Widget _buildHeader() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 40,
      left: 30,
      right: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SWU Guide',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkBlue,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('Smart Campus Guide',
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkBlue.withValues(alpha: 0.6),
                  letterSpacing: 3)),
        ],
      ),
    );
  }

  // ─── 中间内容区（根据标签切换） ──
  Widget _buildContent() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 160,
      left: 0,
      right: 0,
      bottom: 130,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key: ValueKey(_currentTab),
          child: _buildTabContent(),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _TabHome();
      case 1:
        return _TabTrip();
      case 2:
        return _TabVoice();
      case 3:
        return _TabAR();
      default:
        return _TabHome();
    }
  }

  // ─── 底部毛玻璃导航栏 ───
  Widget _buildBottomNav() {
    return Positioned(
      bottom: 30,
      left: 30,
      right: 30,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(4, (i) {
                final active = _currentTab == i;
                return GestureDetector(
                  onTap: () {
                    setState(() => _currentTab = i);
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_tabIcons[i],
                            size: 26,
                            color: active
                                ? AppTheme.primary
                                : AppTheme.textSub.withValues(alpha: 0.6)),
                        const SizedBox(height: 4),
                        Text(_tabLabels[i],
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    active ? FontWeight.w700 : FontWeight.w500,
                                color: active
                                    ? AppTheme.primary
                                    : AppTheme.textSub.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  标签页 0：首页
// ══════════════════════════════════════════════
class _TabHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('欢迎来到西南大学',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('晴 26℃ | 校园空气质量：优',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSub)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('热门景点推荐',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkBlue)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ['樟树林', '三号运动场', '东方红广场']
                      .map((s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(s,
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text('点击下方导航标签，开启全方位智慧校园探索体验。',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.darkBlue.withValues(alpha: 0.8),
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  标签页 1：我的行程
// ══════════════════════════════════════════════
class _TabTrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('今日游览路线',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkBlue)),
            const SizedBox(height: 20),
            _timeline('09:30', '校门出发 → 乘校车前往物理学院'),
            _timeline('11:00', '中心图书馆 → 借阅学术期刊'),
            _timeline('14:30', '东方红广场 → 参加校园文化节'),
          ],
        ),
      ),
    );
  }

  Widget _timeline(String time, String info) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(time,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    fontSize: 15)),
          ),
          Expanded(
              child: Text(info,
                  style: const TextStyle(
                      color: AppTheme.textMain, fontSize: 15))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  标签页 2：智能语音
// ══════════════════════════════════════════════
class _TabVoice extends StatefulWidget {
  @override
  State<_TabVoice> createState() => _TabVoiceState();
}

class _TabVoiceState extends State<_TabVoice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: _GlassCard(
        child: Column(
          children: [
            const Text('西小导 智能播报',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkBlue)),
            const SizedBox(height: 24),
            // 音频波形动画
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [0, 0.2, 0.4, 0.1].map((delay) {
                    final h = 20 +
                        (_ctrl.value *
                            (40 + delay * 40) *
                            (1 - delay).clamp(0.3, 1.0));
                    return Container(
                      width: 5,
                      height: h,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            Text('正在实时检索知识库，准备为您播报当前建筑历史...',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.darkBlue.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  标签页 3：AR导览
// ══════════════════════════════════════════════
class _TabAR extends StatefulWidget {
  @override
  State<_TabAR> createState() => _TabARState();
}

class _TabARState extends State<_TabAR>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanCtrl;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: _GlassCard(
        child: Column(
          children: [
            const Text('AR 实景透视模式',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkBlue)),
            const SizedBox(height: 24),
            // AR 扫描线
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.darkBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AnimatedBuilder(
                  animation: _scanCtrl,
                  builder: (_, child) {
                    return CustomPaint(
                      painter: _ScanLinePainter(_scanCtrl.value),
                      size: const Size(double.infinity, 100),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('请将摄像头对准校园建筑物以识别故事。',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.darkBlue.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.primary.withValues(alpha: 0),
          AppTheme.primary.withValues(alpha: 0.6),
          AppTheme.primary.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final y = progress * size.height;
    canvas.drawRect(
        Rect.fromLTWH(0, y - 1, size.width, 2), paint);
    canvas.drawRect(
        Rect.fromLTWH(0, y - 8, size.width, 16),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primary.withValues(alpha: 0),
              AppTheme.primary.withValues(alpha: 0.15),
              AppTheme.primary.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, y - 8, size.width, 16)));
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) =>
      old.progress != progress;
}

// ══════════════════════════════════════════════
//  共享毛玻璃卡片
// ══════════════════════════════════════════════
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.38),
            border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
