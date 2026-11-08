import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/language.dart';
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

// ملامح السائق المبتسمة لا تُرسم هنا: الجفنان والعينان والفم والحاجبان.
const _driverExpression = {4, 5, 6, 7, 9, 10, 11};

// ملامح التفكير من الرسم الأصلي، بمكانها على وجه السائق.
const _leftEyeCenter = Offset(222.4, 198);
const _rightEyeCenter = Offset(243.5, 199.9);
const _mouthCenter = Offset(231, 218.8);
const _featureInk = Color(0xFF263238);

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
const _answerCenter = Offset(321, 149);

// الكلام يكبر قليلاً وهو يظهر، فتُحفظ صورته بدقة أعلى حتى يبقى حاداً.
const _answerSharpness = 1.25;

const _glassOff = Color(0xFFF5F5F5);
const _glassOn = Color(0xFFFFFDE7);
const _filamentOff = Color(0xFFE0E0E0);
const _filamentOn = Color(0xFFFFA000);

// بعد الضغط على الرسم: يتغير ما في الغيمة، ويبقى الكلام مدة ثم ترجع علامة الاستفهام.
const _answerTurn = Duration(milliseconds: 450);
const _answerHold = Duration(milliseconds: 2800);

/// وضع الشخصية في لحظة معينة: تبقى تفكر، ولا تأتيها الفكرة إلا عند الضغط على الرسم.
class ThinkingPose {
  const ThinkingPose(this.time, {this.answer = 0});

  final double time;

  /// تقدّم الجواب بعد الضغط على الرسم: 0 علامة الاستفهام في الغيمة، و1 «ها فكرت».
  final double answer;

  static const cycle = 9.0;

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

  /// الفكرة بعد الضغط على الرسم: يضيء المصباح ويتغير الوجه.
  double get idea => Curves.easeOut.transform(answer);

  /// إغماض العينين: 1 مغمضتان.
  double get blink => [
        _pulse(1.6, .07, .02, .09),
        _pulse(4.3, .07, .02, .09),
        _pulse(7.2, .07, .02, .09),
      ].reduce(math.max);

  /// ميلان الرأس، ويرتفع الرأس عند الفكرة.
  double get headTilt => .03 * _wave(4.5) - .05 * idea;

  /// صعود الجسم مع التنفس.
  double get bodyLift => -1.2 * (.5 + .5 * _wave(3)) - 1.5 * idea;

  /// حركة العينين: تنظران إلى الغيمة وتتنقلان وهو يفكر.
  Offset get eyes => Offset(.7 + .5 * _wave(4.5, 1), -.5 + .3 * _wave(3) - .4 * idea);

  double get leftBrowLift => .3 * (1 - idea) * _wave(4.5) + 1.6 * idea;

  /// الحاجب الأيمن تحت الشعر مباشرة، فيرتفع أقل عند الفكرة حتى لا يلتصق به.
  double get rightBrowLift => .3 + .6 * (1 - idea) * _wave(4.5) + .8 * idea;

  /// الفم المزموم يتحرك قليلاً إلى الجانبين وهو يفكر.
  double get mouthShift => .6 * (1 - idea) * _wave(6);
  double get mouthTilt => .07 * (1 - idea) * _wave(6, 1);

  /// الفم ينفتح عند الفكرة كأنه يقول «ها».
  double get mouthOpen => idea;

  /// الأصابع تنقر على الذقن فترة من الدورة.
  double get handTap {
    final t = _phase - 2.4;
    if (t <= 0 || t >= 1.6) return 0;
    return .035 * math.sin(math.pi * t / 1.6) * math.sin(2 * math.pi * 2.4 * t);
  }

  double get cloudBob => 2.5 * _wave(4.5);
  double get cloudSize => 1 + .05 * idea;
  double get questionTilt => .05 * _wave(3);

  /// علامة الاستفهام تصغر وتختفي أولاً، ثم يكبر الكلام مكانها.
  double get questionSize => 1 - Curves.easeIn.transform((answer / .45).clamp(0.0, 1.0));
  double get answerSize => Curves.easeOutBack.transform(((answer - .45) / .55).clamp(0.0, 1.0));

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
        answer = RasterLayer(
          _recordAnswer(),
          Rect.fromCenter(center: _answerCenter, width: 90, height: 44),
        ),
        arm = _record(thinkingArm),
        hand = _record(thinkingHand),
        body = _record(thinkingBody),
        table = _record(thinkingTable),
        head = _record([
          for (final (index, shape) in artDriverHead.indexed)
            if (!_driverExpression.contains(index)) shape,
        ]),
        leftEye = _record(thinkingLeftEye),
        rightEye = _record(thinkingRightEye),
        leftBrow = _record(thinkingLeftBrow),
        rightBrow = _record(thinkingRightBrow),
        mouth = _record(thinkingMouth),
        bulbGlass = parseSvgPath(thinkingBulbGlass),
        bulbFilament = parseSvgPath(thinkingBulbFilament);

  final RasterLayer backdrop, answer;
  final List<ui.Picture> gears;
  final ui.Picture bulbBase, cloud, smallBubble, mediumBubble, question, arm, hand, body, table;
  final ui.Picture head, leftEye, rightEye, leftBrow, rightBrow, mouth;
  final Path bulbGlass, bulbFilament;

  void dispose() {
    backdrop.dispose();
    answer.dispose();
    for (final picture in [
      ...gears, bulbBase, cloud, smallBubble, mediumBubble, question, arm, hand, body, table,
      head, leftEye, rightEye, leftBrow, rightBrow, mouth,
    ]) {
      picture.dispose();
    }
  }

  /// كلام الشخصية في وسط الغيمة، بخط كلام السائق في الشاشة الأولى.
  static ui.Picture _recordAnswer() {
    final recorder = ui.PictureRecorder();
    final text = TextPainter(
      text: TextSpan(
        text: tr('ها فكرت', 'Got it!'),
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: _featureInk,
          height: 1,
        ),
      ),
      textDirection: appTextDirection,
    )..layout();
    text.paint(Canvas(recorder), _answerCenter - Offset(text.width / 2, text.height / 2));
    text.dispose();
    return recorder.endRecording();
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

/// سائق السيارة يفكر: رأسه يميل، ويداه ترتاحان، والتروس تدور.
/// والضغط على الرسم يضيء المصباح، ويغيّر وجهه، ويبدّل ما في الغيمة إلى «ها فكرت».
class ThinkingScene extends StatefulWidget {
  const ThinkingScene({super.key, required this.scale});

  final double scale;

  @override
  State<ThinkingScene> createState() => _ThinkingSceneState();
}

class _ThinkingSceneState extends State<ThinkingScene> with TickerProviderStateMixin {
  final _art = ThinkingArt();
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);
  late final _answer = AnimationController(vsync: this);
  Timer? _answerTimer;
  Duration _lastTick = Duration.zero;

  Duration get _turn => MediaQuery.disableAnimationsOf(context) ? Duration.zero : _answerTurn;

  void _showAnswer() {
    _answerTimer?.cancel();
    _answerTimer = Timer(_answerHold, () => _answer.animateTo(0, duration: _turn));
    _answer.animateTo(1, duration: _turn);
  }

  void _onTick(Duration elapsed) {
    _time.value += steadyStep(elapsed - _lastTick);
    _lastTick = elapsed;
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
    _answerTimer?.cancel();
    _answer.dispose();
    _ticker.dispose();
    _time.dispose();
    _art.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('سائق جايك يفكر ويده على ذقنه، اضغط عليه لتأتيه الفكرة', 'The Jaik driver thinking with his hand on his chin. Tap him to get the idea'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showAnswer,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: ThinkingScenePainter(
              art: _art,
              time: _time,
              answer: _answer,
              scale: widget.scale,
              pixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
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
    required this.answer,
    required this.scale,
    required this.pixelRatio,
  }) : super(repaint: Listenable.merge([time, answer]));

  final ThinkingArt art;
  final ValueListenable<double> time;
  final ValueListenable<double> answer;
  final double scale;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      TruckSceneMetrics.hill(size, scale),
      Paint()..color = TruckSceneMetrics.hillColor,
    );

    final pose = ThinkingPose(time.value, answer: answer.value);
    final unit = _artScale * scale;
    final resolution = unit * pixelRatio;
    art.answer.prepare(resolution * _answerSharpness);
    canvas
      ..save()
      ..translate(
        size.width / 2 - _artCenterX * unit,
        size.height * _artCenterFraction - _artCenterY * unit,
      )
      ..scale(unit);
    art.backdrop.paint(canvas, resolution);
    _paintGears(canvas, pose);
    _paintBulb(canvas, pose);
    _paintCloud(canvas, pose, resolution);
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
      _turnAround(canvas, center, 2 * math.pi * speed * pose.time);
      canvas
        ..drawPicture(art.gears[index])
        ..restore();
    }
  }

  void _paintBulb(Canvas canvas, ThinkingPose pose) {
    final light = pose.idea;
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

  void _paintCloud(Canvas canvas, ThinkingPose pose, double resolution) {
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
    if (pose.questionSize > 0) {
      canvas.save();
      _turnAround(canvas, _questionCenter, pose.questionTilt);
      _sizeAround(canvas, _questionCenter, pose.questionSize, pose.questionSize);
      canvas
        ..drawPicture(art.question)
        ..restore();
    }
    if (pose.answerSize > 0) {
      _sizeAround(canvas, _answerCenter, pose.answerSize, pose.answerSize);
      art.answer.paint(canvas, resolution * _answerSharpness);
    }
    canvas.restore();
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
      ..save()
      ..translate(_facePlace.dx, _facePlace.dy)
      ..scale(_headScale)
      ..translate(-_driverFace.dx, -_driverFace.dy)
      ..drawPicture(art.head)
      ..restore();
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
      ..translate(0, -pose.leftBrowLift)
      ..drawPicture(art.leftBrow)
      ..restore()
      ..save()
      ..translate(0, -pose.rightBrowLift)
      ..drawPicture(art.rightBrow)
      ..restore();
    final mouthOpen = pose.mouthOpen;
    if (mouthOpen < 1) {
      canvas
        ..save()
        ..translate(pose.mouthShift, 0);
      _turnAround(canvas, _mouthCenter, pose.mouthTilt);
      _sizeAround(canvas, _mouthCenter, 1 - mouthOpen, 1);
      canvas
        ..drawPicture(art.mouth)
        ..restore();
    }
    if (mouthOpen > 0) {
      canvas.drawOval(
        Rect.fromCenter(center: _mouthCenter, width: 4.6 * mouthOpen, height: 5.6 * mouthOpen),
        Paint()..color = _featureInk,
      );
    }
  }

  @override
  bool shouldRepaint(ThinkingScenePainter oldDelegate) =>
      oldDelegate.art != art ||
      oldDelegate.time != time ||
      oldDelegate.answer != answer ||
      oldDelegate.scale != scale ||
      oldDelegate.pixelRatio != pixelRatio;
}
