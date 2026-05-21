import 'package:flutter/material.dart';

class TacticalGridPainter extends CustomPainter {
  final bool isDarkMode;
  TacticalGridPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode
          ? const Color(0xFF00E5FF).withValues(alpha: 0.025)
          : const Color(0xFF007A8C).withValues(alpha: 0.035)
      ..strokeWidth = 1.0;

    const double step = 32.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
