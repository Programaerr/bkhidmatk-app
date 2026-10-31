import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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

// السيارة تقف على خط الأرض نفسه، ومعكوسة أفقياً لتتجه إلى اليسار.
const _vanScale = .951;
const _vanOrigin = Offset(46 + 695.42 * _vanScale, 462.5 - 320.35 * _vanScale);
const _vanBounds = Rect.fromLTRB(20, -2, 700, 286);

const _rearWheelCenter = Offset(156.23, 270.3);
const _frontWheelCenter = Offset(597.33, 270.3);
const _wheelRadius = 50.45 * _vanScale;
const _logoRect = Rect.fromLTWH(295, 145.27, 84, 84);
const _labelCenterX = 150.8;

// حدود جامة السائق كما في ملف السيارة، وطرفها الأيمن تحت العمود.
const _doorWindow =
    'M466.54,59.39C466.25,60.88,469.23,124.92,470.42,131.18'
    'C471.61,137.44,476.67,154.42,513.02,156.18L530,157L525,66.9'
    'C521,65.5,516,64.5,512.15,63.88C492.81,60.88,466.54,59.39,466.54,59.39Z';

const _driverPosition = Offset(497, 94);
const _driverScale = 1.25;

// غيمة الكلام فوق مقدمة السيارة، وفقاعتان صغيرتان تصلانها بالجامة.
const _bubbleCenter = Offset(648, 46);
const _puffNear = Offset(538, 92);
const _puffFar = Offset(556, 79);

const _groundSpeed = 150.0;
const _buildingSpeed = 62.0;
const _cloudSpeed = 15.0;
const _stripPeriod = 900.0;

/// حركة السائق: الجامة تنزل، تطلع غيمة «جايك بطريق»، ثم يعود كل شيء.
class DriverPose {
  const DriverPose({required this.window, required this.bubble, required this.nod});

  /// الوضعية الثابتة عند تعطيل الحركات من إعدادات الجهاز.
  static const still = DriverPose(window: 1, bubble: 1, nod: 0);

  static const loop = 11.0;

  factory DriverPose.at(double time) {
    final t = time % loop;
    final down = Curves.easeInOut.transform(_progress(t, 1.2, 2.1));
    final up = Curves.easeInOut.transform(_progress(t, 6.7, 7.6));
    final talk = _progress(t, 2.4, 5.6);
    return DriverPose(
      window: down - up,
      bubble: _progress(t, 2.2, 2.9) - _progress(t, 5.7, 6.2),
      nod: talk > 0 && talk < 1 ? math.sin(talk * math.pi * 4) * math.sin(talk * math.pi) : 0,
    );
  }

  final double window;
  final double bubble;
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
    vanBack = RasterLayer(_record(artVanBack), _vanBounds);
    vanTop = RasterLayer(
      _recordWith((canvas) {
        _paintShapes(canvas, artVanTop);
        // تُعكس الكتابة مرة ثانية حول وسطها فتبقى مقروءة على السيارة المعكوسة.
        canvas
          ..save()
          ..translate(_labelCenterX * 2, 0)
          ..scale(-1, 1);
        _paintShapes(canvas, artVanLabel);
        canvas.restore();
      }),
      _vanBounds,
    );
    vanMiddle = _record(artVanMiddle);
    rearWheel = _record(artVanRearWheel);
    frontWheel = _record(artVanFrontWheel);
    torso = _record(artDriverTorso);
    head = _record(artDriverHead);
    bubble = _recordWith(_paintBubble);
    puffNear = _recordWith((canvas) => _paintPuff(canvas, 6));
    puffFar = _recordWith((canvas) => _paintPuff(canvas, 9));
    doorWindow = parseSvgPath(_doorWindow);
  }

  late final RasterLayer clouds, buildings, plants, vanBack, vanTop;
  late final ui.Picture vanMiddle, rearWheel, frontWheel, torso, head, bubble, puffNear, puffFar;
  late final Path doorWindow;

  void dispose() {
    for (final layer in [clouds, buildings, plants, vanBack, vanTop]) {
      layer.dispose();
    }
    for (final picture in [
      vanMiddle, rearWheel, frontWheel, torso, head, bubble, puffNear, puffFar,
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

  static Paint get _bubbleEdge => Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..isAntiAlias = true;

  static void _paintBubble(Canvas canvas) {
    const lobes = <(double, double, double)>[
      (-58, 0, 20),
      (58, 0, 20),
      (-34, -14, 18),
      (0, -18, 20),
      (34, -14, 18),
      (-34, 14, 16),
      (0, 18, 18),
      (34, 14, 16),
    ];
    final circles = [
      for (final (x, y, radius) in lobes) Rect.fromCircle(center: Offset(x, y), radius: radius),
    ];
    // الحدود أولاً ثم التعبئة فوقها، فلا يبقى إلا الخط الخارجي للغيمة.
    final edge = _bubbleEdge;
    for (final circle in circles) {
      canvas.drawOval(circle, edge);
    }
    final fill = Paint()..color = Colors.white;
    for (final circle in circles) {
      canvas.drawOval(circle, fill);
    }
    canvas.drawRect(const Rect.fromLTRB(-60, -18, 60, 18), fill);

    final text = TextPainter(
      text: const TextSpan(
        text: 'جايك بطريق',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 25,
          fontWeight: FontWeight.w700,
          color: _ink,
          height: 1,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    text.dispose();
  }

  static void _paintPuff(Canvas canvas, double radius) {
    canvas
      ..drawCircle(Offset.zero, radius, _bubbleEdge)
      ..drawCircle(Offset.zero, radius, Paint()..color = Colors.white);
  }
}

/// المشهد المتحرك: السيارة تسير والغيوم والبنايات تمر خلفها، والسائق يقول «جايك بطريق».
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
  ui.Image? _logo;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final data = await rootBundle.load('assets/images/van_logo.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 256);
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _logo = frame.image);
  }

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
    _logo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'سيارة جايك تسير وسائقها يفتح الجامة ويقول: جايك بطريق',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: TruckScenePainter(
            art: _art,
            time: _time,
            scale: widget.scale,
            pixelRatio: MediaQuery.devicePixelRatioOf(context),
            still: _still,
            logo: _logo,
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
    this.logo,
  }) : super(repaint: time);

  final TruckArt art;
  final ValueListenable<double> time;
  final double scale;
  final double pixelRatio;
  final bool still;
  final ui.Image? logo;

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

    // تسير السيارة إلى اليسار، فتمر الخلفية إلى اليمين.
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

    _van(canvas, t, pose, resolution * _vanScale);
    canvas.restore();
  }

  void _van(Canvas canvas, double t, DriverPose pose, double resolution) {
    final sway = 5 * math.sin(2 * math.pi * t / 7);
    final bounce = .8 * math.sin(2 * math.pi * 1.7 * t) + .35 * math.sin(2 * math.pi * 3.1 * t);
    // الرسم معكوس، فهذه الزاوية الموجبة تظهر عكس عقارب الساعة على الشاشة.
    final spin = t * _groundSpeed / _wheelRadius;

    canvas
      ..save()
      ..translate(_vanOrigin.dx + sway, _vanOrigin.dy)
      ..scale(-_vanScale, _vanScale)
      ..save()
      ..translate(0, bounce);
    art.vanBack.paint(canvas, resolution);
    _cab(canvas, pose);
    canvas
      ..drawPicture(art.vanMiddle)
      ..restore();

    _wheel(canvas, art.rearWheel, _rearWheelCenter, spin);
    _wheel(canvas, art.frontWheel, _frontWheelCenter, spin);

    canvas
      ..save()
      ..translate(0, bounce);
    art.vanTop.paint(canvas, resolution);
    final image = logo;
    if (image != null) {
      canvas
        ..save()
        ..translate(_logoRect.center.dx * 2, 0)
        ..scale(-1, 1)
        ..drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          _logoRect,
          Paint()..filterQuality = FilterQuality.medium,
        )
        ..restore();
    }
    _bubble(canvas, pose.bubble);
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

    // السائق: رأسه وكتفاه من شخصية الملف الأصلي، ووجهه نحو طريق السيارة.
    const neck = Offset(670, 283);
    canvas
      ..save()
      ..translate(_driverPosition.dx, _driverPosition.dy)
      ..scale(_driverScale)
      ..translate(-670, -258)
      ..save()
      ..translate(neck.dx, neck.dy)
      ..rotate(pose.nod * .05)
      ..translate(-neck.dx, -neck.dy)
      ..drawPicture(art.head)
      ..restore()
      ..drawPicture(art.torso)
      ..restore();

    // الجامة تنزل داخل الباب، وشفافيتها تُظهر السائق خلفها قليلاً.
    if (pose.window < 1) {
      canvas
        ..save()
        ..translate(0, pose.window * 104)
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
      canvas.restore();
    }
    canvas.restore();
  }

  void _bubble(Canvas canvas, double shown) {
    if (shown <= 0) return;
    void pop(ui.Picture picture, Offset center, double from, double to) {
      final progress = ((shown - from) / (to - from)).clamp(0.0, 1.0);
      if (progress == 0) return;
      final size = Curves.easeOutBack.transform(progress);
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..scale(-size, size)
        ..drawPicture(picture)
        ..restore();
    }

    pop(art.puffNear, _puffNear, 0, .35);
    pop(art.puffFar, _puffFar, .15, .5);
    pop(art.bubble, _bubbleCenter, .3, 1);
  }

  @override
  bool shouldRepaint(TruckScenePainter oldDelegate) =>
      oldDelegate.scale != scale ||
      oldDelegate.pixelRatio != pixelRatio ||
      oldDelegate.still != still ||
      oldDelegate.art != art ||
      oldDelegate.logo != logo;
}
