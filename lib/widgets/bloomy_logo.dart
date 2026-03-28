import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BloomyLogo extends StatelessWidget {
  final double size;
  final bool showTagline;
  const BloomyLogo({super.key, this.size = 80, this.showTagline = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _PetalBPainter(),
        ),
        const SizedBox(height: 8),
        Text(
          'bloomy',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
            color: AppColors.deepPink,
            letterSpacing: 2,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'a safe space to be you',
            style: TextStyle(
              fontSize: size * 0.16,
              color: AppColors.textLight,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _PetalBPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.45;

    // Draw petals
    final petalColors = [
      AppColors.softPink,
      AppColors.lavender,
      AppColors.pink,
      AppColors.lavenderLight,
      AppColors.beige,
    ];

    for (int i = 0; i < 5; i++) {
      final angle = (i * 72 - 90) * 3.14159 / 180;
      final px = cx + r * 0.45 * 0.85 * _cos(angle);
      final py = cy + r * 0.45 * 0.85 * _sin(angle);
      final paint = Paint()..color = petalColors[i % petalColors.length];
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, py), width: r * 0.7, height: r * 0.5),
        paint,
      );
    }

    // Center circle
    final centerPaint = Paint()..color = AppColors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.38, centerPaint);

    // Draw "B"
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'B',
        style: TextStyle(
          fontSize: size.width * 0.38,
          fontWeight: FontWeight.w800,
          color: AppColors.deepPink,
          fontFamily: 'Georgia',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
    );
  }

  double _cos(double a) => a == 0 ? 1 : (a == 3.14159 ? -1 : (1 - a * a / 2 + a * a * a * a / 24 - a * a * a * a * a * a / 720));
  double _sin(double a) => a - a * a * a / 6 + a * a * a * a * a / 120 - a * a * a * a * a * a * a / 5040;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
