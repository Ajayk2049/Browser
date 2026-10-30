import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/search_engine.dart';

/// Crisp native vector logo renderers for Google and DuckDuckGo.
/// Complies with rules.md §13, §25.1, §25.2, and §29.2 (< 200 lines).
class SearchEngineIcon extends StatelessWidget {
  final SearchEngine engine;
  final double size;

  const SearchEngineIcon({
    super.key,
    required this.engine,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: engine == SearchEngine.google
            ? const _GoogleLogoPainter()
            : const _DuckDuckGoLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.38;
    final strokeWidth = size.width * 0.22;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // 1. Red (top arc)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi * 0.75, math.pi * 0.5, false, paint);

    // 2. Yellow (bottom-left arc)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 0.5, false, paint);

    // 3. Green (bottom arc)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, math.pi * 0.25, math.pi * 0.5, false, paint);

    // 4. Blue (right arc)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi * 0.25, math.pi * 0.5, false, paint);

    // 5. Blue horizontal crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = Rect.fromLTWH(
      cx - strokeWidth * 0.1,
      cy - strokeWidth / 2,
      radius + strokeWidth * 0.5,
      strokeWidth,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DuckDuckGoLogoPainter extends CustomPainter {
  const _DuckDuckGoLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // 1. Orange background circle
    final bgPaint = Paint()
      ..color = const Color(0xFFDE5833)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    // 2. White duck head & neck silhouette
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Head
    final headCenter = Offset(cx + r * 0.04, cy - r * 0.12);
    canvas.drawCircle(headCenter, r * 0.44, whitePaint);

    // Neck/Body base
    final neckPath = Path()
      ..moveTo(cx - r * 0.32, cy)
      ..quadraticBezierTo(cx - r * 0.35, cy + r * 0.6, cx, cy + r * 0.65)
      ..quadraticBezierTo(cx + r * 0.4, cy + r * 0.6, cx + r * 0.42, cy)
      ..close();
    canvas.drawPath(neckPath, whitePaint);

    // 3. Orange beak
    final beakPaint = Paint()
      ..color = const Color(0xFFF19E38)
      ..style = PaintingStyle.fill;
    final beakPath = Path()
      ..moveTo(cx - r * 0.28, cy - r * 0.22)
      ..lineTo(cx - r * 0.72, cy - r * 0.08)
      ..lineTo(cx - r * 0.24, cy + r * 0.06)
      ..close();
    canvas.drawPath(beakPath, beakPaint);

    // 4. Eye
    final eyePaint = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - r * 0.08, cy - r * 0.22), r * 0.08, eyePaint);

    // 5. Green bow tie
    final bowPaint = Paint()
      ..color = const Color(0xFF5B9E4D)
      ..style = PaintingStyle.fill;
    final bowPath = Path()
      // Left wing of bow
      ..moveTo(cx, cy + r * 0.42)
      ..lineTo(cx - r * 0.26, cy + r * 0.3)
      ..lineTo(cx - r * 0.24, cy + r * 0.54)
      ..close()
      // Right wing of bow
      ..moveTo(cx, cy + r * 0.42)
      ..lineTo(cx + r * 0.26, cy + r * 0.3)
      ..lineTo(cx + r * 0.24, cy + r * 0.54)
      ..close();
    canvas.drawPath(bowPath, bowPaint);
    canvas.drawCircle(Offset(cx, cy + r * 0.42), r * 0.07, bowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

