import 'dart:math' as math;

import 'package:flutter/material.dart';

const _dayTile = Colors.white;
const _nightTile = Color(0xFF2E3446);
const _sun = Color(0xFFF5A300);
const _moon = Color(0xFFFFE9A8);
const _cloud = Color(0xFFD5DCE6);
const _tightShadow = Color(0x36000000);
const _softShadow = Color(0x4A000000);

// النجوم في الوضع الليلي: (الموقع الأفقي، الموقع العمودي، نصف القطر).
const _stars = <(double, double, double)>[
  (9, 8.5, 1),
  (15.5, 18, .8),
  (22, 9.5, .7),
];

// الغيمة الصغيرة في الوضع النهاري: (الموقع الأفقي، الموقع العمودي، نصف القطر).
const _cloudPuffs = <(double, double, double)>[
  (34, 16, 2.8),
  (38.2, 13.6, 3.6),
  (42.6, 16, 2.8),
];

/// زر الليل والنهار: الشمس تنزلق إلى الطرف الآخر وتتحول هلالاً وتظهر النجوم.
class DayNightSwitch extends StatelessWidget {
  const DayNightSwitch({super.key, required this.night, required this.unit});

  /// 0 نهار، و1 ليل.
  final double night;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _SwitchPainter(night: night, unit: unit)),
    );
  }
}

class _SwitchPainter extends CustomPainter {
  _SwitchPainter({required this.night, required this.unit});

  final double night;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final tile = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(7 * unit));
    canvas
      ..drawRRect(
        tile.shift(Offset(0, 6 * unit)),
        Paint()
          ..color = _softShadow
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * unit),
      )
      ..drawRRect(
        tile.shift(Offset(0, 3 * unit)),
        Paint()
          ..color = _tightShadow
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * unit),
      )
      ..drawRRect(tile, Paint()..color = Color.lerp(_dayTile, _nightTile, night)!);

    final cloudFade = (1 - night * 2).clamp(0.0, 1.0);
    if (cloudFade > 0) {
      final paint = Paint()..color = _cloud.withValues(alpha: cloudFade);
      for (final (x, y, radius) in _cloudPuffs) {
        canvas.drawCircle(Offset(x, y) * unit, radius * unit, paint);
      }
    }

    final starFade = ((night - .5) * 2).clamp(0.0, 1.0);
    if (starFade > 0) {
      final paint = Paint()..color = Colors.white.withValues(alpha: starFade);
      for (final (x, y, radius) in _stars) {
        canvas.drawCircle(Offset(x, y) * unit, radius * unit, paint);
      }
    }

    final margin = 12 * unit;
    _sunOrMoon(
      canvas,
      Offset(margin + (size.width - margin * 2) * night, size.height / 2),
    );
  }

  void _sunOrMoon(Canvas canvas, Offset center) {
    final color = Color.lerp(_sun, _moon, night)!;
    final radius = (4.8 + 2.4 * night) * unit;

    final rayFade = (1 - night * 2).clamp(0.0, 1.0);
    if (rayFade > 0) {
      final ray = Paint()
        ..color = color.withValues(alpha: rayFade)
        ..strokeWidth = 1.3 * unit
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4 + night * math.pi / 2;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          center + direction * (radius + 1.9 * unit),
          center + direction * (radius + 3.3 * unit),
          ray,
        );
      }
    }

    // دائرة ثانية تقترب من القرص شيئاً فشيئاً فتقتطع منه الهلال.
    final disc = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: center + Offset(2.4 - 1.8 * night, -1.3 + 1 * night) * radius,
          radius: radius * .86,
        ),
      );
    canvas.drawPath(
      night > 0 ? Path.combine(PathOperation.difference, disc, bite) : disc,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SwitchPainter oldDelegate) =>
      oldDelegate.night != night || oldDelegate.unit != unit;
}
