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
      appBar: AppBar(title: const Text('打卡与徽章')),
      body: RefreshIndicator(
        onRefresh: _loadProgress,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _buildProgressCard(),
                  const SizedBox(height: 16),
                  _buildBadgeSection(),
                  const SizedBox(height: 16),
                  _buildHistorySection(),
                ],
              ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('校园探索进度', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        const SizedBox(height: 8),
        Text('已打卡 $_checkedCount / $_totalSpotCount 个景点', style: const TextStyle(color: AppTheme.textSub)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: _totalSpotCount == 0 ? 0 : (_percent / 100).clamp(0, 1).toDouble(),
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation(AppTheme.success),
          ),
        ),
        const SizedBox(height: 8),
        Text('完成度 $_percent%', style: const TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildBadgeSection() {
    final virtualBadges = [
      _Badge('探索者', '首次打卡景点', Icons.explore, _checkedCount >= 1),
      _Badge('收藏家', '打卡 5 个景点', Icons.stars, _checkedCount >= 5),
      _Badge('校园通', '打卡全部景点', Icons.school, _totalSpotCount > 0 && _checkedCount >= _totalSpotCount),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('我的徽章', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.9,
        ),
        itemCount: virtualBadges.length,
        itemBuilder: (ctx, i) => _BadgeCard(badge: virtualBadges[i]),
      ),
      if (_badges.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('数据库已点亮徽章：${_badges.map((e) => e['badgeName']).where((e) => e != null).join('、')}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
        ),
    ]);
  }

  Widget _buildHistorySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('历史打卡记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
      const SizedBox(height: 10),
      if (_history.isEmpty)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: const Text('还没有打卡记录。进入地图或智能讲解页，靠近景点后会自动打卡，也可以在讲解卡片里点“打卡”。',
              style: TextStyle(color: AppTheme.textSub, height: 1.5)),
        )
      else
        ..._history.map((item) => _HistoryTile(item: item)),
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: badge.unlocked ? Colors.white : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badge.unlocked ? AppTheme.warning.withValues(alpha: 0.35) : Colors.transparent),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(badge.icon, size: 34, color: badge.unlocked ? AppTheme.warning : Colors.grey),
        const SizedBox(height: 8),
        Text(badge.name,
            style: TextStyle(fontWeight: FontWeight.bold, color: badge.unlocked ? AppTheme.textMain : Colors.grey)),
        const SizedBox(height: 4),
        Text(badge.desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppTheme.textSub)),
      ]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: const Icon(Icons.location_on_rounded, color: AppTheme.success),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((item['spotName'] ?? '未知景点').toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            const SizedBox(height: 3),
            Text((item['checkinTime'] ?? '刚刚').toString(), style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
          ]),
        ),
        if (item['badgeName'] != null)
          Text(item['badgeName'].toString(), style: const TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
