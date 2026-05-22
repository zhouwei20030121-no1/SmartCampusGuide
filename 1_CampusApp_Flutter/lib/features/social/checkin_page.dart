import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key});

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  final _badges = [
    _Badge('探索者', '首次打卡景点', Icons.explore, false),
    _Badge('收藏家', '打卡5个景点', Icons.stars, false),
    _Badge('校园通', '打卡全部景点', Icons.school, true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('打卡 & 徽章')),
      body: Column(
        children: [
          const SizedBox(height: 24),
          const Text('我的徽章',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // TODO: 打卡点亮徽章特效（周玮）
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, childAspectRatio: 0.85),
              itemCount: _badges.length,
              itemBuilder: (ctx, i) => _BadgeCard(badge: _badges[i]),
            ),
          ),
        ],
      ),
    );
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
    return Card(
      elevation: badge.unlocked ? 3 : 0,
      color: badge.unlocked ? Colors.white : Colors.grey[200],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Icon(badge.icon,
              size: 36,
              color: badge.unlocked ? AppTheme.warning : Colors.grey),
          const SizedBox(height: 8),
          Text(badge.name,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: badge.unlocked ? AppTheme.textMain : Colors.grey)),
          Text(badge.desc, style: const TextStyle(fontSize: 10, color: AppTheme.textSub)),
        ],
      ),
    );
  }
}
