import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// حركة أيقونة التبويب في الشريط الزجاجي حين يُختار وحين يُترك (طلب المستخدم، بدل البوابة
/// الزمنية). كل حركة تحكي ما في التبويب، والفقاعة نفسها تظهر فوراً.
enum NavMotion {
  /// أيقونة ثابتة.
  none,

  /// بيت ينفتح بابه حين يُختار، فيظهر ضوء الداخل، وينسد حين يُترك.
  door,

  /// مطرقة ترفع ثم تضرب الأرض، فتنضغط الفقاعة وتنداح حولها موجة وشرر.
  strike,

  /// تقويم يطلع عليه قلم يكتب سطراً، ويختفي القلم وما كتب حين يُترك.
  write,

  /// تشغيل يصير إيقافاً (الفيديو يشتغل) من ملف Lottie الذي أرسله المستخدم، ويرجع حين يُترك.
  playPause,

  /// الشخصية تتبدل داخل الدائرة كما في اختيار الشخصية في الألعاب.
  swap,
}

/// أيقونة تبويب متحركة بحجم الأيقونة العادية ولونها.
class NavMotionIcon extends StatefulWidget {
  const NavMotionIcon({
    super.key,
    required this.motion,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.color,
    required this.size,
    this.onImpact,
  });

  final NavMotion motion;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final Color color;
  final double size;

  /// لحظة ضربة المطرقة على الأرض.
  final VoidCallback? onImpact;

  @override
  State<NavMotionIcon> createState() => _NavMotionIconState();
}

class _NavMotionIconState extends State<NavMotionIcon>
    with SingleTickerProviderStateMixin {
  // نهاية التشغيل إلى الإيقاف، وبداية الرجوع منه، في ملف Lottie (180 إطاراً).
  static const _paused = 75 / 180;
  static const _backFromPause = 105 / 180;

  // يتجاوز الواحد قليلاً، لارتداد الباب حين ينفتح.
  late final _motion = AnimationController(
    vsync: this,
    lowerBound: -.2,
    upperBound: 1.2,
  );

  /// القلم يغادر: يخفت هو وما كتب، بلا رجوع في الكتابة.
  bool _leaving = false;
  bool _struck = false;

  @override
  void initState() {
    super.initState();
    _motion.value = _rest(widget.selected);
    _motion.addListener(_watchStrike);
  }

  double _rest(bool selected) => switch (widget.motion) {
        NavMotion.playPause => selected ? _paused : 0,
        NavMotion.door || NavMotion.write => selected ? 1 : 0,
        // المطرقة والشخصية تبدآن وتنتهيان بالشكل نفسه.
        _ => 1,
      };

  void _watchStrike() {
    if (widget.motion != NavMotion.strike || _struck || !widget.selected) return;
    if (_motion.isAnimating && _motion.value >= _Strike.impact) {
      _struck = true;
      widget.onImpact?.call();
    }
  }

  @override
  void didUpdateWidget(NavMotionIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    final selected = widget.selected;
    // من أطفأ الحركة في إعدادات الهاتف يرى الحال الأخيرة فوراً.
    if (MediaQuery.disableAnimationsOf(context)) {
      _leaving = false;
      _motion.value = _rest(selected);
      return;
    }
    switch (widget.motion) {
      case NavMotion.none:
        break;
      case NavMotion.door:
        selected
            ? _motion.animateTo(1,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack)
            : _motion.animateTo(0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInCubic);
      case NavMotion.strike:
        if (selected) {
          _struck = false;
          _motion.value = 0;
          _motion.animateTo(1, duration: const Duration(milliseconds: 600));
        } else {
          _motion.value = 1;
        }
      case NavMotion.write:
        if (selected) {
          _leaving = false;
          _motion.value = 0;
          _motion.animateTo(1, duration: const Duration(milliseconds: 680));
        } else {
          _leaving = true;
          _motion.animateTo(0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeIn);
        }
      case NavMotion.playPause:
        if (selected) {
          if (_motion.value >= _backFromPause - .001) _motion.value = 0;
          _motion.animateTo(_paused, duration: const Duration(milliseconds: 620));
        } else if (_motion.value >= _paused - .01) {
          _motion.value = _backFromPause;
          _motion
              .animateTo(1, duration: const Duration(milliseconds: 500))
              .whenCompleteOrCancel(() {
            // آخر إطار هو الأول نفسه، فيبدأ التشغيل التالي من أوله.
            if (mounted && !widget.selected && _motion.value >= 1) {
              _motion.value = 0;
            }
          });
        } else {
          _motion.animateTo(0, duration: const Duration(milliseconds: 200));
        }
      case NavMotion.swap:
        if (selected) {
          _motion.value = 0;
          _motion.animateTo(1,
              duration: const Duration(milliseconds: 520));
        } else {
          _motion.value = 1;
        }
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final selected = widget.selected;
    final color = widget.color;
    final night = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: size,
      child: switch (widget.motion) {
        NavMotion.none => Icon(selected ? widget.activeIcon : widget.icon,
            size: size, color: color),
        NavMotion.door => CustomPaint(
            painter: _DoorPainter(
              open: _motion,
              filled: selected,
              color: color,
              night: night,
            ),
          ),
        NavMotion.strike => AnimatedBuilder(
            animation: _motion,
            builder: (context, hammer) => Transform.rotate(
              angle: _Strike.angle(_motion.value),
              // رأسها أعلى اليمين: تدور حول طرف المقبض أسفل الأيقونة يساراً.
              alignment: const Alignment(-.68, .68),
              child: hammer,
            ),
            child: Icon(selected ? widget.activeIcon : widget.icon,
                size: size, color: color),
          ),
        NavMotion.write => CustomPaint(
            foregroundPainter: _PenPainter(
              write: _motion,
              leaving: _leaving,
              night: night,
            ),
            child: Icon(selected ? widget.activeIcon : widget.icon,
                size: size, color: color),
          ),
        NavMotion.playPause => Center(
            child: Lottie.asset(
              'assets/lottie/play_pause.json',
              controller: _motion,
              width: size * .9,
              height: size * .9,
              delegates: LottieDelegates(values: [
                ValueDelegate.color(const ['**'], value: color),
                ValueDelegate.strokeColor(const ['**'], value: color),
              ]),
            ),
          ),
        NavMotion.swap => CustomPaint(
            painter: _SwapPainter(
              swap: _motion,
              filled: selected,
              color: color,
            ),
          ),
      },
    );
  }
}

double _smooth(double x) {
  final v = x.clamp(0.0, 1.0);
  return v * v * (3 - 2 * v);
}

/// زاوية المطرقة: ترفع قليلاً، ثم تهوي بسرعة إلى الأرض يميناً، ثم ترتد وتهتز حتى تسكن.
abstract final class _Strike {
  static const lift = .28;
  static const impact = .42;
  static const raised = -.35;
  static const down = .62;

  static double angle(double t) {
    if (t <= 0 || t >= 1) return 0;
    if (t < lift) return raised * Curves.easeOutCubic.transform(t / lift);
    if (t < impact) {
      final fall = Curves.easeInCubic.transform((t - lift) / (impact - lift));
      return lerpDouble(raised, down, fall)!;
    }
    final settle = (t - impact) / (1 - impact);
    return down *
        math.exp(-4.5 * settle) *
        math.cos(2.6 * math.pi * settle) *
        (1 - settle);
  }
}

/// بيت بشكل رموز آبل، بابه ينفتح على ضوء الداخل. [open] صفر مغلق وواحد مفتوح.
class _DoorPainter extends CustomPainter {
  _DoorPainter({
    required this.open,
    required this.filled,
    required this.color,
    required this.night,
  }) : super(repaint: open);

  final Animation<double> open;
  final bool filled;
  final Color color;
  final bool night;

  static const _door = Rect.fromLTRB(9.7, 14.2, 14.3, 21);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 24);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final roof = Path()
      ..moveTo(2.4, 11.3)
      ..lineTo(12, 3.3)
      ..lineTo(21.6, 11.3);
    final chimney = Path()
      ..moveTo(16.9, 7.9)
      ..lineTo(16.9, 4.7);
    final walls = Path()
      ..moveTo(4.7, 9.6)
      ..lineTo(4.7, 19.3)
      ..quadraticBezierTo(4.7, 21, 6.4, 21)
      ..lineTo(17.6, 21)
      ..quadraticBezierTo(19.3, 21, 19.3, 19.3)
      ..lineTo(19.3, 9.6);
    final angle = open.value.clamp(-.2, 1.2) * 1.25;
    final swing = math.cos(angle);
    final rise = math.sin(angle).clamp(0.0, 1.0) * .9;
    // الباب على مفصله الأيسر: حافته الأخرى تقترب وتعلو قليلاً وهو ينفتح نحونا.
    final panel = Path()
      ..moveTo(_door.left, _door.bottom)
      ..lineTo(_door.left, _door.top)
      ..lineTo(_door.left + _door.width * swing, _door.top - rise)
      ..lineTo(_door.left + _door.width * swing, _door.bottom)
      ..close();
    final doorway = RRect.fromRectAndCorners(
      _door,
      topLeft: const Radius.circular(1.2),
      topRight: const Radius.circular(1.2),
    );

    if (filled) {
      final body = Path()
        ..moveTo(12, 3.9)
        ..lineTo(19.3, 9.9)
        ..lineTo(19.3, 19.3)
        ..quadraticBezierTo(19.3, 21, 17.6, 21)
        ..lineTo(6.4, 21)
        ..quadraticBezierTo(4.7, 21, 4.7, 19.3)
        ..lineTo(4.7, 9.9)
        ..close();
      canvas
        ..drawPath(body, Paint()..color = color)
        ..drawPath(roof, line)
        ..drawPath(chimney, line)
        // ضوء الداخل الدافئ يظهر كلما انفتح الباب.
        ..drawRRect(
          doorway,
          Paint()
            ..color = Color.lerp(
              night ? const Color(0xFF1C2833) : Colors.white,
              const Color(0xFFFFE3A0),
              _smooth(open.value * 1.6),
            )!,
        )
        ..drawPath(
          panel,
          Paint()..color = Color.lerp(color, Colors.white, .32)!,
        )
        ..drawPath(
          panel,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7
            ..strokeJoin = StrokeJoin.round
            ..color = Color.lerp(color, Colors.black, .25)!,
        );
      // مقبض الباب على حافته الحرة.
      if (swing > .35) {
        canvas.drawCircle(
          Offset(_door.left + _door.width * swing - 1.1, 17.9),
          .55,
          Paint()..color = Color.lerp(color, Colors.black, .35)!,
        );
      }
    } else {
      canvas
        ..drawPath(roof, line)
        ..drawPath(chimney, line)
        ..drawPath(walls, line)
        ..drawRRect(doorway, line..strokeWidth = 1.5)
        ..drawPath(panel, line..strokeWidth = 1.2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DoorPainter oldDelegate) =>
      oldDelegate.open != open ||
      oldDelegate.filled != filled ||
      oldDelegate.color != color ||
      oldDelegate.night != night;
}

/// قلم يدخل على التقويم ويكتب سطراً متموجاً، ثم يبقى. حين يُترك التبويب يخفت ويبتعد.
class _PenPainter extends CustomPainter {
  _PenPainter({
    required this.write,
    required this.leaving,
    required this.night,
  }) : super(repaint: write);

  final Animation<double> write;
  final bool leaving;
  final bool night;

  static final _line = Path()
    ..moveTo(6.4, 16.9)
    ..cubicTo(7.4, 14.7, 8.5, 14.7, 9.1, 16.6)
    ..cubicTo(9.7, 18.4, 10.8, 18.4, 11.6, 16.5)
    ..cubicTo(12.3, 14.8, 13.4, 14.8, 14, 16.5)
    ..cubicTo(14.4, 17.5, 15, 17.3, 15.6, 16.3);

  /// اتجاه القلم من رأسه إلى آخره: إلى الأعلى يميناً.
  static const _axis = Offset(.7071, -.7071);

  @override
  void paint(Canvas canvas, Size size) {
    final v = write.value.clamp(0.0, 1.0);
    if (v <= 0) return;
    canvas
      ..save()
      ..scale(size.width / 24);
    final metric = _line.computeMetrics().first;
    double shown;
    double written;
    Offset tip;
    double wiggle = 0;
    if (leaving) {
      // يخفت هو وما كتب، ويبتعد القلم على امتداده.
      shown = v;
      written = 1;
      tip = metric.getTangentForOffset(metric.length)!.position +
          _axis * (6 * (1 - v));
    } else if (v < .3) {
      final come = Curves.easeOutCubic.transform(v / .3);
      shown = come;
      written = 0;
      tip = metric.getTangentForOffset(0)!.position + _axis * (7 * (1 - come));
    } else {
      final along = Curves.easeInOutSine.transform(((v - .3) / .65).clamp(0.0, 1.0));
      shown = 1;
      written = along;
      tip = metric.getTangentForOffset(metric.length * along)!.position;
      wiggle = math.sin(along * math.pi * 6) * .07 * (1 - along);
    }

    final ink = night ? Colors.white : const Color(0xFF263238);
    if (written > 0) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * written),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = ink.withValues(alpha: shown),
      );
    }

    // القلم: رأس رصاص على خشب فاتح، وجسم، وممحاة بلون التطبيق، وحوله هالة تفصله عن التقويم.
    canvas
      ..save()
      ..translate(tip.dx, tip.dy)
      ..rotate(-math.pi / 4 + wiggle);
    final body = RRect.fromLTRBR(2.4, -1.6, 10.6, 1.6, const Radius.circular(.6));
    final wood = Path()
      ..moveTo(0, 0)
      ..lineTo(2.5, -1.6)
      ..lineTo(2.5, 1.6)
      ..close();
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..color = (night ? const Color(0xFF2B2B2B) : Colors.white)
          .withValues(alpha: shown);
    canvas
      ..drawRRect(body, halo)
      ..drawPath(wood, halo)
      ..drawPath(wood, Paint()..color = const Color(0xFFE9C79B).withValues(alpha: shown))
      ..drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(.9, -.58)
          ..lineTo(.9, .58)
          ..close(),
        Paint()..color = ink.withValues(alpha: shown),
      )
      ..drawRRect(body, Paint()..color = ink.withValues(alpha: shown))
      ..drawRect(
        const Rect.fromLTRB(8.8, -1.6, 10.6, 1.6),
        Paint()..color = const Color(0xFF7CC4F2).withValues(alpha: shown),
      )
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_PenPainter oldDelegate) =>
      oldDelegate.write != write ||
      oldDelegate.leaving != leaving ||
      oldDelegate.night != night;
}

/// دائرة حسابي: الشخصية تنزلق خارجة وتدخل مكانها شخصية بارتداد، والدائرة تنبض قليلاً.
class _SwapPainter extends CustomPainter {
  _SwapPainter({
    required this.swap,
    required this.filled,
    required this.color,
  }) : super(repaint: swap);

  final Animation<double> swap;
  final bool filled;
  final Color color;

  static const _centre = Offset(12, 12);
  static const _radius = 9.6;

  Path _person(double dx) => Path()
    ..addOval(Rect.fromCircle(center: Offset(12 + dx, 9.3), radius: 3.6))
    ..addOval(Rect.fromCenter(center: Offset(12 + dx, 21.6), width: 14.4, height: 11.4));

  @override
  void paint(Canvas canvas, Size size) {
    final v = swap.value.clamp(0.0, 1.0);
    final pulse = 1 + .07 * math.sin(math.pi * v);
    canvas
      ..save()
      ..scale(size.width / 24)
      ..translate(12, 12)
      ..scale(pulse)
      ..translate(-12, -12);
    // الخارجة تنزلق يساراً، والداخلة تأتي من اليمين بارتداد.
    final out = -22 * Curves.easeInCubic.transform((v / .5).clamp(0.0, 1.0));
    final into =
        22 * (1 - Curves.easeOutBack.transform(((v - .28) / .72).clamp(0.0, 1.0)));
    final circle = Rect.fromCircle(center: _centre, radius: _radius);
    if (filled) {
      canvas
        ..saveLayer(circle.inflate(2), Paint())
        ..drawCircle(_centre, _radius + .85, Paint()..color = color)
        ..clipPath(Path()..addOval(circle.deflate(.2)));
      final cut = Paint()..blendMode = BlendMode.dstOut;
      canvas
        ..drawPath(_person(out), cut)
        ..drawPath(_person(into), cut)
        ..restore();
    } else {
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color;
      canvas
        ..drawCircle(_centre, _radius, line)
        ..save()
        ..clipPath(Path()..addOval(circle.deflate(.4)))
        ..drawPath(_person(out), line)
        ..drawPath(_person(into), line)
        ..restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SwapPainter oldDelegate) =>
      oldDelegate.swap != swap ||
      oldDelegate.filled != filled ||
      oldDelegate.color != color;
}
