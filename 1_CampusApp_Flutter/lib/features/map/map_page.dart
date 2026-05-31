import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  static const _pois = [
    _CampusPoi('含弘门（1号门）', '西南大学主校门，常用入校点', Icons.flag),
    _CampusPoi('学行门（2号门）', '天生路主入口，适合定位测试', Icons.flag_outlined),
    _CampusPoi('中心图书馆', '北区核心学习空间', Icons.local_library),
    _CampusPoi('南区图书馆', '南区学习服务点', Icons.menu_book),
    _CampusPoi('计算机与信息科学学院', '计科院 / 软件学院相关区域', Icons.computer),
    _CampusPoi('中心体育馆', '校内体育场馆', Icons.sports_basketball),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF7FF),
      appBar: AppBar(
        title: const Text('校园地图'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textMain,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          Container(
            height: 210,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFFB7E3F5), Color(0xFFEAF8EF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x15000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _CampusSketchPainter()),
                ),
                Positioned(
                  left: 18,
                  top: 16,
                  child: _MapBadge(
                    icon: Icons.map_rounded,
                    label: '模拟器临时地图',
                  ),
                ),
                const Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Text(
                    '已临时停用高德原生插件，便于 iPhone 模拟器构建与测试。真机/安卓可恢复原地图模块。',
                    style: TextStyle(
                      color: AppTheme.textSub,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '校园地点',
            style: TextStyle(
              color: AppTheme.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (final poi in _pois) ...[
            _PoiTile(poi: poi),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PoiTile extends StatelessWidget {
  const _PoiTile({required this.poi});

  final _CampusPoi poi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(poi.icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poi.name,
                  style: const TextStyle(
                    color: AppTheme.textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  poi.description,
                  style: const TextStyle(
                    color: AppTheme.textSub,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMain,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampusSketchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final lakePaint = Paint()
      ..color = const Color(0xFF79C6E8).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    final lawnPaint = Paint()
      ..color = const Color(0xFF75C889).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    final pinPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.56, size.height * 0.16, 86, 58),
      lakePaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.08, size.height * 0.42, 110, 70),
      lawnPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.76),
      Offset(size.width * 0.86, size.height * 0.26),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.20, size.height * 0.22),
      Offset(size.width * 0.82, size.height * 0.72),
      roadPaint,
    );

    for (final point in [
      Offset(size.width * 0.25, size.height * 0.62),
      Offset(size.width * 0.48, size.height * 0.46),
      Offset(size.width * 0.68, size.height * 0.32),
      Offset(size.width * 0.72, size.height * 0.66),
    ]) {
      canvas.drawCircle(point, 7, pinPaint);
      canvas.drawCircle(point, 13, pinPaint..color = AppTheme.primary.withValues(alpha: 0.15));
      pinPaint.color = AppTheme.primary;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CampusPoi {
  const _CampusPoi(this.name, this.description, this.icon);

  final String name;
  final String description;
  final IconData icon;
}
