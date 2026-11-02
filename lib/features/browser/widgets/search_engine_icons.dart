import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/search_engine.dart';

/// Crisp native vector and glyph logo renderers for search engines.
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
    if (engine == SearchEngine.google) {
      return SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(painter: _GoogleLogoPainter()),
      );
    }
    if (engine == SearchEngine.duckDuckGo) {
      return SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(painter: _DuckDuckGoLogoPainter()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    String letter = 'D';
    Color bgColor = const Color(0xFF0080FF);
    if (engine == SearchEngine.bing) {
      letter = 'B';
      bgColor = const Color(0xFF008373);
    } else if (engine == SearchEngine.brave) {
      letter = '▲';
      bgColor = const Color(0xFFFF5500);
    } else if (engine == SearchEngine.startpage) {
      letter = 'S';
      bgColor = const Color(0xFF4353FF);
    } else if (engine == SearchEngine.custom) {
      letter = '+';
      bgColor = isDark ? const Color(0xFF334155) : const Color(0xFF64748B);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.55,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
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

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi * 0.75, math.pi * 0.5, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 0.5, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, math.pi * 0.25, math.pi * 0.5, false, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi * 0.25, math.pi * 0.5, false, paint);

    final barPaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    final barRect = Rect.fromLTWH(cx - strokeWidth * 0.1, cy - strokeWidth / 2, radius + strokeWidth * 0.5, strokeWidth);
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

    final bgPaint = Paint()..color = const Color(0xFFDE5833)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    final whitePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final headCenter = Offset(cx + r * 0.04, cy - r * 0.12);
    canvas.drawCircle(headCenter, r * 0.44, whitePaint);

    final neckPath = Path()
      ..moveTo(cx - r * 0.32, cy)
      ..quadraticBezierTo(cx - r * 0.35, cy + r * 0.6, cx, cy + r * 0.65)
      ..quadraticBezierTo(cx + r * 0.4, cy + r * 0.6, cx + r * 0.42, cy)
      ..close();
    canvas.drawPath(neckPath, whitePaint);

    final beakPaint = Paint()..color = const Color(0xFFF19E38)..style = PaintingStyle.fill;
    final beakPath = Path()
      ..moveTo(cx - r * 0.28, cy - r * 0.22)
      ..lineTo(cx - r * 0.72, cy - r * 0.08)
      ..lineTo(cx - r * 0.24, cy + r * 0.06)
      ..close();
    canvas.drawPath(beakPath, beakPaint);

    final eyePaint = Paint()..color = const Color(0xFF222222)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - r * 0.08, cy - r * 0.22), r * 0.08, eyePaint);

    final bowPaint = Paint()..color = const Color(0xFF5B9E4D)..style = PaintingStyle.fill;
    final bowPath = Path()
      ..moveTo(cx, cy + r * 0.42)
      ..lineTo(cx - r * 0.26, cy + r * 0.3)
      ..lineTo(cx - r * 0.24, cy + r * 0.54)
      ..close()
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
