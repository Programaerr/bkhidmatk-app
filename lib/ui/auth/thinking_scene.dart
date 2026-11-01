import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'thinking_art.dart';
import 'truck_art.dart';
import 'truck_scene.dart';

// مكان الرسم كما في التصميم (إطار عرضه 391): وسطه في وسط الشاشة.
const _artScale = .7784;
const _artCenterX = 249.6;
const _artCenterY = 250.0;
const _artCenterFraction = 208.7 / 414.3;

// رأس سائق السيارة مكبَّر حتى يطابق رأس الشخصية الأصلية في مكانها نفسه.
const _headScale = 2.4;
const _driverFace = Offset(669, 258);
const _facePlace = Offset(222, 207);
const _neck = Offset(218, 262);
const _wrist = Offset(275, 247);

// أجزاء الوجه المتحركة في رسم رأس السائق.
const _rightLid = 4, _leftEye = 5, _rightEye = 6, _leftLid = 7, _leftBrow = 10, _rightBrow = 11;
const _leftEyeCenter = Offset(669.15, 254.25);
const _rightEyeCenter = Offset(677.95, 255.05);

// مركز كل ترس وسرعته باللفات في الثانية، والمتجاوران يدوران بعكس بعضهما.
const _gears = <(Offset, double)>[
  (Offset(243.3, 268.2), .035),
  (Offset(398.16, 285.78), -.08),
  (Offset(92.54, 292.3), .09),
  (Offset(238.12, 114.8), -.11),
  (Offset(390.13, 184.79), .14),
  (Offset(354.6, 334.87), -.1),
];

const _bulbCenter = Offset(127, 150);
const _cloudCenter = Offset(321, 146);
const _smallBubbleCenter = Offset(266.86, 192.66);
const _mediumBubbleCenter = Offset(283.96, 187);
const _questionCenter = Offset(321, 146);

const _glassOff = Color(0xFFF5F5F5);
const _glassOn = Color(0xFFFFFDE7);
const _filamentOff = Color(0xFFE0E0E0);
const _filamentOn = Color(0xFFFFA000);

/// وضع الشخصية في لحظة معينة: تفكر طوال الدورة، ثم تأتيها الفكرة فيضيء المصباح.
class ThinkingPose {
  const ThinkingPose(this.time);

  final double time;

  static const cycle = 9.0;
  static const _ideaStart = 6.4;

  double get _phase => time % cycle;

  double _wave(double period, [double shift = 0]) =>
      math.sin(2 * math.pi * time / period + shift);

  /// ترتفع من 0 إلى 1 بنعومة، ثم تثبت، ثم ترجع إلى 0.
  double _pulse(double start, double rise, double hold, double fall) {
    final t = _phase - start;
    if (t <= 0 || t >= rise + hold + fall) return 0;
    if (t < rise) return Curves.easeOut.transform(t / rise);
    if (t < rise + hold) return 1;
    return 1 - Curves.easeIn.transform((t - rise - hold) / fall);
  }

  /// لحظة الفكرة.
  double get idea => _pulse(_ideaStart, .3, 1, .7);

  /// ضوء المصباح: يرتجف مرتين قبل الفكرة ثم يضيء معها.
  double get light => [
        _pulse(5.7, .06, .04, .1) * .35,
        _pulse(6, .06, .06, .12) * .6,
        idea,
      ].reduce(math.max);

  /// إغماض العينين: 1 مغمضتان.
  double get blink => math.max(_pulse(1.6, .07, .02, .09), _pulse(4.3, .07, .02, .09));

  /// ميلان الرأس، ويرتفع الرأس عند الفكرة.
  double get headTilt => .03 * _wave(4.5) - .05 * idea;

  /// صعود الجسم مع التنفس.
  double get bodyLift => -1.2 * (.5 + .5 * _wave(3)) - 1.5 * idea;

  /// حركة العينين: تنظران إلى الأعلى وتتنقلان وهو يفكر.
  Offset get eyes => Offset(.25 * _wave(4.5, 1), -.2 + .12 * _wave(3) - .15 * idea);

  double get leftBrowLift => .1 + .15 * _wave(4.5) + .7 * idea;
  double get rightBrowLift => .35 + .3 * _wave(4.5) + .7 * idea;

  /// الأصابع تنقر على الذقن فترة من الدورة.
  double get handTap {
    final t = _phase - 2.4;
    if (t <= 0 || t >= 1.6) return 0;
    return .035 * math.sin(math.pi * t / 1.6) * math.sin(2 * math.pi * 2.4 * t);
  }

  /// زمن التروس: تتسارع قليلاً عند الفكرة ثم ترجع إلى سرعتها.
  double get gearTime {
    final spin = ((_phase - _ideaStart) / 1.4).clamp(0.0, 1.0);
    return time + 1.5 * ((time / cycle).floorToDouble() + Curves.easeInOut.transform(spin));
  }

  double get cloudBob => 2.5 * _wave(4.5);
  double get cloudSize => 1 + .05 * idea;
  double get questionTilt => .05 * _wave(3);
  double get smallBubbleSize => 1 + .16 * _wave(3);
  double get mediumBubbleSize => 1 + .16 * _wave(3, -.9);
}

/// طبقات الرسم مسجّلة مرة واحدة حتى لا يُعاد بناؤها مع كل إطار.
class ThinkingArt {
  ThinkingArt()
      : backdrop = RasterLayer(_record(thinkingBackdrop), const Rect.fromLTRB(-40, 50, 540, 430)),
        gears = [for (final gear in thinkingGears) _record([gear])],
        bulbBase = _record(thinkingBulbBase),
        cloud = _record(thinkingCloud),
        smallBubble = _record(thinkingSmallBubble),
        mediumBubble = _record(thinkingMediumBubble),
        question = _record(thinkingQuestion),
        arm = _record(thinkingArm),
        hand = _record(thinkingHand),
        body = _record(thinkingBody),
        table = _record(thinkingTable),
        head = _record([
          for (final (index, shape) in artDriverHead.indexed)
            if (!const {_rightLid, _leftEye, _rightEye, _leftLid, _leftBrow, _rightBrow}
                .contains(index))
              shape,
        ]),
        leftEye = _record([artDriverHead[_leftEye]]),
        rightEye = _record([artDriverHead[_rightEye]]),
        lids = _record([artDriverHead[_rightLid], artDriverHead[_leftLid]]),
        leftBrow = _record([artDriverHead[_leftBrow]]),
        rightBrow = _record([artDriverHead[_rightBrow]]),
        bulbGlass = parseSvgPath(thinkingBulbGlass),
        bulbFilament = parseSvgPath(thinkingBulbFilament);

  final RasterLayer backdrop;
  final List<ui.Picture> gears;
  final ui.Picture bulbBase, cloud, smallBubble, mediumBubble, question, arm, hand, body, table;
  final ui.Picture head, leftEye, rightEye, lids, leftBrow, rightBrow;
  final Path bulbGlass, bulbFilament;

  void dispose() {
    backdrop.dispose();
    for (final picture in [
      ...gears, bulbBase, cloud, smallBubble, mediumBubble, question, arm, hand, body, table,
      head, leftEye, rightEye, lids, leftBrow, rightBrow,
    ]) {
      picture.dispose();
    }
  }

  static ui.Picture _record(List<ArtShape> shapes) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;
    for (final shape in shapes) {
      paint.color = Color(shape.color);
      canvas.drawPath(parseSvgPath(shape.path), paint);
    }
    return recorder.endRecording();
  }
}

/// سائق السيارة يفكر: رأسه يميل، ويداه ترتاحان، والتروس تدور، ثم يضيء المصباح عند الفكرة.
class ThinkingScene extends StatefulWidget {
  const ThinkingScene({super.key, required this.scale});

  final double scale;

  @override
  State<ThinkingScene> createState() => _ThinkingSceneState();
}

class _ThinkingSceneState extends State<ThinkingScene> with SingleTickerProviderStateMixin {
  final _art = ThinkingArt();
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  void _onTick(Duration elapsed) {
    // لا تقفز الحركة إذا توقفت الإطارات ثم عادت.
    final step = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    _time.value += math.min(step, .1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _art.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'سائق جايك يفكر ويده على ذقنه',
      child: RepaintBoundary(
        child: CustomPaint(
          painter: ThinkingScenePainter(
            art: _art,
            time: _time,
            scale: widget.scale,
            pixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      ),
    );
  }
}

class ThinkingScenePainter extends CustomPainter {
  ThinkingScenePainter({
    required this.art,
    required this.time,
    required this.scale,
    required this.pixelRatio,
  }) : super(repaint: time);

  final ThinkingArt art;
  final ValueListenable<double> time;
  final double scale;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      TruckSceneMetrics.hill(size, scale),
      Paint()..color = TruckSceneMetrics.hillColor,
    );

    final pose = ThinkingPose(time.value);
    final unit = _artScale * scale;
    canvas
      ..save()
      ..translate(
        size.width / 2 - _artCenterX * unit,
        size.height * _artCenterFraction - _artCenterY * unit,
      )
      ..scale(unit);
    art.backdrop.paint(canvas, unit * pixelRatio);
    _paintGears(canvas, pose);
    _paintBulb(canvas, pose);
    _paintCloud(canvas, pose);
    _paintCharacter(canvas, pose);
    canvas
      ..drawPicture(art.table)
      ..restore();
  }

  void _turnAround(Canvas canvas, Offset center, double angle) {
    canvas
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..translate(-center.dx, -center.dy);
  }

  void _sizeAround(Canvas canvas, Offset center, double sizeX, double sizeY) {
    canvas
      ..translate(center.dx, center.dy)
      ..scale(sizeX, sizeY)
      ..translate(-center.dx, -center.dy);
  }

  void _paintGears(Canvas canvas, ThinkingPose pose) {
    for (final (index, (center, speed)) in _gears.indexed) {
      canvas.save();
      _turnAround(canvas, center, 2 * math.pi * speed * pose.gearTime);
      canvas
        ..drawPicture(art.gears[index])
        ..restore();
    }
  }

  void _paintBulb(Canvas canvas, ThinkingPose pose) {
    final light = pose.light;
    if (light > 0) {
      canvas.drawCircle(
        _bulbCenter,
        92,
        Paint()
          ..shader = ui.Gradient.radial(_bulbCenter, 92, [
            Colors.white.withValues(alpha: .8 * light),
            Colors.white.withValues(alpha: 0),
          ]),
      );
      final ray = Paint()
        ..color = Colors.white.withValues(alpha: light)
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;
      // الأشعة تطلع من أعلى المصباح وجانبيه، أما قاعدته فلا يخرج منها ضوء.
      for (var i = 0; i < 7; i++) {
        final angle = math.pi * (.95 + i * .185);
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          _bulbCenter + direction * 50,
          _bulbCenter + direction * (50 + 16 * light),
          ray,
        );
      }
    }
    canvas
      ..drawPicture(art.bulbBase)
      ..drawPath(art.bulbGlass, Paint()..color = Color.lerp(_glassOff, _glassOn, light)!)
      ..drawPath(art.bulbFilament, Paint()..color = Color.lerp(_filamentOff, _filamentOn, light)!);
  }

  void _paintCloud(Canvas canvas, ThinkingPose pose) {
    canvas
      ..save()
      ..translate(0, pose.cloudBob * .4);
    _sizeAround(canvas, _smallBubbleCenter, pose.smallBubbleSize, pose.smallBubbleSize);
    canvas
      ..drawPicture(art.smallBubble)
      ..restore()
      ..save()
      ..translate(0, pose.cloudBob * .7);
    _sizeAround(canvas, _mediumBubbleCenter, pose.mediumBubbleSize, pose.mediumBubbleSize);
    canvas
      ..drawPicture(art.mediumBubble)
      ..restore()
      ..save()
      ..translate(0, pose.cloudBob);
    _sizeAround(canvas, _cloudCenter, pose.cloudSize, pose.cloudSize);
    canvas.drawPicture(art.cloud);
    _turnAround(canvas, _questionCenter, pose.questionTilt);
    canvas
      ..drawPicture(art.question)
      ..restore();
  }

  void _paintCharacter(Canvas canvas, ThinkingPose pose) {
    canvas
      ..save()
      ..translate(0, pose.bodyLift)
      ..drawPicture(art.arm)
      ..save();
    _turnAround(canvas, _wrist, pose.handTap);
    canvas
      ..drawPicture(art.hand)
      ..restore()
      ..drawPicture(art.body)
      ..save();
    _turnAround(canvas, _neck, pose.headTilt);
    canvas
      ..translate(_facePlace.dx, _facePlace.dy)
      ..scale(_headScale)
      ..translate(-_driverFace.dx, -_driverFace.dy)
      ..drawPicture(art.head);
    _paintFace(canvas, pose);
    canvas
      ..restore()
      ..restore();
  }

  void _paintFace(Canvas canvas, ThinkingPose pose) {
    final open = 1 - pose.blink * .88;
    final eyes = pose.eyes;
    for (final (picture, center) in [
      (art.leftEye, _leftEyeCenter),
      (art.rightEye, _rightEyeCenter),
    ]) {
      canvas
        ..save()
        ..translate(eyes.dx, eyes.dy);
      _sizeAround(canvas, center, 1, open);
      canvas
        ..drawPicture(picture)
        ..restore();
    }
    canvas
      ..save()
      ..translate(0, pose.blink * .9)
      ..drawPicture(art.lids)
      ..restore()
      ..save()
      ..translate(0, -pose.leftBrowLift)
      ..drawPicture(art.leftBrow)
      ..restore()
      ..save()
      ..translate(0, -pose.rightBrowLift)
      ..drawPicture(art.rightBrow)
      ..restore();
  }

  @override
  bool shouldRepaint(ThinkingScenePainter oldDelegate) =>
      oldDelegate.art != art ||
      oldDelegate.time != time ||
      oldDelegate.scale != scale ||
      oldDelegate.pixelRatio != pixelRatio;
}
