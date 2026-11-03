import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

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

// الزر الأصفر بلون التطبيق، نهاراً وليلاً.
const _yellowFaceCenter = AppColors.gold;
const _yellowFaceEdge = Color(0xFFF1C800);
const _yellowSide = AppColors.goldDeep;

// الزر بلون الجهة الصفراء في الصفحة الرئيسية.
const _lemonFaceCenter = Color(0xFFE2E255);
const _lemonFaceEdge = Color(0xFFDFDF53);
const _lemonSide = Color(0xFFCDCD4D);

// زر تسجيل الخروج الأحمر، نهاراً وليلاً.
const _redFaceCenter = Color(0xFFFA4D4D);
const _redFaceEdge = Color(0xFFF74C4B);
const _redSide = Color(0xFFE34646);

// مقاسات أزرار الشاشة الأولى وألوانها.
const _loginDesignWidth = 391.0;
const _loginDesignHeight = 715.0;
const _loginMinScale = .95;
const _loginFaceHeight = 32.74;
const _loginTextSize = 13.0;
const _loginTouchMargin = 3.0;
const _loginInk = Color(0xFF263238);
const _loginNightInk = Color(0xFFF4F4EE);
const _loginSpinner = Color(0xFF416F9E);

// زر الرجوع: حافته على حافة خانات الصفحة، وبعده عنوانها.
const _backFaceWidth = 34.0;
const _backArrowSize = 20.0;
const _pageMargin = 22.0;
const _backTitleGap = 12.0;

/// مقياس أزرار الشاشة الأولى على هذه الشاشة.
double pushKeyUnit(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final fit = math.min(size.width / _loginDesignWidth, size.height / _loginDesignHeight);
  return math.max(fit, _loginMinScale);
}

/// زر الرجوع بشكل أزرار الشاشة الأولى، سهم فقط. يملأ مكانه بمساحة اللمس، والزر في طرفه.
class PushKeyBack extends StatelessWidget {
  const PushKeyBack({super.key});

  /// عرض الزر بوحدات التصميم.
  static const width = _backFaceWidth + PushKey.faceInset * 2;

  @override
  Widget build(BuildContext context) {
    final unit = pushKeyUnit(context);
    final night = Theme.of(context).brightness == Brightness.dark;
    final faceHeight = _loginFaceHeight * unit;
    return Semantics(
      button: true,
      label: 'رجوع',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.maybePop(context),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SizedBox(
            width: width * unit,
            height: faceHeight + PushKey.depth * unit,
            child: PushKey(
              unit: unit,
              faceHeight: faceHeight,
              night: night ? kAlwaysCompleteAnimation : kAlwaysDismissedAnimation,
              child: Center(
                child: Icon(
                  Icons.arrow_back,
                  size: _backArrowSize * unit,
                  color: night ? _loginNightInk : _loginInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// شريط صفحة تُفتح من الشاشة الأولى: عنوانها وزر الرجوع.
class PushKeyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PushKeyAppBar({super.key, required this.title, this.backgroundColor});

  final String title;
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      leadingWidth: _pageMargin + PushKeyBack.width * pushKeyUnit(context),
      titleSpacing: _backTitleGap,
      leading: const PushKeyBack(),
      title: Text(title),
    );
  }
}

/// زر بشكل أزرار الشاشة الأولى ومقاساتها، ويأخذ عرض المكان الذي يوضع فيه.
class PushKeyButton extends StatelessWidget {
  const PushKeyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.yellow = false,
  });

  /// ارتفاعه كاملاً بوحدات التصميم، مع هامش اللمس فوقه وتحته.
  static const outerHeight = _loginFaceHeight + PushKey.depth + _loginTouchMargin * 2;

  final String label;
  final VoidCallback onPressed;
  final bool loading;
  final bool yellow;

  @override
  Widget build(BuildContext context) {
    final unit = pushKeyUnit(context);
    final night = Theme.of(context).brightness == Brightness.dark;
    final faceHeight = _loginFaceHeight * unit;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading ? null : onPressed,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _loginTouchMargin * unit),
        child: SizedBox(
          width: double.infinity,
          height: faceHeight + PushKey.depth * unit,
          child: PushKey(
            unit: unit,
            faceHeight: faceHeight,
            held: loading,
            yellow: yellow,
            night: night ? kAlwaysCompleteAnimation : kAlwaysDismissedAnimation,
            child: Semantics(
              button: true,
              enabled: !loading,
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 16 * unit,
                        height: 16 * unit,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: yellow ? _loginInk : _loginSpinner,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: _loginTextSize * unit,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: night && !yellow ? _loginNightInk : _loginInk,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// زر دائري بشكل أزرار الشاشة الأولى. [diameter] قطر وجهه، و[unit] مقياس جانبه وقاعدته.
class PushKeyCircle extends StatelessWidget {
  const PushKeyCircle({
    super.key,
    required this.diameter,
    required this.unit,
    required this.label,
    required this.onPressed,
    required this.child,
    this.touchMargin = 0,
  });

  final double diameter;
  final double unit;
  final String label;
  final VoidCallback? onPressed;
  final Widget child;

  /// مساحة لمس إضافية حول الزر الصغير.
  final double touchMargin;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.all(touchMargin),
          child: SizedBox(
            width: diameter + PushKey.faceInset * 2 * unit,
            height: diameter + PushKey.depth * unit,
            child: PushKey(
              unit: unit,
              faceHeight: diameter,
              round: true,
              night: night ? kAlwaysCompleteAnimation : kAlwaysDismissedAnimation,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// زر ثلاثي الأبعاد باللون الأبيض: وجهه ينخفض عند اللمس فوق جانب وقاعدة ثابتين.
class PushKey extends StatefulWidget {
  const PushKey({
    super.key,
    required this.unit,
    required this.faceHeight,
    required this.child,
    this.held = false,
    this.night = kAlwaysDismissedAnimation,
    this.yellow = false,
    this.lemon = false,
    this.red = false,
    this.round = false,
    this.faceRadius = 4,
  });

  /// ارتفاع الجانب الظاهر تحت وجه الزر، بوحدات التصميم.
  static const depth = 12.0;

  /// المسافة الأفقية بين حد القاعدة وحد وجه الزر، بوحدات التصميم.
  static const faceInset = 8.0;

  final double unit;
  final double faceHeight;
  final Widget child;

  /// يبقي الزر منضغطاً، مثل أثناء انتظار النتيجة.
  final bool held;

  /// 0 نهار، و1 ليل. الزر الساكن يتدرج بطبقتين، فلا يُعاد بناؤه ولا رسمه مع كل إطار.
  final Animation<double> night;

  /// وجه الزر وجانبه باللون الأصفر بدل الأبيض.
  final bool yellow;

  /// وجه الزر وجانبه بلون الجهة الصفراء في الصفحة الرئيسية.
  final bool lemon;

  /// وجه الزر وجانبه باللون الأحمر، مثل زر تسجيل الخروج.
  final bool red;

  /// وجه الزر دائرة، وجانبه وقاعدته حولها.
  final bool round;

  /// استدارة زوايا الوجه بوحدات التصميم.
  final double faceRadius;

  @override
  State<PushKey> createState() => _PushKeyState();
}

/// ما يميز شكل الزر ولونه.
typedef _KeyStyle = ({bool yellow, bool lemon, bool red, bool round, double faceRadius});

class _PushKeyState extends State<PushKey> {
  final _resting = _RestingImages();
  bool _down = false;
  Offset _downAt = Offset.zero;

  void _setDown(bool down) => setState(() => _down = down);

  _KeyStyle get _style => (
        yellow: widget.yellow,
        lemon: widget.lemon,
        red: widget.red,
        round: widget.round,
        faceRadius: widget.faceRadius,
      );

  Widget _chrome(double pressed, double pixelRatio) {
    if (pressed > 0) {
      return RepaintBoundary(
        child: CustomPaint(
          painter: _KeyPainter(
            pressed: pressed,
            unit: widget.unit,
            faceHeight: widget.faceHeight,
            night: widget.night,
            style: _style,
          ),
        ),
      );
    }
    final changesTheme = !identical(widget.night, kAlwaysDismissedAnimation) &&
        !identical(widget.night, kAlwaysCompleteAnimation);
    Widget image(bool night) => CustomPaint(
          painter: _RestingPainter(
            images: _resting,
            night: night,
            both: changesTheme,
            pixelRatio: pixelRatio,
            unit: widget.unit,
            faceHeight: widget.faceHeight,
            style: _style,
          ),
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(opacity: ReverseAnimation(widget.night), child: image(false)),
        FadeTransition(opacity: widget.night, child: image(true)),
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
      onPointerDown: (event) {
        _downAt = event.position;
        _setDown(true);
      },
      // السحب فوق الزر لتحريك الصفحة لا يبقيه منضغطاً.
      onPointerMove: (event) {
        if (_down && (event.position - _downAt).distance > kTouchSlop) _setDown(false);
      },
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

/// صورة زر ساكن، تتشاركها الأزرار المتشابهة فلا تُرسم مرة لكل زر.
class _SharedImage {
  _SharedImage(this.image);

  final ui.Image image;
  int users = 1;
}

typedef _RestingLook = (Size, double, double, double, _KeyStyle, double);

final _sharedImages = <_RestingLook, _SharedImage>{};

/// صورتا الزر وهو ساكن نهاراً وليلاً، حتى لا تُعاد ظلاله مع كل إطار.
class _RestingImages {
  ui.Image? _day;
  ui.Image? _night;
  Size _size = Size.zero;
  double _pixelRatio = 0;
  double _unit = 0;
  double _faceHeight = 0;
  _KeyStyle? _style;

  void paint(
    Canvas canvas, {
    required Size size,
    required double pixelRatio,
    required double unit,
    required double faceHeight,
    required bool night,
    required bool both,
    required _KeyStyle style,
  }) {
    if (size != _size ||
        pixelRatio != _pixelRatio ||
        unit != _unit ||
        faceHeight != _faceHeight ||
        style != _style) {
      dispose();
      _size = size;
      _pixelRatio = pixelRatio;
      _unit = unit;
      _faceHeight = faceHeight;
      _style = style;
    }
    // الزر الذي يتدرج بين النهار والليل يحتاج الصورتين، وغيره يحتاج واحدة.
    if (both || !night) _day ??= _acquire(0);
    if (both || night) _night ??= _acquire(1);
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

  _RestingLook _look(double night) => (_size, _pixelRatio, _unit, _faceHeight, _style!, night);

  ui.Image _acquire(double night) {
    final look = _look(night);
    final shared = _sharedImages[look];
    if (shared != null) {
      shared.users++;
      return shared.image;
    }
    final image = _snapshot(night);
    _sharedImages[look] = _SharedImage(image);
    return image;
  }

  void _release(double night) {
    final look = _look(night);
    final shared = _sharedImages[look]!;
    if (--shared.users > 0) return;
    shared.image.dispose();
    _sharedImages.remove(look);
  }

  ui.Image _snapshot(double night) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(_pixelRatio)
      ..translate(_margin, _margin);
    _KeyPainter(
      pressed: 0,
      unit: _unit,
      faceHeight: _faceHeight,
      night: AlwaysStoppedAnimation(night),
      style: _style!,
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
    if (_day != null) _release(0);
    if (_night != null) _release(1);
    _day = null;
    _night = null;
  }
}

class _RestingPainter extends CustomPainter {
  _RestingPainter({
    required this.images,
    required this.night,
    required this.both,
    required this.pixelRatio,
    required this.unit,
    required this.faceHeight,
    required this.style,
  });

  final _RestingImages images;
  final bool night;
  final bool both;
  final double pixelRatio;
  final double unit;
  final double faceHeight;
  final _KeyStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    images.paint(
      canvas,
      size: size,
      pixelRatio: pixelRatio,
      unit: unit,
      faceHeight: faceHeight,
      night: night,
      both: both,
      style: style,
    );
  }

  @override
  bool shouldRepaint(_RestingPainter oldDelegate) =>
      oldDelegate.night != night ||
      oldDelegate.both != both ||
      oldDelegate.pixelRatio != pixelRatio ||
      oldDelegate.unit != unit ||
      oldDelegate.faceHeight != faceHeight ||
      oldDelegate.style != style;
}

class _KeyPainter extends CustomPainter {
  _KeyPainter({
    required this.pressed,
    required this.unit,
    required this.faceHeight,
    required this.night,
    required this.style,
  }) : super(repaint: night);

  final double pressed;
  final double unit;
  final double faceHeight;
  final Animation<double> night;
  final _KeyStyle style;

  double _mix(double up, double down) => (up + (down - up) * pressed) * unit;

  Color _tone(Color day, Color dark) => Color.lerp(day, dark, night.value)!;

  Color _keyTone(Color inYellow, Color inLemon, Color inRed, Color day, Color dark) => style.yellow
      ? inYellow
      : style.lemon
          ? inLemon
          : style.red
              ? inRed
              : _tone(day, dark);

  @override
  void paint(Canvas canvas, Size size) {
    _paintBase(canvas, size);
    _paintSide(canvas, size);
    _paintFace(canvas, size);
  }

  void _paintBase(Canvas canvas, Size size) {
    final baseCorner = style.round ? (size.height - 4 * unit) / 2 : 12 * unit;
    final base = RRect.fromLTRBR(0, 4 * unit, size.width, size.height, Radius.circular(baseCorner));
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
    final roundCorner = Radius.circular((size.height - 4 * unit - _mix(0, 6)) / 2);
    final top = style.round ? roundCorner : Radius.elliptical(_mix(8, 10), _mix(16, 8));
    final bottom = style.round ? roundCorner : Radius.circular(8 * unit);
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
      ..drawRRect(
        side,
        Paint()..color = _keyTone(_yellowSide, _lemonSide, _redSide, _side, _nightSide),
      )
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

  RRect _faceShape(Size size) {
    final grow = _mix(0, 2);
    final offset = _mix(0, 6);
    final inset = PushKey.faceInset * unit;
    return RRect.fromLTRBR(
      inset - grow,
      offset,
      size.width - inset + grow,
      faceHeight + offset,
      style.round
          ? Radius.circular(faceHeight / 2)
          : Radius.circular(_mix(style.faceRadius, style.faceRadius + 2)),
    );
  }

  void _paintOutline(Canvas canvas, RRect face, Color color) {
    canvas.drawRRect(
      face.deflate(.5 * unit),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit,
    );
  }

  void _paintFace(Canvas canvas, Size size) {
    final face = _faceShape(size);
    canvas.drawRRect(
      face,
      Paint()
        ..shader = ui.Gradient.radial(
          face.center,
          face.width * .62,
          [
            _keyTone(_yellowFaceCenter, _lemonFaceCenter, _redFaceCenter, _faceCenter, _nightFaceCenter),
            _keyTone(_yellowFaceEdge, _lemonFaceEdge, _redFaceEdge, _faceEdge, _nightFaceEdge),
          ],
        ),
    );
    _paintOutline(canvas, face, _tone(_faceOutline, _nightFaceOutline));
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
      oldDelegate.night != night ||
      oldDelegate.style != style;
}
