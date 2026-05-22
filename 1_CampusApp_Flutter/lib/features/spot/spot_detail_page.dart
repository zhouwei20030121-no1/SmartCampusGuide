import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SpotDetailPage extends StatelessWidget {
  final int spotId;

  const SpotDetailPage({super.key, required this.spotId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('景点详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TODO: 高清图片轮播（贾丝楠）
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.lightBlue.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.image, size: 48, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            // TODO: 文字介绍排版（贾丝楠）
            const Text('景点名称', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('景点详细介绍文字...', style: TextStyle(color: AppTheme.textSub)),
            const SizedBox(height: 16),
            // TODO: 视频播放器组件（贾丝楠）
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.play_circle, size: 48, color: AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
