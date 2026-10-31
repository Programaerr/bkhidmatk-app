import 'dart:math' as math;

import 'package:flutter/material.dart';

// تصميم المفتاح من Uiverse.io (r7chardgh)، وكل المقاسات بوحدة em كما في أصله.
const _frameColor = Color(0xFF373737);
const _panelColor = Color(0xFFF3F3F3);
const _sideColor = Color(0xFFCECECE);
const _underColor = Color(0xFF707070);
const _sunOnColor = Color(0xFF373737);
const _moonOnColor = Color(0xFF487BDB);
const _iconOffColor = Color(0xFFCECECE);

const _trackWidth = 5.0;
const _trackHeight = 2.5;
const _rim = .3;
const _corner = Radius.circular(.1);
const _panelWidth = 2.5;
const _panelHeight = 2.2;
const _panelCenterY = _trackHeight - _panelHeight / 2;

// تبعد اللوحة اليمنى في الأصل 1px عن طرف الإطار، وحجم خطه 17px.
const _rightPanelHinge = _trackWidth - 1 / 17 - _panelWidth;

const _tilt = 10 * math.pi / 180;
const _swing = 45 * math.pi / 180;

/// زر الليل والنهار: لوحتان تدوران حول مفصل في الوسط، والمفعّلة منهما مسطحة،
/// الشمس على اليسار والقمر على اليمين.
class DayNightSwitch extends StatelessWidget {
  const DayNightSwitch({super.key, required this.night});

  final bool night;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: night ? 1 : 0),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        curve: Curves.ease,
        builder: (context, progress, _) => CustomPaint(painter: _SwitchPainter(progress)),
      ),
    );
  }
}

class _SwitchPainter extends CustomPainter {
  _SwitchPainter(this.night);

  /// 0 نهار، و1 ليل.
  final double night;

  static final _moon = Path.combine(
    PathOperation.difference,
    Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: .62)),
    Path()..addOval(Rect.fromCircle(center: const Offset(.3, -.22), radius: .5)),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final em = size.width / (_trackWidth + _rim * 2);
    canvas
      ..save()
      ..translate(_rim * em, (size.height - (_trackHeight + _rim) * em) / 2)
      ..scale(em)
      ..drawRRect(
        RRect.fromLTRBR(-_rim, 0, _trackWidth + _rim, _trackHeight + _rim, _corner),
        Paint()..color = _frameColor,
      )
      ..clipRRect(RRect.fromLTRBR(0, 0, _trackWidth, _trackHeight, _corner));
    _panel(
      canvas,
      hinge: _trackWidth / 2,
      outward: -1,
      swing: _swing * night,
      icon: () => _paintSun(canvas, Color.lerp(_sunOnColor, _iconOffColor, night)!),
    );
    _panel(
      canvas,
      hinge: _rightPanelHinge,
      outward: 1,
      swing: _swing * (1 - night),
      icon: () => canvas.drawPath(
        _moon,
        Paint()..color = Color.lerp(_iconOffColor, _moonOnColor, night)!,
      ),
    );
    canvas.restore();
  }

  /// لوحة بوجه وجدارين يمتدان إلى الخلف، تدور حول مفصلها ثم تميل قليلاً،
  /// وتُرسم بإسقاط مستقيم بلا منظور كما في الأصل.
  void _panel(
    Canvas canvas, {
    required double hinge,
    required double outward,
    required double swing,
    required VoidCallback icon,
  }) {
    final yaw = -outward * swing;
    Offset point(double x, double y, double z) {
      final turnedX = x * math.cos(yaw) + z * math.sin(yaw);
      final turnedZ = -x * math.sin(yaw) + z * math.cos(yaw);
      return Offset(
        hinge + turnedX,
        _panelCenterY + y * math.cos(_tilt) - turnedZ * math.sin(_tilt),
      );
    }

    void face(List<Offset> corners, Color color) {
      canvas.drawPath(Path()..addPolygon(corners, true), Paint()..color = color);
    }

    final edge = outward * _panelWidth;
    const top = -_panelHeight / 2;
    const bottom = _panelHeight / 2;
    face(
      [
        point(edge, top, 0),
        point(edge, bottom, 0),
        point(edge, bottom, -_panelWidth),
        point(edge, top, -_panelWidth),
      ],
      _sideColor,
    );
    face(
      [
        point(0, bottom, 0),
        point(edge, bottom, 0),
        point(edge, bottom, -_panelHeight),
        point(0, bottom, -_panelHeight),
      ],
      _underColor,
    );
    face(
      [
        point(0, top, 0),
        point(edge, top, 0),
        point(edge, bottom, 0),
        point(0, bottom, 0),
      ],
      _panelColor,
    );

    // الأيقونة على وجه اللوحة، فتنضغط وتميل معه.
    final center = point(edge / 2, 0, 0);
    final xAxis = point(edge / 2 + 1, 0, 0) - center;
    final yAxis = point(edge / 2, 1, 0) - center;
    canvas
      ..save()
      ..transform(
        Matrix4(
          xAxis.dx, xAxis.dy, 0, 0,
          yAxis.dx, yAxis.dy, 0, 0,
          0, 0, 1, 0,
          center.dx, center.dy, 0, 1,
        ).storage,
      );
    icon();
    canvas.restore();
  }

  void _paintSun(Canvas canvas, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = .13
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset.zero, .36, paint);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(direction * .56, direction * .78, paint);
    }
  }

  @override
  bool shouldRepaint(_SwitchPainter oldDelegate) => oldDelegate.night != night;
}
