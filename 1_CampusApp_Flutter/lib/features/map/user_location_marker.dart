import 'dart:math' as math;

import 'package:flutter/material.dart';

class UserLocationMarker extends StatelessWidget {
  final double headingDegrees;
  final bool showHeading;
  final double size;

  const UserLocationMarker({
    super.key,
    required this.headingDegrees,
    required this.showHeading,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue.shade600;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showHeading)
            Transform.rotate(
              angle: headingDegrees * math.pi / 180,
              child: CustomPaint(
                size: Size(size, size),
                painter: _HeadingPainter(color: blue),
              ),
            ),
          Container(
            width: size * 0.48,
            height: size * 0.48,
            decoration: BoxDecoration(
              color: blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), blurRadius: 8),
              ],
            ),
            child: Center(
              child: Container(
                width: size * 0.16,
                height: size * 0.16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadingPainter extends CustomPainter {
  final Color color;

  const _HeadingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, size.height * 0.04)
      ..lineTo(center.dx - size.width * 0.22, center.dy + size.height * 0.08)
      ..quadraticBezierTo(
        center.dx,
        center.dy + size.height * 0.18,
        center.dx + size.width * 0.22,
        center.dy + size.height * 0.08,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.28));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(covariant _HeadingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
