import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class RoutePage extends StatefulWidget {
  const RoutePage({super.key});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('智能路线规划')),
      body: Stack(
        children: [
          // TODO: 在地图上画出最优导航路线轨迹线（周玮）
          Container(color: AppTheme.pageBg),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route, size: 64, color: AppTheme.primary),
                SizedBox(height: 16),
                Text('路线规划 & 导航轨迹',
                    style: TextStyle(color: AppTheme.textSub, fontSize: 16)),
                SizedBox(height: 8),
                Text('寻路算法 + 地图轨迹绘制 - 待实现（周玮）',
                    style: TextStyle(color: AppTheme.textSub, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
