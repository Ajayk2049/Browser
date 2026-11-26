import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom vector icons for the Welcome/Onboarding flow matching Browser_UI_mockup.fig.
class DabAppLogoWidget extends StatelessWidget {
  final bool isDark;
  final double size;

  const DabAppLogoWidget({
    super.key,
    required this.isDark,
    this.size = 152,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF0B0D14) : Colors.white;
    final fgColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: fgColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.08),
      child: isDark
          ? ColorFiltered(
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              child: Image.asset('assets/images/splash_icon.png', fit: BoxFit.contain),
            )
          : Image.asset('assets/images/splash_icon.png', fit: BoxFit.contain),
    );
  }
}

/// Shield icon with "uO" monogram representing uBlock Origin.
class UBlockShieldIcon extends StatelessWidget {
  final double size;
  final Color shieldColor;
  final Color textColor;

  const UBlockShieldIcon({
    super.key,
    required this.size,
    required this.shieldColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ShieldPainter(color: shieldColor),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: size * 0.06),
            child: Text(
              'uO',
              style: TextStyle(
                color: textColor,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final Color color;
  const _ShieldPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.88, h * 0.22)
      ..lineTo(w * 0.88, h * 0.48)
      ..cubicTo(w * 0.88, h * 0.72, w * 0.66, h * 0.86, w * 0.5, h * 0.94)
      ..cubicTo(w * 0.34, h * 0.86, w * 0.12, h * 0.72, w * 0.12, h * 0.48)
      ..lineTo(w * 0.12, h * 0.22)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Concentric swirl icon representing direct torrent downloads.
class TorrentSwirlIcon extends StatelessWidget {
  final double size;
  final Color color;

  const TorrentSwirlIcon({
    super.key,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TorrentSwirlPainter(color: color)),
    );
  }
}

class _TorrentSwirlPainter extends CustomPainter {
  final Color color;
  const _TorrentSwirlPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, circlePaint);

    final cutPaint = Paint()
      ..color = color.computeLuminance() > 0.5
          ? const Color(0xFF1A2130)
          : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.64),
      math.pi * 0.15,
      math.pi * 1.45,
      false,
      cutPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.32),
      math.pi * 0.35,
      math.pi * 1.35,
      false,
      cutPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TorrentSwirlPainter oldDelegate) =>
      oldDelegate.color != color;
}
