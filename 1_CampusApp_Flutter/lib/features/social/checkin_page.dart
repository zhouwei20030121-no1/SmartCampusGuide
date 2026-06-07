import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/network/network_client.dart';
import '../../core/theme/app_theme.dart';

class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key});

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  bool _loading = true;
  int _checkedCount = 0;
  int _totalSpotCount = 0;
  int _percent = 0;
  List<Map<String, dynamic>> _badges = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _loading = true);
    try {
      final res = await NetworkClient.dio.get('/checkin/progress/${NetworkClient.currentUserId}');
      if (res.data['code'] == 200) {
        final data = Map<String, dynamic>.from(res.data['data'] ?? {});
        setState(() {
          _checkedCount = _asInt(data['checkedCount']);
          _totalSpotCount = _asInt(data['totalSpotCount']);
          _percent = _asInt(data['percent']);
          _badges = _asMapList(data['badges']);
          _history = _asMapList(data['history']);
        });
      }
    } catch (e) {
      debugPrint('打卡记录加载失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return [];
    return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('打卡与徽章', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textMain),
      ),
      body: _CheckinBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadProgress,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
                    children: [
                      _buildProgressCard(),
                      const SizedBox(height: 20),
                      _buildBadgeSection(),
                      const SizedBox(height: 20),
                      _buildHistorySection(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return _GlassPanel(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.verified_rounded, color: AppTheme.success),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('校园探索进度', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppTheme.textMain)),
          ),
        ]),
        const SizedBox(height: 14),
        Text('已打卡 $_checkedCount / $_totalSpotCount 个景点', style: const TextStyle(color: AppTheme.textSub, fontSize: 14)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 11,
            value: _totalSpotCount == 0 ? 0 : (_percent / 100).clamp(0, 1).toDouble(),
            backgroundColor: Colors.white.withValues(alpha: 0.72),
            valueColor: const AlwaysStoppedAnimation(AppTheme.success),
          ),
        ),
        const SizedBox(height: 10),
        Text('完成度 $_percent%', style: const TextStyle(fontSize: 13, color: AppTheme.success, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _buildBadgeSection() {
    final virtualBadges = [
      _Badge('探索者', '首次打卡景点', Icons.explore_rounded, _checkedCount >= 1),
      _Badge('收藏家', '打卡 5 个景点', Icons.stars_rounded, _checkedCount >= 5),
      _Badge('校园通', '打卡全部景点', Icons.school_rounded, _totalSpotCount > 0 && _checkedCount >= _totalSpotCount),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(icon: Icons.workspace_premium_rounded, title: '我的徽章'),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.86,
        ),
        itemCount: virtualBadges.length,
        itemBuilder: (ctx, i) => _BadgeCard(badge: virtualBadges[i]),
      ),
      if (_badges.isNotEmpty) ...[
        const SizedBox(height: 12),
        _GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Text(
            '数据库已点亮徽章：${_badges.map((e) => e['badgeName']).where((e) => e != null).join('、')}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSub, height: 1.45),
          ),
        ),
      ],
    ]);
  }

  Widget _buildHistorySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(icon: Icons.history_rounded, title: '历史打卡记录'),
      const SizedBox(height: 12),
      if (_history.isEmpty)
        const _GlassPanel(
          child: Text(
            '还没有打卡记录。进入地图或智能讲解页，靠近景点后会自动打卡，也可以在讲解卡片里点“打卡”。',
            style: TextStyle(color: AppTheme.textSub, height: 1.6),
          ),
        )
      else
        ..._history.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HistoryTile(item: item),
            )),
    ]);
  }
}

class _Badge {
  final String name;
  final String desc;
  final IconData icon;
  final bool unlocked;

  _Badge(this.name, this.desc, this.icon, this.unlocked);
}

class _BadgeCard extends StatelessWidget {
  final _Badge badge;

  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final color = badge.unlocked ? AppTheme.warning : const Color(0xFF94A3B8);
    return _GlassPanel(
      padding: const EdgeInsets.all(12),
      opacity: badge.unlocked ? 0.68 : 0.46,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: badge.unlocked ? 0.16 : 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(badge.icon, size: 28, color: color),
        ),
        const SizedBox(height: 10),
        Text(
          badge.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w900, color: badge.unlocked ? AppTheme.textMain : const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 5),
        Text(
          badge.desc,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: AppTheme.textSub, height: 1.25),
        ),
      ]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: const Icon(Icons.location_on_rounded, color: AppTheme.success),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              (item['spotName'] ?? '未知景点').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textMain, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text((item['checkinTime'] ?? '刚刚').toString(), style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
          ]),
        ),
        if (item['badgeName'] != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Text(
              item['badgeName'].toString(),
              style: const TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 22, color: AppTheme.primary),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textMain)),
    ]);
  }
}

class _CheckinBackground extends StatelessWidget {
  final Widget child;

  const _CheckinBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: Image.asset(
          'assets/images/bg.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: AppTheme.pageBg),
        ),
      ),
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(color: const Color(0xFFE0F2FE).withValues(alpha: 0.48)),
        ),
      ),
      child,
    ]);
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double opacity;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.opacity = 0.64,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.84), width: 1.4),
            boxShadow: [
              BoxShadow(color: AppTheme.primary.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
