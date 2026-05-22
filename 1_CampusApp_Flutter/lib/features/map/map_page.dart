import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // TODO: 集成高德地图 Flutter SDK（李卓尔）
          Container(color: AppTheme.pageBg),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map, size: 64, color: AppTheme.primary),
                SizedBox(height: 16),
                Text('地图展示 & 实时定位',
                    style: TextStyle(fontSize: 18, color: AppTheme.textSub)),
                SizedBox(height: 8),
                Text('高德地图 SDK 待集成（李卓尔）',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSub)),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FloatingActionButton.small(
                  heroTag: 'profile',
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/profile'),
                  child: const Icon(Icons.person),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
