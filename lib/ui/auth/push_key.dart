import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const _faceCenter = Colors.white;
const _faceEdge = Color(0xFFF1F0E9);
const _faceOutline = Color(0x12000000);
const _side = Color(0xFFF0EEDF);
const _baseFill = Color(0x14000000);
const _baseHighlight = Color(0xBFFFFFFF);
const _baseInnerShadow = Color(0x26000000);
const _sideShadow = Color(0x38000000);
const _sideInnerShadow = Color(0x24000000);
const _sideShine = Color(0x40FFFFFF);
const _sideGlow = Colors.white;
const _alarmFaceCenter = Color(0xFFEF4444);
const _alarmFaceEdge = Color(0xFFDC2626);
const _alarmSide = Color(0xFF991B1B);

// الألوان نفسها في الوضع الليلي.
const _nightFaceCenter = Color(0xFF2C2C32);
const _nightFaceEdge = Color(0xFF25252B);
const _nightFaceOutline = Color(0x1FFFFFFF);
const _nightSide = Color(0xFF17171A);
const _nightBaseFill = Color(0x14FFFFFF);
const _nightBaseHighlight = Color(0x14FFFFFF);
const _nightBaseInnerShadow = Color(0x66000000);
const _nightSideShadow = Color(0x80000000);
const _nightSideInnerShadow = Color(0x4D000000);
const _nightSideShine = Color(0x14FFFFFF);
const _nightSideGlow = Color(0x26FFFFFF);

/// زر ثلاثي الأبعاد باللون الأبيض: وجهه ينخفض عند اللمس فوق جانب وقاعدة ثابتين.
class PushKey extends StatefulWidget {
  const PushKey({
    super.key,
    required this.unit,
    required this.faceHeight,
    required this.child,
    this.borderColor,
    this.held = false,
    this.alarm = 0,
    this.night = kAlwaysDismissedAnimation,
  });

  /// ارتفاع الجانب الظاهر تحت وجه الزر، بوحدات التصميم.
  static const depth = 12.0;

  /// المسافة الأفقية بين حد القاعدة وحد وجه الزر، بوحدات التصميم.
  static const faceInset = 8.0;

  final double unit;
  final double faceHeight;
  final Widget child;
  final Color? borderColor;

  /// يبقي الزر منضغطاً، مثل أثناء انتظار النتيجة.
  final bool held;

  /// مقدار احمرار الزر: 0 لونه الطبيعي، و1 أحمر بالكامل.
  final double alarm;

  /// 0 نهار، و1 ليل. الزر الساكن يتدرج بطبقتين، فلا يُعاد بناؤه ولا رسمه مع كل إطار.
  final Animation<double> night;

  @override
  State<PushKey> createState() => _PushKeyState();
}

class _PushKeyState extends State<PushKey> {
  final _resting = _RestingImages();
  bool _down = false;

  void _setDown(bool down) => setState(() => _down = down);

  Widget _chrome(double pressed, double pixelRatio) {
    final shape = _KeyPainter(
      pressed: pressed,
      unit: widget.unit,
      faceHeight: widget.faceHeight,
      borderColor: widget.borderColor,
      alarm: widget.alarm,
      night: widget.night,
    );
    if (pressed > 0 || widget.alarm > 0) {
      return RepaintBoundary(child: CustomPaint(painter: shape));
    }
    Widget image(bool night) => CustomPaint(
          painter: _RestingPainter(
            images: _resting,
            night: night,
            pixelRatio: pixelRatio,
            unit: widget.unit,
            faceHeight: widget.faceHeight,
          ),
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(opacity: ReverseAnimation(widget.night), child: image(false)),
        FadeTransition(opacity: widget.night, child: image(true)),
        if (widget.borderColor != null) CustomPaint(painter: _FocusOutlinePainter(shape)),
      ],
    );
  }

  @override
  void dispose() {
    _resting.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _setDown(true),
      onPointerUp: (_) => _setDown(false),
      onPointerCancel: (_) => _setDown(false),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _down || widget.held ? 1 : 0),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.ease,
        child: widget.child,
        builder: (context, pressed, child) => Stack(
          fit: StackFit.expand,
          children: [
            _chrome(pressed, pixelRatio),
            Positioned(
              left: PushKey.faceInset * unit,
              right: PushKey.faceInset * unit,
              top: 6 * unit * pressed,
              height: widget.faceHeight,
              child: child!,
            ),
          ],
        ),
      ),
    );
  }
}

/// صورتا الزر وهو ساكن نهاراً وليلاً، حتى لا تُعاد ظلاله مع كل إطار.
class _RestingImages {
  ui.Image? _day;
  ui.Image? _night;
  Size _size = Size.zero;
  double _pixelRatio = 0;
  double _unit = 0;
  double _faceHeight = 0;

  void paint(
    Canvas canvas, {
    required Size size,
    required double pixelRatio,
    required double unit,
    required double faceHeight,
    required bool night,
  }) {
    if (size != _size ||
        pixelRatio != _pixelRatio ||
        unit != _unit ||
        faceHeight != _faceHeight) {
      dispose();
      _size = size;
      _pixelRatio = pixelRatio;
      _unit = unit;
      _faceHeight = faceHeight;
      _day = _snapshot(0);
      _night = _snapshot(1);
    }
    final image = night ? _night! : _day!;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        -_margin,
        -_margin,
        image.width / _pixelRatio,
        image.height / _pixelRatio,
      ),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  // الحافة المضيئة تحت الزر تخرج قليلاً عن حدوده.
  double get _margin => 4 * _unit;

  ui.Image _snapshot(double night) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(_pixelRatio)
      ..translate(_margin, _margin);
    _KeyPainter(
      pressed: 0,
      unit: _unit,
      faceHeight: _faceHeight,
      alarm: 0,
      night: AlwaysStoppedAnimation(night),
    ).paint(canvas, _size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      ((_size.width + _margin * 2) * _pixelRatio).ceil(),
      ((_size.height + _margin * 2) * _pixelRatio).ceil(),
    );
    picture.dispose();
    return image;
  }

  void dispose() {
    _day?.dispose();
    _night?.dispose();
    _day = null;
    _night = null;
  }
}

class _RestingPainter extends CustomPainter {
  _RestingPainter({
    required this.images,
    required this.night,
    required this.pixelRatio,
    required this.unit,
    required this.faceHeight,
  });

  final _RestingImages images;
  final bool night;
  final double pixelRatio;
  final double unit;
  final double faceHeight;

  @override
  void paint(Canvas canvas, Size size) {
    images.paint(
      canvas,
      size: size,
      pixelRatio: pixelRatio,
      unit: unit,
      faceHeight: faceHeight,
      night: night,
    );
  }

  @override
  bool shouldRepaint(_RestingPainter oldDelegate) =>
      oldDelegate.night != night ||
      oldDelegate.pixelRatio != pixelRatio ||
      oldDelegate.unit != unit ||
      oldDelegate.faceHeight != faceHeight;
}

/// إطار الخانة عند الكتابة فيها، فوق صورة الزر الساكن.
class _FocusOutlinePainter extends CustomPainter {
  _FocusOutlinePainter(this.shape);

  final _KeyPainter shape;

  @override
  void paint(Canvas canvas, Size size) {
    shape.paintOutline(canvas, shape.faceShape(size), shape.borderColor!);
  }

  @override
  bool shouldRepaint(_FocusOutlinePainter oldDelegate) =>
      oldDelegate.shape.borderColor != shape.borderColor ||
      oldDelegate.shape.unit != shape.unit ||
      oldDelegate.shape.faceHeight != shape.faceHeight;
}

class _KeyPainter extends CustomPainter {
  _KeyPainter({
    required this.pressed,
    required this.unit,
    required this.faceHeight,
    required this.alarm,
    required this.night,
    this.borderColor,
  }) : super(repaint: night);

  final double pressed;
  final double unit;
  final double faceHeight;
  final double alarm;
  final Animation<double> night;
  final Color? borderColor;

  double _mix(double up, double down) => (up + (down - up) * pressed) * unit;

  Color _tone(Color day, Color dark) => Color.lerp(day, dark, night.value)!;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBase(canvas, size);
    _paintSide(canvas, size);
    _paintFace(canvas, size);
  }

  void _paintBase(Canvas canvas, Size size) {
    final base = RRect.fromLTRBR(0, 4 * unit, size.width, size.height, Radius.circular(12 * unit));
    canvas
      ..drawRRect(
        base.shift(Offset(0, unit)),
        Paint()
          ..color = _tone(_baseHighlight, _nightBaseHighlight)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, .5 * unit),
      )
      ..drawRRect(base, Paint()..color = _tone(_baseFill, _nightBaseFill));
    _innerShadow(
      canvas,
      base,
      _tone(_baseInnerShadow, _nightBaseInnerShadow),
      Offset(0, 2 * unit),
      2 * unit,
      0,
    );
  }

  void _paintSide(Canvas canvas, Size size) {
    final top = Radius.elliptical(_mix(8, 10), _mix(16, 8));
    final bottom = Radius.circular(8 * unit);
    final side = RRect.fromLTRBAndCorners(
      4 * unit,
      _mix(0, 6),
      size.width - 4 * unit,
      size.height - 4 * unit,
      topLeft: top,
      topRight: top,
      bottomLeft: bottom,
      bottomRight: bottom,
    );
    canvas
      ..drawRRect(
        side.shift(Offset(0, 2 * unit)),
        Paint()
          ..color = _tone(_sideShadow, _nightSideShadow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * unit),
      )
      ..drawRRect(side, Paint()..color = Color.lerp(_tone(_side, _nightSide), _alarmSide, alarm)!)
      ..save()
      ..clipRRect(side);
    final lowCorner = side.bottom - 8 * unit;
    final shine = _tone(_sideShine, _nightSideShine);
    final glow = _tone(_sideGlow, _nightSideGlow);
    _glow(canvas, Offset(side.left + 4 * unit, lowCorner), 4 * unit, 8 * unit, shine);
    _glow(canvas, Offset(side.right - 4 * unit, lowCorner), 4 * unit, 8 * unit, shine);
    _glow(canvas, Offset(side.left - 4 * unit, side.top), 16 * unit, 16 * unit, glow);
    _glow(canvas, Offset(side.right + 4 * unit, side.top), 16 * unit, 16 * unit, glow);
    canvas.restore();
    _innerShadow(
      canvas,
      side,
      _tone(_sideInnerShadow, _nightSideInnerShadow),
      Offset(0, -unit),
      3 * unit,
      3 * unit,
    );
  }

  RRect faceShape(Size size) {
    final grow = _mix(0, 2);
    final offset = _mix(0, 6);
    final inset = PushKey.faceInset * unit;
    return RRect.fromLTRBR(
      inset - grow,
      offset,
      size.width - inset + grow,
      faceHeight + offset,
      Radius.circular(_mix(4, 6)),
    );
  }

  void paintOutline(Canvas canvas, RRect face, Color color) {
    canvas.drawRRect(
      face.deflate(.5 * unit),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit,
    );
  }

  void _paintFace(Canvas canvas, Size size) {
    final face = faceShape(size);
    final outline = _tone(_faceOutline, _nightFaceOutline);
    canvas.drawRRect(
      face,
      Paint()
        ..shader = ui.Gradient.radial(
          face.center,
          face.width * .62,
          [
            Color.lerp(_tone(_faceCenter, _nightFaceCenter), _alarmFaceCenter, alarm)!,
            Color.lerp(_tone(_faceEdge, _nightFaceEdge), _alarmFaceEdge, alarm)!,
          ],
        ),
    );
    paintOutline(canvas, face, Color.lerp(borderColor ?? outline, outline, alarm)!);
  }

  void _glow(Canvas canvas, Offset center, double radiusX, double radiusY, Color color) {
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(radiusX, radiusY)
      ..drawCircle(
        Offset.zero,
        1,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            1,
            [color, color.withValues(alpha: 0)],
          ),
      )
      ..restore();
  }

  void _innerShadow(
    Canvas canvas,
    RRect shape,
    Color color,
    Offset offset,
    double blur,
    double spread,
  ) {
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(shape.outerRect.inflate(blur * 3 + spread))
      ..addRRect(shape.deflate(spread).shift(offset));
    canvas
      ..save()
      ..clipRRect(shape)
      ..drawPath(
        ring,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_KeyPainter oldDelegate) =>
      oldDelegate.pressed != pressed ||
      oldDelegate.unit != unit ||
      oldDelegate.faceHeight != faceHeight ||
      oldDelegate.alarm != alarm ||
      oldDelegate.night != night ||
      oldDelegate.borderColor != borderColor;
}
