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

/// زر ثلاثي الأبعاد باللون الأبيض: وجهه ينخفض عند اللمس فوق جانب وقاعدة ثابتين.
class PushKey extends StatefulWidget {
  const PushKey({
    super.key,
    required this.unit,
    required this.faceHeight,
    required this.child,
    this.borderColor,
    this.held = false,
  });

  /// ارتفاع الجانب الظاهر تحت وجه الزر، بوحدات التصميم.
  static const depth = 12.0;

  final double unit;
  final double faceHeight;
  final Widget child;
  final Color? borderColor;

  /// يبقي الزر منضغطاً، مثل أثناء انتظار النتيجة.
  final bool held;

  @override
  State<PushKey> createState() => _PushKeyState();
}

class _PushKeyState extends State<PushKey> {
  bool _down = false;

  void _setDown(bool down) => setState(() => _down = down);

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
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
            RepaintBoundary(
              child: CustomPaint(
                painter: _KeyPainter(
                  pressed: pressed,
                  unit: unit,
                  faceHeight: widget.faceHeight,
                  borderColor: widget.borderColor,
                ),
              ),
            ),
            Positioned(
              left: 8 * unit,
              right: 8 * unit,
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

class _KeyPainter extends CustomPainter {
  _KeyPainter({
    required this.pressed,
    required this.unit,
    required this.faceHeight,
    this.borderColor,
  });

  final double pressed;
  final double unit;
  final double faceHeight;
  final Color? borderColor;

  double _mix(double up, double down) => (up + (down - up) * pressed) * unit;

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
          ..color = _baseHighlight
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, .5 * unit),
      )
      ..drawRRect(base, Paint()..color = _baseFill);
    _innerShadow(canvas, base, _baseInnerShadow, Offset(0, 2 * unit), 2 * unit, 0);
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
          ..color = _sideShadow
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * unit),
      )
      ..drawRRect(side, Paint()..color = _side)
      ..save()
      ..clipRRect(side);
    final lowCorner = side.bottom - 8 * unit;
    _glow(canvas, Offset(side.left + 4 * unit, lowCorner), 4 * unit, 8 * unit, _sideShine);
    _glow(canvas, Offset(side.right - 4 * unit, lowCorner), 4 * unit, 8 * unit, _sideShine);
    _glow(canvas, Offset(side.left - 4 * unit, side.top), 16 * unit, 16 * unit, Colors.white);
    _glow(canvas, Offset(side.right + 4 * unit, side.top), 16 * unit, 16 * unit, Colors.white);
    canvas.restore();
    _innerShadow(canvas, side, _sideInnerShadow, Offset(0, -unit), 3 * unit, 3 * unit);
  }

  void _paintFace(Canvas canvas, Size size) {
    final grow = _mix(0, 2);
    final offset = _mix(0, 6);
    final face = RRect.fromLTRBR(
      8 * unit - grow,
      offset,
      size.width - 8 * unit + grow,
      faceHeight + offset,
      Radius.circular(_mix(4, 6)),
    );
    canvas.drawRRect(
      face,
      Paint()
        ..shader = ui.Gradient.radial(
          face.center,
          face.width * .62,
          const [_faceCenter, _faceEdge],
        ),
    );
    canvas.drawRRect(
      face.deflate(.5 * unit),
      Paint()
        ..color = borderColor ?? _faceOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit,
    );
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
      oldDelegate.borderColor != borderColor;
}
