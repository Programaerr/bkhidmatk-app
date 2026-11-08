import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/language.dart';
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

// أضلاع العجلة تسعة بين المحور وحافتها الخلفية، ويظهر منها ثلاثة كما في الرسم. ما يدور خلف
// المحور لا يُرسم، وما يقترب من أعلاها أو أسفلها يختفي خلف حافتها الأمامية ويدي العامل.
const _spokeCount = 9;
const _spokeStep = 2 * math.pi / _spokeCount;
const _spokeRing = Offset(229.19, 53.69);
const _spokeRingRadii = Size(5.64, 11.68);
const _spokeWidth = 2.12;
const _spokeInk = Color(0xFFE0E0E0);

// العامل الجالس يضبط العداد بيد ويقرأ الجهاز الذي في يده الأخرى.
const _hip = Offset(104, 152);
const _kneelingNeck = Offset(97, 118);
const _reachingShoulder = Offset(92, 127);
const _holdingShoulder = Offset(108, 121);
const _meterGrip = Offset(79, 138);
const _smallNeedle = Offset(35.3, 118.6);
const _tallNeedle = Offset(23.8, 111.3);

const _featureInk = Color(0xFF263238);
const _teethInk = Color(0xFFFFFFFF);
const _tongueInk = Color(0xFFE57373);
const _sweatInk = Color(0xFF4FC3F7);
const _sweatEdge = Color(0xFF0288D1);

// ملامح كل عامل في الرسم، وكيف يتحرك فمه مع الابتسامة، وأين تظهر ملامح الشغل على وجهه.
const _standingFeatures = _Features(
  eyes: Offset(188.25, 41.6),
  leftEye: Offset(184.79, 41.85),
  rightEye: Offset(191.71, 41.39),
  leftBrow: Offset(183.49, 37.26),
  rightBrow: Offset(190.72, 36.25),
  mouthCorner: Offset(185.9, 46.1),
  mouthEnd: Offset(188.37, 47.76),
  cornerRise: Offset(-.05, -.9),
  endRise: Offset(.08, 0),
  bow: Offset(0, .45),
  mouth: Offset(187.1, 47.3),
  mouthTilt: .3,
  openMouth: Size(1.9, 2.3),
  teeth: Size(2.5, 1.2),
  grin: Size(2.8, 1.8),
  tongue: Offset(186.1, 47.7),
  sweatFrom: Offset(193.5, 39.4),
  sweatTo: Offset(193.9, 44.6),
);
const _kneelingFeatures = _Features(
  eyes: Offset(86.7, 105.3),
  leftEye: Offset(83.37, 106.04),
  rightEye: Offset(90.05, 104.49),
  leftBrow: Offset(83.06, 102.11),
  rightBrow: Offset(90.19, 99.25),
  mouthCorner: Offset(90.66, 108.2),
  mouthEnd: Offset(89.39, 110.54),
  cornerRise: Offset(.25, -.85),
  endRise: Offset(-.05, 0),
  bow: Offset(.31, .17),
  mouth: Offset(89.9, 109.5),
  mouthTilt: 0,
  openMouth: Size(1.7, 2.1),
  teeth: Size(2.1, 1.1),
  grin: Size(2.4, 1.6),
  tongue: Offset(89.05, 110.95),
  sweatFrom: Offset(95.6, 101.8),
  sweatTo: Offset(95.9, 107),
);

/// مواضع ملامح أحد العاملين في الرسم.
class _Features {
  const _Features({
    required this.eyes,
    required this.leftEye,
    required this.rightEye,
    required this.leftBrow,
    required this.rightBrow,
    required this.mouthCorner,
    required this.mouthEnd,
    required this.cornerRise,
    required this.endRise,
    required this.bow,
    required this.mouth,
    required this.mouthTilt,
    required this.openMouth,
    required this.teeth,
    required this.grin,
    required this.tongue,
    required this.sweatFrom,
    required this.sweatTo,
  });

  /// وسط العينين، وحوله تضيقان وتتسعان وتُغمضان، ووسط كل عين.
  final Offset eyes, leftEye, rightEye;

  /// وسط كل حاجب، وحوله يميل.
  final Offset leftBrow, rightBrow;

  /// طرف الفم الذي ترفعه الابتسامة، وطرفه الآخر.
  final Offset mouthCorner, mouthEnd;

  /// حركة الطرفين ووسط الفم مع كل زيادة في الابتسامة.
  final Offset cornerRise, endRise, bow;

  /// وسط الفم وميله على الوجه، ومقاس الفم مفتوحاً، والأسنان المضغوطة، والضحكة.
  final Offset mouth;
  final double mouthTilt;
  final Size openMouth, teeth, grin;

  /// طرف اللسان حين يخرج مع التركيز.
  final Offset tongue;

  /// من أين تنزل قطرة العرق وإلى أين.
  final Offset sweatFrom, sweatTo;

  /// موضع نقطة من الفم بعد أن تتغير الابتسامة.
  Offset smiled(Offset point, double smile) {
    final chord = mouthEnd - mouthCorner;
    final along = point - mouthCorner;
    final t = ((along.dx * chord.dx + along.dy * chord.dy) / chord.distanceSquared).clamp(0.0, 1.0);
    return point + (cornerRise * (1 - t) + endRise * t + bow * (4 * t * (1 - t))) * smile;
  }
}

/// ملامح أحد العاملين في لحظة. القيم كلها صفر هي وجهه كما في الرسم.
@immutable
class WorkerFace {
  const WorkerFace({
    this.browLift = 0,
    this.browKnit = 0,
    this.squint = 0,
    this.happy = 0,
    this.smile = 0,
    this.open = 0,
    this.teeth = 0,
    this.grin = 0,
    this.tongue = 0,
    this.sweat = 0,
    this.look = Offset.zero,
  });

  /// صعود الحاجبين بوحدات الرسم، والسالب نزولهما.
  final double browLift;

  /// نزول طرفي الحاجبين الداخليين مع الشد والتركيز، والسالب صعودهما مع القلق.
  final double browKnit;

  /// ضيق العينين: 1 مغمضتان من الشد، والسالب اتساعهما من المفاجأة.
  final double squint;

  /// العينان مغمضتان من الفرح كقوسين.
  final double happy;

  /// 0 ابتسامة الرسم، و-1 فم مستقيم، وتحته ينقلب إلى الأسفل، وفوق 0 ابتسامة أعرض.
  final double smile;

  /// الفم مفتوح كأنه يقول «ها».
  final double open;

  /// أسنان مضغوطة من الشد.
  final double teeth;

  /// ضحكة واسعة بعد أن يصلح.
  final double grin;

  /// طرف اللسان خارج الفم من التركيز.
  final double tongue;

  /// قطرة عرق على جبينه.
  final double sweat;

  /// اتجاه النظر بوحدات الرسم.
  final Offset look;

  static WorkerFace lerp(WorkerFace a, WorkerFace b, double t) => WorkerFace(
        browLift: ui.lerpDouble(a.browLift, b.browLift, t)!,
        browKnit: ui.lerpDouble(a.browKnit, b.browKnit, t)!,
        squint: ui.lerpDouble(a.squint, b.squint, t)!,
        happy: ui.lerpDouble(a.happy, b.happy, t)!,
        smile: ui.lerpDouble(a.smile, b.smile, t)!,
        open: ui.lerpDouble(a.open, b.open, t)!,
        teeth: ui.lerpDouble(a.teeth, b.teeth, t)!,
        grin: ui.lerpDouble(a.grin, b.grin, t)!,
        tongue: ui.lerpDouble(a.tongue, b.tongue, t)!,
        sweat: ui.lerpDouble(a.sweat, b.sweat, t)!,
        look: Offset.lerp(a.look, b.look, t)!,
      );
}

// وجوه الشغل: الشد على العجلة بأسنان مضغوطة وعينين مغمضتين ونفَسه بين الدفعات، والتركيز
// في الضبط ولسانه خارج فمه، والفرح بعد أن يصلح بعينين كقوسين وضحكة واسعة.
const _straining = WorkerFace(browLift: -.9, browKnit: .5, squint: 1, teeth: 1, look: Offset(.25, .2));
const _hardStraining =
    WorkerFace(browLift: -1.1, browKnit: .6, squint: 1, teeth: 1, sweat: 1, look: Offset(.25, .2));
const _breathing =
    WorkerFace(browLift: -.2, browKnit: .2, squint: .3, smile: -1, open: .55, look: Offset(.25, .2));
const _focused =
    WorkerFace(browLift: -.6, browKnit: .5, squint: .6, smile: -1, tongue: 1, look: Offset(-.3, .15));
const _pleased = WorkerFace(browLift: .9, browKnit: -.1, happy: 1, grin: 1);

/// وضع العاملين في لحظة. كل واحد يكرر قصة إصلاح: ينزل مؤشر عداده فينتبه، ثم يصلح
/// ويتعب، ثم يرجع المؤشر إلى علامته فيفرح، ثم يهدأ على شكله في الرسم.
class WorkersPose {
  const WorkersPose(this.time, [double? kneelingTime]) : kneelingTime = kneelingTime ?? time;

  /// ساعة العامل الواقف.
  final double time;

  /// ساعة العامل الجالس. كل منهما يرتاح بين حكاية وأخرى في وضعه الهادئ، فلكل منهما ساعته.
  final double kneelingTime;

  static const standingCycle = 9.0;
  static const kneelingCycle = 8.0;

  // ثلاث دفعات على العجلة، وبعد كل دفعة تفلت يداه وترجعان لتمسكاها من جديد. كل دفعة تدير
  // العجلة ضلعاً ونصفاً، فيتغير شكل أضلاعها بعدها ويُرى أنها دارت.
  static const _pushes = [(2.4, 3.3), (3.8, 4.7), (5.2, 6.3)];
  static const _regrip = .5;
  static const _turnPerPush = 1.5 * _spokeStep;

  // ثلاث لفات للعداد الصغير، وبعد كل لفة ترجع أصابعه لتمسكه من جديد.
  static const _twists = [(2.2, 2.7), (2.9, 3.4), (3.6, 4.1)];
  static const _release = .2;

  static const _standingFaces = [
    (0.0, WorkerFace()),
    (0.7, WorkerFace()),
    // يرى مؤشر العداد ينزل، فتتسع عيناه ويرتفع حاجباه ويقول «ها».
    (1.4, WorkerFace(browLift: .5, squint: -.3, look: Offset(.35, .05))),
    (1.9, WorkerFace(browLift: 1.3, browKnit: -.25, squint: -.6, smile: -1, open: 1, look: Offset(.35, .05))),
    (2.35, WorkerFace(browLift: -.4, browKnit: .35, squint: .5, smile: -1, look: Offset(.25, .2))),
    (2.85, _straining),
    (3.55, _breathing),
    (4.25, _straining),
    (4.95, _breathing),
    (5.6, _hardStraining),
    (6.3, _hardStraining),
    // ينظر إلى المؤشر وهو يرجع، ثم يفرح.
    (6.75, WorkerFace(browLift: .9, browKnit: -.15, squint: -.3, smile: -.6, open: .6, look: Offset(.35, .05))),
    (7.25, _pleased),
    (8.3, _pleased),
    (standingCycle, WorkerFace()),
  ];

  static const _kneelingFaces = [
    (0.0, WorkerFace()),
    (0.5, WorkerFace()),
    // ينزل إلى الجهاز في يده فيرى القراءة نزلت.
    (1.1, WorkerFace(browLift: -.4, browKnit: .35, squint: .5, smile: -1, look: Offset(-.2, .3))),
    (1.75, WorkerFace(browLift: 1.2, browKnit: -.25, squint: -.5, smile: -1, open: .9, look: Offset(-.2, .3))),
    (2.25, _focused),
    (4.05, _focused),
    // ينتظر العداد الكبير، ثم يفرح.
    (4.45, WorkerFace(browLift: .8, browKnit: -.15, squint: -.3, smile: -.6, open: .6, look: Offset(-.35, .05))),
    (4.95, _pleased),
    (6.4, _pleased),
    (kneelingCycle, WorkerFace()),
  ];

  // ميل الرأس: ينظر إلى العداد، ويرجعه حين يرى المؤشر نزل، ويهزه فرحاً في الآخر.
  static const _standingHeads = [
    (0.0, 0.0),
    (0.7, 0.0),
    (1.4, .02),
    (1.9, -.05),
    (2.35, .02),
    (6.3, .02),
    (6.75, .02),
    (7.1, .09),
    (7.35, .01),
    (7.6, .07),
    (7.85, .01),
    (standingCycle, 0.0),
  ];

  // ينزل رأسه إلى الجهاز ثم إلى العداد الصغير، ويرفعه إلى الكبير، ويهزه فرحاً.
  static const _kneelingHeads = [
    (0.0, 0.0),
    (0.5, 0.0),
    (1.1, -.08),
    (1.75, -.04),
    (2.25, -.06),
    (4.05, -.06),
    (4.45, .02),
    (4.85, -.08),
    (5.1, -.01),
    (5.35, -.07),
    (5.6, -.01),
    (kneelingCycle, 0.0),
  ];

  double get _standing => time % standingCycle;
  double get _kneeling => kneelingTime % kneelingCycle;

  double _wave(double period, [double shift = 0]) =>
      math.sin(2 * math.pi * time / period + shift);

  double _kneelingWave(double period) => math.sin(2 * math.pi * kneelingTime / period);

  /// إغماضة قصيرة في كل دورة: 1 مغمضتان.
  double _blink(double cycle, double at, [double? clock]) {
    final t = ((clock ?? time) % cycle) - at;
    if (t <= 0 || t >= .18) return 0;
    return math.sin(math.pi * t / .18);
  }

  /// تقدّم من 0 إلى 1 بين بداية ونهاية، يبدأ هادئاً وينتهي هادئاً.
  static double _progress(double t, double start, double end) =>
      Curves.easeInOut.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  /// كم تم من الحركات في الدورة حتى الآن، مع جزء الحركة الجارية.
  static double _done(double t, List<(double, double)> moves) =>
      moves.fold(0, (done, move) => done + _progress(t, move.$1, move.$2));

  /// قوة الحركة الجارية: تصل إلى 1 في آخرها، ثم ترجع إلى 0 واليد في مكانها من الرسم.
  static double _effort(double t, List<(double, double)> moves, double back) {
    for (final (start, end) in moves) {
      if (t >= start && t < end) return _progress(t, start, end);
      if (t >= end && t < end + back) return 1 - _progress(t, end, end + back);
    }
    return 0;
  }

  /// قيمة تمر بمحطات الدورة بنعومة.
  static T _through<T>(double t, List<(double, T)> stops, T Function(T, T, double) lerp) {
    for (var i = 1; i < stops.length; i++) {
      final (end, to) = stops[i];
      if (t <= end) {
        final (start, from) = stops[i - 1];
        return lerp(from, to, Curves.easeInOut.transform((t - start) / (end - start)));
      }
    }
    return stops.last.$2;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  // العامل الواقف.

  double get _grip => _effort(_standing, _pushes, _regrip);

  /// الدفعة الأخيرة أصعب: ترتجف فيها يداه قليلاً.
  double get _tremble {
    final (start, end) = _pushes.last;
    final t = _standing;
    if (t <= start || t >= end) return 0;
    return math.sin(math.pi * (t - start) / (end - start)) * math.sin(2 * math.pi * 11 * t);
  }

  double get _standingPleased =>
      _progress(_standing, 6.75, 7.25) - _progress(_standing, 8.3, standingCycle);

  /// دوران العجلة منذ البداية: كل دفعة تديرها، ولا ترجع أبداً.
  double get wheelTurn =>
      -_turnPerPush * (_pushes.length * (time ~/ standingCycle) + _done(_standing, _pushes));

  // اليدان تدوران مع حافة العجلة بعكس بعضهما في الدفعة، وجسمه يميل معهما قليلاً حتى لا تفلت
  // يده العليا من الحافة.
  double get _hold => _grip * (1 + .08 * _tremble);
  double get upperArm => .1 * _hold;
  double get lowerArm => -.09 * _hold;
  double get standingLean => .008 * _grip - .008 * _standingPleased + .003 * _wave(3.2);
  double get standingHead => _through(_standing, _standingHeads, _lerp) + .05 * _grip;

  /// نقص الضغط في عداده: 0 والمؤشر على علامته كما في الرسم، و1 في أدناه.
  /// يرتفع المؤشر بعد كل دفعة بلحظة.
  double get _standingDrop {
    final t = _standing;
    return _progress(t, .7, 1.9) * (1 - _done(t - .15, _pushes) / _pushes.length);
  }

  double get standingNeedle {
    final t = _standing - (_pushes.last.$2 + .15);
    final settle = t > 0 ? .14 * math.exp(-3.5 * t) * math.sin(11 * t) : 0.0;
    final drop = _standingDrop;
    return -1.05 * drop + settle + .025 * (1 - drop) * _wave(.9);
  }

  double get standingBlink => math.max(_blink(standingCycle, .35), _blink(standingCycle, 8.55));

  WorkerFace get standingFace => _through(_standing, _standingFaces, WorkerFace.lerp);

  /// قطرة العرق تنزل على وجهه في الدفعة الأخيرة.
  double get standingSweatFall => _progress(_standing, 5.3, 6.6);

  // العامل الجالس.

  double get _twist => _effort(_kneeling, _twists, _release);

  /// يرفع الجهاز إلى عينيه ليقرأه، ثم ينزله.
  double get _reading => _progress(_kneeling, .9, 1.3) - _progress(_kneeling, 1.9, 2.3);

  double get _kneelingPleased =>
      _progress(_kneeling, 4.45, 4.95) - _progress(_kneeling, 6.4, kneelingCycle);

  /// نقص الضغط عنده: العداد الصغير يتبع أصابعه، والكبير يتبعه بعد لحظة.
  double _kneelingDrop(double lag) {
    final t = _kneeling - lag;
    return _progress(t, .5, 1.8) * (1 - _done(t, _twists) / _twists.length);
  }

  // يرجع فرحاً ويتنفس، ولا يميل وهو يضبط حتى تبقى أصابعه على العداد.
  double get kneelingLean => .006 * _kneelingPleased + .003 * _kneelingWave(3.6);
  double get kneelingHead => _through(_kneeling, _kneelingHeads, _lerp);
  double get reachingArm => .02 * _twist;
  double get smallNeedle => -1.0 * _kneelingDrop(0);
  double get holdingArm => .045 * _reading + .006 * _kneelingWave(2.2);
  double get meterTilt => -.15 * _reading + .02 * _kneelingWave(2.2);

  double get tallNeedle {
    final t = _kneeling - (_twists.last.$2 + .3);
    final settle = t > 0 ? .14 * math.exp(-3.5 * t) * math.sin(11 * t) : 0.0;
    final drop = _kneelingDrop(.3);
    return -1.2 * drop + settle + .02 * (1 - drop) * _kneelingWave(1.3);
  }

  double get kneelingBlink =>
      math.max(_blink(kneelingCycle, .25, kneelingTime), _blink(kneelingCycle, 6.9, kneelingTime));

  WorkerFace get kneelingFace => _through(_kneeling, _kneelingFaces, WorkerFace.lerp);

  /// العامل الجالس لا يعرق، فلا تنزل عنده قطرة.
  double get kneelingSweatFall => 0;
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

/// ملامح أحد العاملين، تُرسم فوق وجهه وتتحرك. الفم يُحفظ نقاطاً أيضاً حتى تتغير ابتسامته.
class _FaceArt {
  _FaceArt({
    required List<ArtShape> eyes,
    required List<ArtShape> lids,
    required List<ArtShape> leftBrow,
    required List<ArtShape> rightBrow,
    required List<ArtShape> mouth,
  })  : eyes = WorkersArt._record(eyes),
        lids = WorkersArt._record(lids),
        leftBrow = WorkersArt._record(leftBrow),
        rightBrow = WorkersArt._record(rightBrow),
        mouth = WorkersArt._record(mouth),
        mouthOutline = [
          for (final shape in mouth)
            (
              Color(shape.color),
              [
                for (final contour in parseSvgPath(shape.path).computeMetrics())
                  [
                    for (var at = 0.0; at < contour.length; at += .04)
                      contour.getTangentForOffset(at)!.position,
                  ],
              ],
            ),
        ];

  final ui.Picture eyes, lids, leftBrow, rightBrow, mouth;
  final List<(Color, List<List<Offset>>)> mouthOutline;

  void dispose() {
    for (final picture in [eyes, lids, leftBrow, rightBrow, mouth]) {
      picture.dispose();
    }
  }
}

/// طبقات الرسم مرة واحدة، وصورها بمقاس الشاشة.
class WorkersArt {
  WorkersArt()
      : _backdrop = _ArtLayer(workersBackdrop),
        _standingHead = _ArtLayer(workersStandingHead),
        _standingHeadTop = _ArtLayer(workersStandingHeadTop),
        _upperArm = _ArtLayer(workersUpperArm),
        _wheelRim = _ArtLayer(workersWheelRim),
        _standingBody = _ArtLayer(workersStandingBody),
        _lowerArm = _ArtLayer(workersLowerArm),
        _standingCollar = _ArtLayer(workersStandingCollar),
        _kneelingHead = _ArtLayer(workersKneelingHead),
        _kneelingHeadTop = _ArtLayer(workersKneelingHeadTop),
        _palm = _ArtLayer(workersPalm),
        _smallDial = _ArtLayer(workersSmallDial),
        _reachingArm = _ArtLayer(workersReachingArm),
        _kneelingBody = _ArtLayer(workersKneelingBody),
        _meter = _ArtLayer(workersMeter),
        _holdingArm = _ArtLayer(workersHoldingArm),
        _kneelingCollar = _ArtLayer(workersKneelingCollar),
        _standingFace = _FaceArt(
          eyes: workersStandingEyes,
          lids: workersStandingLids,
          leftBrow: workersStandingLeftBrow,
          rightBrow: workersStandingRightBrow,
          mouth: workersStandingMouth,
        ),
        _kneelingFace = _FaceArt(
          eyes: workersKneelingEyes,
          lids: workersKneelingLids,
          leftBrow: workersKneelingLeftBrow,
          rightBrow: workersKneelingRightBrow,
          mouth: workersKneelingMouth,
        ),
        _standingNeedleArt = _record(workersStandingNeedle),
        _smallNeedleArt = _record(workersSmallNeedle),
        _tallNeedleArt = _record(workersTallNeedle);

  final _ArtLayer _backdrop, _standingHead, _standingHeadTop, _upperArm, _wheelRim, _standingBody;
  final _ArtLayer _lowerArm, _standingCollar, _kneelingHead, _kneelingHeadTop, _palm, _smallDial;
  final _ArtLayer _reachingArm, _kneelingBody, _meter, _holdingArm, _kneelingCollar;
  final _FaceArt _standingFace, _kneelingFace;
  final ui.Picture _standingNeedleArt, _smallNeedleArt, _tallNeedleArt;

  Offset _origin = Offset.zero;
  double _unit = 0;
  double _pixelRatio = 0;

  List<_ArtLayer> get _layers => [
        _backdrop, _standingHead, _standingHeadTop, _upperArm, _wheelRim, _standingBody, _lowerArm,
        _standingCollar, _kneelingHead, _kneelingHeadTop, _palm, _smallDial, _reachingArm,
        _kneelingBody, _meter, _holdingArm, _kneelingCollar,
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
    _standingFace.dispose();
    _kneelingFace.dispose();
    for (final picture in [_standingNeedleArt, _smallNeedleArt, _tallNeedleArt]) {
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

/// عاملان يصلحان الأنابيب، والأنابيب تكمل إلى حافتي الشاشة.
class WorkersScene extends StatefulWidget {
  const WorkersScene({super.key, required this.scale, this.left = 0});

  /// نسبة عرض الشاشة إلى عرض التصميم.
  final double scale;

  /// بُعد الصفحة عن يسار الشاشة حين تتوسطها.
  final double left;

  @override
  State<WorkersScene> createState() => _WorkersSceneState();
}

// كل عامل يمثل حكايته مرة حين تظهر الرئيسية أو تُلمس، ثم يرتاح في وضعه الهادئ الذي تبدأ وتنتهي به
// حكايته. وهما مرتاحان لا يُرسم شيء، فلا تبقى الرئيسية تشغّل المعالج وهي ساكنة (طلب المستخدم:
// «تقلل حركه العمال»). كانت الحركة دائمة، فبقي المعالج مشغولاً نحو 70% طول بقاء الرئيسية.
class _WorkersSceneState extends State<WorkersScene> with SingleTickerProviderStateMixin {
  final _art = WorkersArt();

  /// ساعتا العامل الواقف والعامل الجالس.
  final _time = ValueNotifier<(double, double)>((0, 0));
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  /// طُلب من كل عامل مرتاح أن يمثل حكايته مرة.
  bool _wanted = false;
  bool _shown = false;
  bool _reduceMotion = false;

  /// ساعة عامل بعد خطوة: تمشي حتى آخر حكايته ثم تقف عليه، ولا تبدأ من جديد إلا إذا طُلب ذلك.
  static double _advance(double clock, double step, double cycle, bool start) {
    if (clock % cycle == 0 && !start) return clock;
    return math.min(clock + step, (clock ~/ cycle + 1) * cycle);
  }

  void _onTick(Duration elapsed) {
    final step = steadyStep(elapsed - _lastTick);
    _lastTick = elapsed;
    if (step == 0) return;
    final (standing, kneeling) = _time.value;
    final start = _wanted;
    _wanted = false;
    final next = (
      _advance(standing, step, WorkersPose.standingCycle, start),
      _advance(kneeling, step, WorkersPose.kneelingCycle, start),
    );
    _time.value = next;
    if (next.$1 % WorkersPose.standingCycle == 0 && next.$2 % WorkersPose.kneelingCycle == 0) {
      _ticker.stop();
    }
  }

  void _wake() {
    if (_reduceMotion || !_shown) return;
    _wanted = true;
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) _wake();
  }

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    // تبويب مخفي أو صفحة فوق الرئيسية تعطّل حركتها، فلا يوقظها لمس تلك الصفحات.
    final shown = TickerMode.valuesOf(context).enabled;
    final appeared = shown && !_shown;
    _shown = shown;
    if (_reduceMotion) {
      if (_ticker.isActive) _ticker.stop();
    } else if (appeared) {
      _wake();
    }
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _ticker.dispose();
    _time.dispose();
    _art.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: tr('عاملان من جايك يصلحان أنابيب: واحد يدير الصمام والآخر يضبط العداد', 'Two Jaik workers fixing pipes: one turns the valve and the other adjusts the meter'),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: WorkersScenePainter(
            art: _art,
            time: _time,
            scale: widget.scale,
            left: widget.left,
            pixelRatio: MediaQuery.devicePixelRatioOf(context),
            night: Theme.of(context).brightness == Brightness.dark,
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
    this.night = false,
  }) : super(repaint: time);

  final WorkersArt art;

  /// ساعتا العامل الواقف والعامل الجالس.
  final ValueListenable<(double, double)> time;
  final double scale;
  final double left;
  final double pixelRatio;

  /// خط الأرض الداكن يضيع ليلاً، فيصير أبيض ليظهر العاملان واقفين عليه.
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final (standing, kneeling) = time.value;
    final pose = WorkersPose(standing, kneeling);
    final unit = scale * _artScale;
    final origin = Offset(left + _artLeft * scale, 0);
    art._prepare(origin, unit, pixelRatio);
    canvas
      ..save()
      ..translate(origin.dx, origin.dy)
      ..scale(unit);
    _paintPipeEnds(canvas, -origin.dx / unit, (size.width - origin.dx) / unit, unit);
    art._backdrop.paint(canvas);
    _paintSpokes(canvas, pose.wheelTurn);
    _paintStanding(canvas, pose);
    _paintKneeling(canvas, pose);
    canvas.restore();
  }

  /// الأنابيب وخط الأرض من طرفيها في الرسم إلى حافتي الشاشة.
  void _paintPipeEnds(Canvas canvas, double left, double right, double unit) {
    final pipe = Paint()..color = _pipeInk;
    final pale = Paint()..color = _paleInk;
    double high(double x) => 128.547 + (x - 6.95) * _pipeSlope;
    double low(double x) => 161.816 + (x - 6.66) * _pipeSlope;
    // خط الأرض أرفع من بكسل، فيظهر الأبيض ليلاً رمادياً باهتاً؛ ليلاً سُمكه بكسلان على الأقل.
    final groundBottom = night
        ? 195.3 + math.max(.216, 2 / (unit * pixelRatio))
        : 195.516;
    canvas
      ..drawRect(
        Rect.fromLTRB(left, 195.3, right, groundBottom),
        Paint()..color = night ? Colors.white : _groundInk,
      )
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

  /// أضلاع العجلة بعد أن دارت: أطرافها تنزلق على حافتها الخلفية.
  void _paintSpokes(Canvas canvas, double turn) {
    final paint = Paint()
      ..strokeWidth = _spokeWidth
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < _spokeCount; i++) {
      final angle = (math.pi / 2 + i * _spokeStep + turn) % (2 * math.pi);
      final shown = ((math.min(angle, math.pi - angle) - .32) / .25).clamp(0.0, 1.0);
      if (shown == 0) continue;
      paint.color = _spokeInk.withValues(alpha: shown);
      canvas.drawLine(
        _wheelHub,
        Offset(
          _spokeRing.dx - _spokeRingRadii.width * math.sin(angle),
          _spokeRing.dy - _spokeRingRadii.height * math.cos(angle),
        ),
        paint,
      );
    }
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

  void _paintFace(Canvas canvas, _FaceArt face, _Features at, WorkerFace look, double blink) {
    // العينان تضيقان مع الشد حتى تُغمضا، وتتسعان مع المفاجأة، وتُغمضان لحظة، وتصيران قوسين مع
    // الفرح، وتنظران إلى ما يشتغل عليه.
    final open = (1 - .55 * look.squint) * (1 - .85 * blink) * (1 - look.happy);
    if (open > .02) {
      canvas
        ..save()
        ..translate(at.eyes.dx + look.look.dx, at.eyes.dy + look.look.dy)
        ..scale(1, open)
        ..translate(-at.eyes.dx, -at.eyes.dy)
        ..drawPicture(face.eyes)
        ..restore();
    }
    if (look.happy > 0) {
      final arc = Paint()
        ..color = _featureInk.withValues(alpha: look.happy)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .45
        ..strokeCap = StrokeCap.round;
      for (final eye in [at.leftEye, at.rightEye]) {
        canvas.drawPath(
          Path()
            ..moveTo(eye.dx - .95, eye.dy + .35)
            ..quadraticBezierTo(eye.dx, eye.dy - .85, eye.dx + .95, eye.dy + .35),
          arc,
        );
      }
    }
    // خطا الجفنين ينزلان مع ضيق العينين ويصعدان مع الحاجبين.
    canvas
      ..save()
      ..translate(0, .5 * math.max(look.squint, 0) - .35 * look.browLift)
      ..drawPicture(face.lids)
      ..restore();
    _paintMouth(canvas, face, at, look);
    // الحاجبان يصعدان وينزلان، وطرفاهما الداخليان ينزلان مع العبوس.
    for (final (center, brow, tilt) in [
      (at.leftBrow, face.leftBrow, look.browKnit),
      (at.rightBrow, face.rightBrow, -look.browKnit),
    ]) {
      canvas
        ..save()
        ..translate(0, -look.browLift);
      _turnAround(canvas, center, tilt);
      canvas
        ..drawPicture(brow)
        ..restore();
    }
  }

  void _paintMouth(Canvas canvas, _FaceArt face, _Features at, WorkerFace look) {
    // فم الرسم يختفي حين تظهر الأسنان المضغوطة أو الضحكة مكانه.
    final line = 1.0 - math.max(look.teeth, look.grin);
    if (line > 0) {
      canvas.save();
      if (look.open > 0) {
        // الفم يضيق وهو ينفتح، كأنه يقول «ها».
        canvas
          ..translate(at.mouth.dx, at.mouth.dy)
          ..scale(1 - .7 * look.open, 1)
          ..translate(-at.mouth.dx, -at.mouth.dy);
      }
      if (look.smile == 0 && line == 1) {
        canvas.drawPicture(face.mouth);
      } else {
        final paint = Paint();
        for (final (color, contours) in face.mouthOutline) {
          final path = Path();
          for (final points in contours) {
            path.addPolygon([for (final point in points) at.smiled(point, look.smile)], true);
          }
          canvas.drawPath(path, paint..color = color.withValues(alpha: color.a * line));
        }
      }
      canvas.restore();
    }
    if (look.open > 0) {
      canvas.drawOval(
        Rect.fromCenter(
          center: at.mouth,
          width: at.openMouth.width * look.open,
          height: at.openMouth.height * look.open,
        ),
        Paint()..color = _featureInk.withValues(alpha: line),
      );
    }
    if (look.tongue > 0) {
      canvas.drawOval(
        Rect.fromCenter(center: at.tongue, width: .95, height: .75),
        Paint()..color = _tongueInk.withValues(alpha: look.tongue),
      );
    }
    if (look.teeth == 0 && look.grin == 0) return;
    canvas
      ..save()
      ..translate(at.mouth.dx, at.mouth.dy)
      ..rotate(at.mouthTilt);
    if (look.teeth > 0) {
      final teeth = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: at.teeth.width, height: at.teeth.height),
        Radius.circular(at.teeth.height * .4),
      );
      final ink = Paint()
        ..color = _featureInk.withValues(alpha: look.teeth)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .26;
      canvas
        ..drawRRect(teeth, Paint()..color = _teethInk.withValues(alpha: look.teeth))
        ..drawRRect(teeth, ink)
        ..drawLine(Offset(-at.teeth.width / 2 + .2, 0), Offset(at.teeth.width / 2 - .2, 0), ink..strokeWidth = .18);
    }
    if (look.grin > 0) {
      final w = at.grin.width, h = at.grin.height;
      final grin = Path()
        ..moveTo(-w / 2, -h / 2)
        ..lineTo(w / 2, -h / 2)
        ..arcToPoint(Offset(-w / 2, -h / 2), radius: Radius.elliptical(w / 2, h))
        ..close();
      canvas
        ..drawPath(grin, Paint()..color = _featureInk.withValues(alpha: look.grin))
        ..save()
        ..clipPath(grin)
        ..drawOval(
          Rect.fromCenter(center: Offset(0, h * .32), width: w * .55, height: h * .5),
          Paint()..color = _tongueInk.withValues(alpha: look.grin),
        )
        ..restore();
    }
    canvas.restore();
  }

  /// قطرة عرق تنزل على وجهه وهو يشد.
  void _paintSweat(Canvas canvas, _Features at, double shown, double fall) {
    if (shown <= 0) return;
    final place = Offset.lerp(at.sweatFrom, at.sweatTo, fall)!;
    final drop = Path()
      ..moveTo(0, -1.15)
      ..cubicTo(.35, -.6, .65, -.15, .65, .3)
      ..arcToPoint(const Offset(-.65, .3), radius: const Radius.circular(.65))
      ..cubicTo(-.65, -.15, -.35, -.6, 0, -1.15)
      ..close();
    canvas
      ..save()
      ..translate(place.dx, place.dy)
      ..drawPath(drop, Paint()..color = _sweatInk.withValues(alpha: shown))
      ..drawPath(
        drop,
        Paint()
          ..color = _sweatEdge.withValues(alpha: shown)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .14,
      )
      ..restore();
  }

  void _paintStanding(Canvas canvas, WorkersPose pose) {
    final face = pose.standingFace;
    canvas.save();
    _turnAround(canvas, _waist, pose.standingLean);
    canvas.save();
    _turnAround(canvas, _standingNeck, pose.standingHead);
    art._standingHead.paint(canvas);
    _paintFace(canvas, art._standingFace, _standingFeatures, face, pose.standingBlink);
    art._standingHeadTop.paint(canvas);
    _paintSweat(canvas, _standingFeatures, face.sweat, pose.standingSweatFall);
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
    final face = pose.kneelingFace;
    canvas.save();
    _turnAround(canvas, _hip, pose.kneelingLean);
    canvas.save();
    _turnAround(canvas, _kneelingNeck, pose.kneelingHead);
    art._kneelingHead.paint(canvas);
    _paintFace(canvas, art._kneelingFace, _kneelingFeatures, face, pose.kneelingBlink);
    art._kneelingHeadTop.paint(canvas);
    _paintSweat(canvas, _kneelingFeatures, face.sweat, pose.kneelingSweatFall);
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
      oldDelegate.pixelRatio != pixelRatio ||
      oldDelegate.night != night;
}
