import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../auth/truck_art.dart';
import '../auth/truck_scene.dart';
import 'workers_art.dart';

// مكان الرسم كما في التصميم (إطار عرضه 391): بُعده عن يسار الإطار، ونسبة وحداته إلى بكسلات التصميم.
const _artLeft = 50.9;
const _artScale = .9257;

/// ارتفاع مكان الرسم بوحدات التصميم.
const workersSceneHeight = 207 * _artScale;

// أطراف الأنابيب في الرسم، ومنها تكمل إلى حافتي الشاشة.
const _pipeInk = Color(0xFF455A64);
const _paleInk = Color(0xFFEBEBEB);
const _groundInk = Color(0xFF263238);
const _pipeSlope = .0098;

// العامل الواقف يدير عجلة الصمام بيديه.
const _waist = Offset(187, 104);
const _standingNeck = Offset(186, 58);
const _upperShoulder = Offset(197, 64);
const _lowerShoulder = Offset(181, 66);
const _wheelHub = Offset(229.7, 53.6);
const _standingNeedle = Offset(243.53, 53.2);
const _standingEyes = Offset(188.25, 41.6);

// العامل الجالس يضبط العداد بيد ويقرأ الجهاز الذي في يده الأخرى.
const _hip = Offset(104, 152);
const _kneelingNeck = Offset(97, 118);
const _reachingShoulder = Offset(92, 127);
const _holdingShoulder = Offset(108, 121);
const _meterGrip = Offset(79, 138);
const _smallNeedle = Offset(35.3, 118.6);
const _tallNeedle = Offset(23.8, 111.3);
const _kneelingEyes = Offset(86.7, 105.3);

/// وضع العاملين في لحظة معينة: حركتهما متصلة ولا تتوقف.
class WorkersPose {
  const WorkersPose(this.time);

  final double time;

  static const _turnPeriod = 2.6;
  static const _dialPeriod = 3.4;
  static const _readPeriod = 2.2;

  double _wave(double period, [double shift = 0]) =>
      math.sin(2 * math.pi * time / period + shift);

  /// إغماضة قصيرة في كل دورة: 1 مغمضتان.
  double _blink(double cycle, double at) {
    final t = (time % cycle) - at;
    if (t <= 0 || t >= .18) return 0;
    return math.sin(math.pi * t / .18);
  }

  // اليدان تتحركان بعكس بعضهما على العجلة، وجسمه يميل معهما قليلاً.
  double get standingLean => .006 * _wave(_turnPeriod);
  double get upperArm => .05 * _wave(_turnPeriod);
  double get lowerArm => -.036 * _wave(_turnPeriod);
  double get spokes => .16 * _wave(_turnPeriod);
  double get standingHead => .018 * _wave(_turnPeriod * 2, .8);
  double get standingNeedle => .35 * _wave(_turnPeriod * 2) + .05 * _wave(.9);
  double get standingBlink => _blink(5.2, 1.4);

  // يده تضبط العداد، ورأسه ينزل إلى الجهاز ويرتفع إلى العداد.
  double get kneelingLean => .005 * _wave(_dialPeriod, 1);
  double get kneelingHead => .028 * _wave(_dialPeriod * 2, 2);
  double get reachingArm => .02 * _wave(_dialPeriod);
  double get smallNeedle => .45 * _wave(_dialPeriod);
  double get holdingArm => .016 * _wave(_readPeriod, .5);
  double get meterTilt => .05 * _wave(_readPeriod, 2);
  double get tallNeedle => .3 * _wave(7.3, 1);
  double get kneelingBlink => _blink(6.1, 3.7);
}

/// طبقة من الرسم تُحفظ صورةً على شبكة بكسلات الشاشة: تبقى حادة وهي ساكنة، ولا تُعاد مساراتها مع كل إطار.
class _ArtLayer {
  _ArtLayer(List<ArtShape> shapes) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;
    Rect? box;
    for (final shape in shapes) {
      final path = parseSvgPath(shape.path);
      paint.color = Color(shape.color);
      canvas.drawPath(path, paint);
      final shapeBox = path.getBounds();
      box = box?.expandToInclude(shapeBox) ?? shapeBox;
    }
    _picture = recorder.endRecording();
    _bounds = box!.inflate(1);
  }

  late final ui.Picture _picture;
  late final Rect _bounds;
  ui.Image? _image;
  Rect _place = Rect.zero;

  void prepare(Offset origin, double unit, double pixelRatio) {
    final scale = unit * pixelRatio;
    final left = ((origin.dx + _bounds.left * unit) * pixelRatio).floorToDouble();
    final top = ((origin.dy + _bounds.top * unit) * pixelRatio).floorToDouble();
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..translate(origin.dx * pixelRatio - left, origin.dy * pixelRatio - top)
      ..scale(scale)
      ..drawPicture(_picture);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (_bounds.width * scale).ceil() + 1,
      (_bounds.height * scale).ceil() + 1,
    );
    picture.dispose();
    _image?.dispose();
    _image = image;
    _place = Rect.fromLTWH(
      (left / pixelRatio - origin.dx) / unit,
      (top / pixelRatio - origin.dy) / unit,
      image.width / scale,
      image.height / scale,
    );
  }

  void paint(Canvas canvas) {
    final image = _image!;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      _place,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  void dispose() {
    _image?.dispose();
    _picture.dispose();
  }
}

/// طبقات الرسم مرة واحدة، وصورها بمقاس الشاشة.
class WorkersArt {
  WorkersArt()
      : _backdrop = _ArtLayer(workersBackdrop),
        _spokes = _ArtLayer(workersSpokes),
        _standingHead = _ArtLayer(workersStandingHead),
        _upperArm = _ArtLayer(workersUpperArm),
        _wheelRim = _ArtLayer(workersWheelRim),
        _standingBody = _ArtLayer(workersStandingBody),
        _lowerArm = _ArtLayer(workersLowerArm),
        _standingCollar = _ArtLayer(workersStandingCollar),
        _kneelingHead = _ArtLayer(workersKneelingHead),
        _palm = _ArtLayer(workersPalm),
        _smallDial = _ArtLayer(workersSmallDial),
        _reachingArm = _ArtLayer(workersReachingArm),
        _kneelingBody = _ArtLayer(workersKneelingBody),
        _meter = _ArtLayer(workersMeter),
        _holdingArm = _ArtLayer(workersHoldingArm),
        _kneelingCollar = _ArtLayer(workersKneelingCollar),
        _standingEyesArt = _record(workersStandingEyes),
        _kneelingEyesArt = _record(workersKneelingEyes),
        _standingNeedleArt = _record(workersStandingNeedle),
        _smallNeedleArt = _record(workersSmallNeedle),
        _tallNeedleArt = _record(workersTallNeedle);

  final _ArtLayer _backdrop, _spokes, _standingHead, _upperArm, _wheelRim, _standingBody, _lowerArm;
  final _ArtLayer _standingCollar, _kneelingHead, _palm, _smallDial, _reachingArm, _kneelingBody;
  final _ArtLayer _meter, _holdingArm, _kneelingCollar;
  final ui.Picture _standingEyesArt, _kneelingEyesArt;
  final ui.Picture _standingNeedleArt, _smallNeedleArt, _tallNeedleArt;

  Offset _origin = Offset.zero;
  double _unit = 0;
  double _pixelRatio = 0;

  List<_ArtLayer> get _layers => [
        _backdrop, _spokes, _standingHead, _upperArm, _wheelRim, _standingBody, _lowerArm,
        _standingCollar, _kneelingHead, _palm, _smallDial, _reachingArm, _kneelingBody,
        _meter, _holdingArm, _kneelingCollar,
      ];

  void _prepare(Offset origin, double unit, double pixelRatio) {
    if (origin == _origin && unit == _unit && pixelRatio == _pixelRatio) return;
    _origin = origin;
    _unit = unit;
    _pixelRatio = pixelRatio;
    for (final layer in _layers) {
      layer.prepare(origin, unit, pixelRatio);
    }
  }

  void dispose() {
    for (final layer in _layers) {
      layer.dispose();
    }
    for (final picture in [
      _standingEyesArt, _kneelingEyesArt, _standingNeedleArt, _smallNeedleArt, _tallNeedleArt,
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

/// عاملان يشتغلان على الأنابيب، والأنابيب تكمل إلى حافتي الشاشة.
class WorkersScene extends StatefulWidget {
  const WorkersScene({super.key, required this.scale, this.left = 0});

  /// نسبة عرض الشاشة إلى عرض التصميم.
  final double scale;

  /// بُعد الصفحة عن يسار الشاشة حين تتوسطها.
  final double left;

  @override
  State<WorkersScene> createState() => _WorkersSceneState();
}

class _WorkersSceneState extends State<WorkersScene> with SingleTickerProviderStateMixin {
  final _art = WorkersArt();
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

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
    _ticker.dispose();
    _time.dispose();
    _art.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'عاملان من جايك يشتغلان على أنابيب: واحد يدير الصمام والآخر يقرأ العداد',
      child: RepaintBoundary(
        child: CustomPaint(
          painter: WorkersScenePainter(
            art: _art,
            time: _time,
            scale: widget.scale,
            left: widget.left,
            pixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      ),
    );
  }
}

class WorkersScenePainter extends CustomPainter {
  WorkersScenePainter({
    required this.art,
    required this.time,
    required this.scale,
    required this.pixelRatio,
    this.left = 0,
  }) : super(repaint: time);

  final WorkersArt art;
  final ValueListenable<double> time;
  final double scale;
  final double left;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final pose = WorkersPose(time.value);
    final unit = scale * _artScale;
    final origin = Offset(left + _artLeft * scale, 0);
    art._prepare(origin, unit, pixelRatio);
    canvas
      ..save()
      ..translate(origin.dx, origin.dy)
      ..scale(unit);
    _paintPipeEnds(canvas, -origin.dx / unit, (size.width - origin.dx) / unit);
    art._backdrop.paint(canvas);
    _turned(canvas, _wheelHub, pose.spokes, art._spokes);
    _paintStanding(canvas, pose);
    _paintKneeling(canvas, pose);
    canvas.restore();
  }

  /// الأنابيب وخط الأرض من طرفيها في الرسم إلى حافتي الشاشة.
  void _paintPipeEnds(Canvas canvas, double left, double right) {
    final pipe = Paint()..color = _pipeInk;
    final pale = Paint()..color = _paleInk;
    double high(double x) => 128.547 + (x - 6.95) * _pipeSlope;
    double low(double x) => 161.816 + (x - 6.66) * _pipeSlope;
    canvas
      ..drawRect(Rect.fromLTRB(left, 195.3, right, 195.516), Paint()..color = _groundInk)
      ..drawPath(
        Path()
          ..moveTo(left, high(left))
          ..lineTo(7.5, high(7.5))
          ..lineTo(7.5, low(7.5))
          ..lineTo(left, low(left))
          ..close(),
        pipe,
      )
      ..drawRect(Rect.fromLTRB(302.8, 70.8727, right, 104.146), pipe)
      ..drawRect(Rect.fromLTRB(left, 79.1692, 16, 99.1323), pale)
      ..drawRect(Rect.fromLTRB(301.3, 117.837, right, 137.8), pale);
  }

  void _turnAround(Canvas canvas, Offset center, double angle) {
    canvas
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..translate(-center.dx, -center.dy);
  }

  void _turned(Canvas canvas, Offset center, double angle, _ArtLayer layer) {
    canvas.save();
    _turnAround(canvas, center, angle);
    layer.paint(canvas);
    canvas.restore();
  }

  void _turnedPicture(Canvas canvas, Offset center, double angle, ui.Picture picture) {
    canvas.save();
    _turnAround(canvas, center, angle);
    canvas
      ..drawPicture(picture)
      ..restore();
  }

  void _paintEyes(Canvas canvas, Offset center, double blink, ui.Picture eyes) {
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(1, 1 - blink * .85)
      ..translate(-center.dx, -center.dy)
      ..drawPicture(eyes)
      ..restore();
  }

  void _paintStanding(Canvas canvas, WorkersPose pose) {
    canvas.save();
    _turnAround(canvas, _waist, pose.standingLean);
    canvas.save();
    _turnAround(canvas, _standingNeck, pose.standingHead);
    art._standingHead.paint(canvas);
    _paintEyes(canvas, _standingEyes, pose.standingBlink, art._standingEyesArt);
    canvas.restore();
    _turned(canvas, _upperShoulder, pose.upperArm, art._upperArm);
    canvas.restore();

    art._wheelRim.paint(canvas);
    _turnedPicture(canvas, _standingNeedle, pose.standingNeedle, art._standingNeedleArt);

    canvas.save();
    _turnAround(canvas, _waist, pose.standingLean);
    art._standingBody.paint(canvas);
    _turned(canvas, _lowerShoulder, pose.lowerArm, art._lowerArm);
    art._standingCollar.paint(canvas);
    canvas.restore();
  }

  void _paintKneeling(Canvas canvas, WorkersPose pose) {
    canvas.save();
    _turnAround(canvas, _hip, pose.kneelingLean);
    canvas.save();
    _turnAround(canvas, _kneelingNeck, pose.kneelingHead);
    art._kneelingHead.paint(canvas);
    _paintEyes(canvas, _kneelingEyes, pose.kneelingBlink, art._kneelingEyesArt);
    canvas.restore();
    _turned(canvas, _reachingShoulder, pose.reachingArm, art._palm);
    canvas.restore();

    art._smallDial.paint(canvas);

    canvas.save();
    _turnAround(canvas, _hip, pose.kneelingLean);
    _turned(canvas, _reachingShoulder, pose.reachingArm, art._reachingArm);
    canvas.restore();
    _turnedPicture(canvas, _smallNeedle, pose.smallNeedle, art._smallNeedleArt);

    canvas.save();
    _turnAround(canvas, _hip, pose.kneelingLean);
    art._kneelingBody.paint(canvas);
    canvas.save();
    _turnAround(canvas, _holdingShoulder, pose.holdingArm);
    _turned(canvas, _meterGrip, pose.meterTilt, art._meter);
    art._holdingArm.paint(canvas);
    canvas.restore();
    art._kneelingCollar.paint(canvas);
    canvas.restore();

    _turnedPicture(canvas, _tallNeedle, pose.tallNeedle, art._tallNeedleArt);
  }

  @override
  bool shouldRepaint(WorkersScenePainter oldDelegate) =>
      oldDelegate.art != art ||
      oldDelegate.time != time ||
      oldDelegate.scale != scale ||
      oldDelegate.left != left ||
      oldDelegate.pixelRatio != pixelRatio;
}
