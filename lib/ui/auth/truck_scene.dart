import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'truck_art.dart';

/// مقاسات المشهد كما في التصميم المعتمد (إطار عرضه 391 بكسل).
abstract final class TruckSceneMetrics {
  static const designWidth = 391.0;

  /// نسبة الرسم من وحدات ملف SVG إلى بكسلات التصميم.
  static const artScale = .45114;

  /// مركز الرسم عمودياً كنسبة من ارتفاع المنطقة الزرقاء.
  static const artCenterFraction = 244.8 / 414.3;

  static const curveRadiusX = 199.0;
  static const curveRadiusY = 36.0;
}

const _blue = Color(0xFF416F9E);
const _ink = Color(0xFF263238);
const _cabInterior = Color(0xFF2F3E46);
const _glass = Color(0xFF455A64);
const _glassEdge = Color(0xFF6B8290);
const _skin = Color(0xFFFFBE9D);
const _skinShade = Color(0xFFEB996E);

// حدود الزجاج المتحرك: جزء النافذة خلف العمود كما هو في ملف SVG.
const _doorWindow =
    'M125.74,213.54c9.37-2.81,36.31-6.23,74.23-8.4h.36a6.16,6.16,0,0,1,6.14,6.15v46.5'
    'a5.65,5.65,0,0,1-3.66,5.27l-66.71,8.23a18.57,18.57,0,0,0-13.25,8.24L119,282Z';

// اليد تخرج من خلف حافة النافذة السفلى فلا يظهر ما تحتها.
const _aboveSill =
    'M60,150L240,150L240,259.5L206.47,258.5L202.81,263.06L136.1,271.29'
    'a18.57,18.57,0,0,0-13.25,8.24L111.29,297.16L60,297.16Z';

const _forearm = 'M9,-7C19,3 31,20 44,42L28,53C19,36 9,23 0,13Z';
const _fist =
    'M-14,-7C-14,-11 -11,-13 -7,-13L5,-13C11,-13 15,-8 15,-2L15,6C15,12 10,15 4,15'
    'L-8,15C-12,15 -15,12 -15,8Z';
const _thumb = 'M-6,-11C-8,-18 -8,-24 -5,-28C-3,-31 3,-31 4.5,-27C6,-22 6,-17 9,-11Z';
const _fingerLines = <String>[
  'M-14.5,-5.5L1,-5.5',
  'M-15,1L1.5,1',
  'M-14.5,7.5L1,7.5',
  'M1,-12C3.5,-6 3.5,8 1,14.5',
];
const _thumbCrease = 'M-5.5,-11.5L7.5,-11.5';

const _frontWheelCenter = Offset(190.35, 414.17);
const _rearWheelCenter = Offset(544.45, 414.17);
const _wheelRadius = 47.94;

const _groundSpeed = 150.0;
const _buildingSpeed = 62.0;
const _cloudSpeed = 15.0;
const _stripPeriod = 900.0;

/// حركة السائق: النافذة تنزل، اليد ترتفع بعلامة الإعجاب، ثم يعود كل شيء.
class DriverPose {
  const DriverPose({required this.window, required this.hand, required this.pulse, required this.nod});

  /// الوضعية الثابتة عند تعطيل الحركات من إعدادات الجهاز.
  static const still = DriverPose(window: 1, hand: 1, pulse: 0, nod: 0);

  static const loop = 11.0;

  factory DriverPose.at(double time) {
    final t = time % loop;
    final down = Curves.easeInOut.transform(_progress(t, 1.2, 2.1));
    final up = Curves.easeInOut.transform(_progress(t, 6.7, 7.6));
    final show = Curves.easeOutBack.transform(_progress(t, 2.2, 2.8));
    final hide = Curves.easeIn.transform(_progress(t, 5.7, 6.3));
    final hold = _progress(t, 3.0, 5.4);
    return DriverPose(
      window: down - up,
      hand: show - hide,
      pulse: hold > 0 && hold < 1 ? math.sin(hold * math.pi * 3).abs() : 0,
      nod: hold > 0 && hold < 1 ? math.sin(hold * math.pi * 4) * math.sin(hold * math.pi) : 0,
    );
  }

  final double window;
  final double hand;
  final double pulse;
  final double nod;

  static double _progress(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);
}

/// قارئ مصغّر لمسارات SVG (كل أوامر المسار، بما فيها الأقواس والمنحنيات الناعمة).
Path parseSvgPath(String data) {
  final path = Path();
  final reader = _PathReader(data);
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  var controlX = 0.0, controlY = 0.0;
  var previous = '';
  var command = '';

  while (reader.hasMore) {
    if (reader.atCommand) command = reader.command();
    final relative = command == command.toLowerCase();
    final dx = relative ? x : 0.0;
    final dy = relative ? y : 0.0;

    switch (command.toUpperCase()) {
      case 'M':
        x = reader.number() + dx;
        y = reader.number() + dy;
        startX = x;
        startY = y;
        path.moveTo(x, y);
        command = relative ? 'l' : 'L';
      case 'L':
        x = reader.number() + dx;
        y = reader.number() + dy;
        path.lineTo(x, y);
      case 'H':
        x = reader.number() + dx;
        path.lineTo(x, y);
      case 'V':
        y = reader.number() + dy;
        path.lineTo(x, y);
      case 'C':
        final x1 = reader.number() + dx, y1 = reader.number() + dy;
        controlX = reader.number() + dx;
        controlY = reader.number() + dy;
        x = reader.number() + dx;
        y = reader.number() + dy;
        path.cubicTo(x1, y1, controlX, controlY, x, y);
      case 'S':
        final smooth = previous == 'C' || previous == 'S';
        final x1 = smooth ? 2 * x - controlX : x, y1 = smooth ? 2 * y - controlY : y;
        controlX = reader.number() + dx;
        controlY = reader.number() + dy;
        x = reader.number() + dx;
        y = reader.number() + dy;
        path.cubicTo(x1, y1, controlX, controlY, x, y);
      case 'Q':
        controlX = reader.number() + dx;
        controlY = reader.number() + dy;
        x = reader.number() + dx;
        y = reader.number() + dy;
        path.quadraticBezierTo(controlX, controlY, x, y);
      case 'T':
        final smooth = previous == 'Q' || previous == 'T';
        controlX = smooth ? 2 * x - controlX : x;
        controlY = smooth ? 2 * y - controlY : y;
        x = reader.number() + dx;
        y = reader.number() + dy;
        path.quadraticBezierTo(controlX, controlY, x, y);
      case 'A':
        final radiusX = reader.number(), radiusY = reader.number();
        final rotation = reader.number();
        final largeArc = reader.flag(), clockwise = reader.flag();
        x = reader.number() + dx;
        y = reader.number() + dy;
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(radiusX, radiusY),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: clockwise,
        );
      case 'Z':
        path.close();
        x = startX;
        y = startY;
        command = '';
    }
    previous = command.toUpperCase();
  }
  return path;
}

class _PathReader {
  _PathReader(this.source);

  final String source;
  var _index = 0;

  bool get hasMore {
    _skipSeparators();
    return _index < source.length;
  }

  bool get atCommand {
    _skipSeparators();
    final code = source.codeUnitAt(_index);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  String command() => source[_index++];

  bool flag() {
    _skipSeparators();
    return source[_index++] == '1';
  }

  double number() {
    _skipSeparators();
    final start = _index;
    if (source[_index] == '-' || source[_index] == '+') _index++;
    var seenDot = false;
    while (_index < source.length) {
      final char = source[_index];
      if (char == '.') {
        if (seenDot) break;
        seenDot = true;
      } else if (char.codeUnitAt(0) < 48 || char.codeUnitAt(0) > 57) {
        break;
      }
      _index++;
    }
    return double.parse(source.substring(start, _index));
  }

  void _skipSeparators() {
    while (_index < source.length && (source[_index] == ',' || source[_index] == ' ')) {
      _index++;
    }
  }
}

/// طبقة ثابتة تُحوَّل إلى صورة بدقة الشاشة، فلا تُعاد مساراتها مع كل إطار.
class RasterLayer {
  RasterLayer(this.picture, this.bounds);

  final ui.Picture picture;
  final Rect bounds;
  ui.Image? _image;
  double _resolution = 0;

  void paint(Canvas canvas, double resolution) {
    if (resolution != _resolution) _rasterize(resolution);
    final image = _image!;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(bounds.left, bounds.top, image.width / resolution, image.height / resolution),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  void _rasterize(double resolution) {
    _image?.dispose();
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..scale(resolution)
      ..translate(-bounds.left, -bounds.top)
      ..drawPicture(picture);
    final scaled = recorder.endRecording();
    _image = scaled.toImageSync(
      (bounds.width * resolution).ceil(),
      (bounds.height * resolution).ceil(),
    );
    scaled.dispose();
    _resolution = resolution;
  }

  void dispose() {
    _image?.dispose();
    picture.dispose();
  }
}

/// طبقات الرسم مسجّلة مرة واحدة حتى لا يُعاد بناؤها مع كل إطار.
class TruckArt {
  TruckArt() {
    clouds = RasterLayer(_record(artClouds), const Rect.fromLTRB(41, 41, 726, 182));
    buildings = RasterLayer(_record(artBuildings), const Rect.fromLTRB(32, 36, 734, 464));
    plants = RasterLayer(_record(artPlants), const Rect.fromLTRB(310, 391, 662, 464));
    body = RasterLayer(
      _record([...artTruckBody, ...artTruckLabel, ...artTruckHighlights]),
      const Rect.fromLTRB(45, 96, 644, 429),
    );
    truckBack = _record(artTruckBack);
    cabGlass = _record(artCabGlass);
    pillar = _record(artTruckPillar);
    frontWheel = _record(artFrontWheel);
    rearWheel = _record(artRearWheel);
    rearGuard = _record(artRearGuard);
    torso = _record(artDriverTorso);
    head = _record(artDriverHead);
    streaks = _record(artGlassStreaks);
    hand = _recordWith(_paintHand);
    doorWindow = parseSvgPath(_doorWindow);
    aboveSill = parseSvgPath(_aboveSill);
  }

  late final RasterLayer clouds, buildings, plants, body;
  late final ui.Picture truckBack, cabGlass, pillar, frontWheel, rearWheel, rearGuard;
  late final ui.Picture torso, head, streaks, hand;
  late final Path doorWindow, aboveSill;

  void dispose() {
    for (final layer in [clouds, buildings, plants, body]) {
      layer.dispose();
    }
    for (final picture in [
      truckBack, cabGlass, pillar, frontWheel, rearWheel, rearGuard, torso, head, streaks, hand,
    ]) {
      picture.dispose();
    }
  }

  static ui.Picture _record(List<ArtShape> shapes) =>
      _recordWith((canvas) => _paintShapes(canvas, shapes));

  static ui.Picture _recordWith(void Function(Canvas) paint) {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder));
    return recorder.endRecording();
  }

  static void _paintShapes(Canvas canvas, List<ArtShape> shapes) {
    final paint = Paint()..isAntiAlias = true;
    for (final shape in shapes) {
      paint.color = Color(shape.color);
      canvas.drawPath(parseSvgPath(shape.path), paint);
    }
  }

  static void _paintHand(Canvas canvas) {
    final skin = Paint()
      ..color = _skin
      ..isAntiAlias = true;
    final crease = Paint()
      ..color = _skinShade
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..isAntiAlias = true;
    canvas
      ..drawPath(parseSvgPath(_forearm), skin)
      ..drawPath(parseSvgPath(_thumb), skin)
      ..drawPath(parseSvgPath(_fist), skin)
      ..drawPath(parseSvgPath(_thumbCrease), crease);
    for (final line in _fingerLines) {
      canvas.drawPath(parseSvgPath(line), crease);
    }
  }
}

/// المشهد المتحرك: الشاحنة تسير والغيوم والبنايات تمر خلفها، والسائق يحيّي بالإبهام.
class TruckScene extends StatefulWidget {
  const TruckScene({super.key, required this.scale});

  final double scale;

  @override
  State<TruckScene> createState() => _TruckSceneState();
}

class _TruckSceneState extends State<TruckScene> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  final _art = TruckArt();
  late final Ticker _ticker = createTicker((elapsed) {
    _time.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  });
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
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
      label: 'شاحنة جايك تسير وسائقها يرفع إبهامه من النافذة',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: TruckScenePainter(
            art: _art,
            time: _time,
            scale: widget.scale,
            pixelRatio: MediaQuery.devicePixelRatioOf(context),
            still: _still,
          ),
        ),
      ),
    );
  }
}

class TruckScenePainter extends CustomPainter {
  TruckScenePainter({
    required this.art,
    required this.time,
    required this.scale,
    required this.pixelRatio,
    this.still = false,
  }) : super(repaint: time);

  final TruckArt art;
  final ValueListenable<double> time;
  final double scale;
  final double pixelRatio;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final t = still ? 0.0 : time.value;
    final pose = still ? DriverPose.still : DriverPose.at(t);

    final widthRatio = size.width / TruckSceneMetrics.designWidth;
    final radiusX = TruckSceneMetrics.curveRadiusX * widthRatio;
    final radiusY = TruckSceneMetrics.curveRadiusY * scale;
    final background = Path()
      ..addRect(Rect.fromLTRB(0, 0, size.width, size.height - radiusY))
      ..addOval(Rect.fromCenter(
        center: Offset(size.width / 2, size.height - radiusY),
        width: radiusX * 2,
        height: radiusY * 2,
      ));
    canvas.drawPath(background, Paint()..color = _blue);

    final unit = TruckSceneMetrics.artScale * scale;
    final centerY = size.height * TruckSceneMetrics.artCenterFraction;
    canvas
      ..save()
      ..translate(size.width / 2 - 375 * unit, centerY - 250.5 * unit)
      ..scale(unit);
    final viewLeft = 375 - size.width / 2 / unit;
    final viewRight = 375 + size.width / 2 / unit;
    final resolution = unit * pixelRatio;

    void strip(RasterLayer layer, double speed) {
      final offset = (t * speed) % _stripPeriod;
      final first = ((viewLeft - layer.bounds.right - offset) / _stripPeriod).ceil();
      final last = ((viewRight - layer.bounds.left - offset) / _stripPeriod).floor();
      for (var i = first; i <= last; i++) {
        canvas
          ..save()
          ..translate(offset + i * _stripPeriod, 0);
        layer.paint(canvas, resolution);
        canvas.restore();
      }
    }

    strip(art.clouds, _cloudSpeed);
    strip(art.buildings, _buildingSpeed);
    canvas.drawRect(
      Rect.fromLTRB(viewLeft, 462.25, viewRight, 462.77),
      Paint()..color = _ink,
    );
    strip(art.plants, _groundSpeed);

    _truck(canvas, t, pose, resolution);
    canvas.restore();
  }

  void _truck(Canvas canvas, double t, DriverPose pose, double resolution) {
    final sway = 5 * math.sin(2 * math.pi * t / 7);
    final bounce = .8 * math.sin(2 * math.pi * 1.7 * t) + .35 * math.sin(2 * math.pi * 3.1 * t);
    // تسير الشاحنة إلى اليسار، فتدور العجلات عكس عقارب الساعة.
    final spin = -t * _groundSpeed / _wheelRadius;

    canvas
      ..save()
      ..translate(sway, 0)
      ..save()
      ..translate(0, bounce)
      ..drawPicture(art.truckBack)
      ..drawPicture(art.cabGlass);
    _cab(canvas, pose);
    canvas
      ..drawPicture(art.pillar)
      ..restore();

    _wheel(canvas, art.frontWheel, _frontWheelCenter, spin);
    canvas
      ..save()
      ..translate(0, bounce);
    art.body.paint(canvas, resolution);
    canvas.restore();
    _wheel(canvas, art.rearWheel, _rearWheelCenter, spin);

    canvas
      ..save()
      ..translate(0, bounce)
      ..drawPicture(art.rearGuard);
    _hand(canvas, pose);
    canvas
      ..restore()
      ..restore();
  }

  void _wheel(Canvas canvas, ui.Picture wheel, Offset center, double angle) {
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..translate(-center.dx, -center.dy)
      ..drawPicture(wheel)
      ..restore();
  }

  void _cab(Canvas canvas, DriverPose pose) {
    canvas
      ..save()
      ..clipPath(art.doorWindow)
      ..drawPath(art.doorWindow, Paint()..color = _cabInterior);

    // السائق: رأسه وكتفاه من شخصية الملف الأصلي، معكوسان ليواجه طريق الشاحنة.
    const neck = Offset(670, 283);
    canvas
      ..save()
      ..translate(180, 236)
      ..scale(-1.15, 1.15)
      ..translate(-670, -258)
      ..save()
      ..translate(neck.dx, neck.dy)
      ..rotate(pose.nod * .07)
      ..translate(-neck.dx, -neck.dy)
      ..drawPicture(art.head)
      ..restore()
      ..drawPicture(art.torso)
      ..restore();

    // الزجاج ينزل داخل الباب، وشفافيته تُظهر السائق خلفه قليلاً.
    if (pose.window < 1) {
      canvas
        ..save()
        ..translate(0, pose.window * 74)
        ..drawPath(art.doorWindow, Paint()..color = _glass.withValues(alpha: .86));
      if (pose.window > 0) {
        canvas.drawPath(
          art.doorWindow,
          Paint()
            ..color = _glassEdge
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      canvas
        ..drawPicture(art.streaks)
        ..restore();
    }
    canvas.restore();
  }

  void _hand(Canvas canvas, DriverPose pose) {
    if (pose.hand <= 0) return;
    final hidden = 1 - pose.hand;
    final pump = .9 + pose.pulse * .07;
    canvas
      ..save()
      ..clipPath(art.aboveSill)
      ..translate(141 + hidden * 26, 241 + hidden * 50)
      ..scale(pump)
      ..rotate(-pose.pulse * .05)
      ..drawPicture(art.hand)
      ..restore();
  }

  @override
  bool shouldRepaint(TruckScenePainter oldDelegate) =>
      oldDelegate.scale != scale ||
      oldDelegate.pixelRatio != pixelRatio ||
      oldDelegate.still != still ||
      oldDelegate.art != art;
}
