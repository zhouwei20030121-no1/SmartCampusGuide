import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ARPage extends StatefulWidget {
  const ARPage({super.key});

  @override
  State<ARPage> createState() => _ARPageState();
}

class _ARPageState extends State<ARPage> with WidgetsBindingObserver {
  final _spots = const [
    _ARSpot(
      name: '西南大学南门',
      confidence: 0.92,
      intro: '校园重要入口，适合作为访客和新生导览的起点。',
      routeHint: '可从这里串联光华楼、图书馆、博物馆等地点。',
    ),
    _ARSpot(
      name: '图书馆',
      confidence: 0.88,
      intro: '校园核心学习空间，可用于自习、借阅和资料查询。',
      routeHint: '到馆前建议关注开放时间、座位情况与步行路线。',
    ),
    _ARSpot(
      name: '光华楼',
      confidence: 0.86,
      intro: '具有代表性的校园地标，适合校史文化讲解。',
      routeHint: '可作为历史文化路线的重要节点。',
    ),
  ];

  Timer? _scanTimer;
  int _activeIndex = 0;
  bool _scanning = false;

  _ARSpot get _activeSpot => _spots[_activeIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startScan() {
    _scanTimer?.cancel();
    setState(() => _scanning = true);
    _scanTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _activeIndex = (_activeIndex + 1) % _spots.length;
        _scanning = false;
      });
    });
  }

  void _askGuide() {
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {'prompt': '我现在通过 AR 识别到了${_activeSpot.name}，请给我讲解一下。'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('AR 识别讲解'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/shouye.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _ScanFramePainter())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 90, 18, 18),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Align(
                          alignment: const Alignment(0, -0.2),
                          child: _ARLabel(
                            spot: _activeSpot,
                            scanning: _scanning,
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _RecognitionPanel(
                            spots: _spots,
                            activeIndex: _activeIndex,
                            scanning: _scanning,
                            onSelected: (index) =>
                                setState(() => _activeIndex = index),
                            onScan: _startScan,
                            onAskGuide: _askGuide,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecognitionPanel extends StatelessWidget {
  final List<_ARSpot> spots;
  final int activeIndex;
  final bool scanning;
  final ValueChanged<int> onSelected;
  final VoidCallback onScan;
  final VoidCallback onAskGuide;

  const _RecognitionPanel({
    required this.spots,
    required this.activeIndex,
    required this.scanning,
    required this.onSelected,
    required this.onScan,
    required this.onAskGuide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                scanning ? Icons.radar : Icons.view_in_ar,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  scanning ? '正在分析视频画面...' : '已识别：${spots[activeIndex].name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            spots[activeIndex].intro,
            style: const TextStyle(color: AppTheme.textSub, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < spots.length; i++)
                ChoiceChip(
                  label: Text(spots[i].name),
                  selected: i == activeIndex,
                  onSelected: (_) => onSelected(i),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: scanning ? null : onScan,
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('开始识别'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: scanning ? null : onAskGuide,
                  icon: const Icon(Icons.record_voice_over),
                  label: const Text('AI 讲解'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ARLabel extends StatelessWidget {
  final _ARSpot spot;
  final bool scanning;

  const _ARLabel({required this.spot, required this.scanning});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: scanning ? 0.45 : 1,
      duration: const Duration(milliseconds: 180),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xE61E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    spot.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                Text(
                  '${(spot.confidence * 100).round()}%',
                  style: const TextStyle(color: Color(0xFF93C5FD)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              spot.routeHint,
              style: const TextStyle(color: Color(0xFFE2E8F0), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.38),
      width: size.width * 0.76,
      height: size.width * 0.52,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(22)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ARSpot {
  final String name;
  final double confidence;
  final String intro;
  final String routeHint;

  const _ARSpot({
    required this.name,
    required this.confidence,
    required this.intro,
    required this.routeHint,
  });
}
