import 'package:flutter/material.dart';

// تصميم الخانة من Uiverse.io (0xnihilism)، والمقاسات محسوبة من rem في أصله (1rem = 16).
const _fill = Color(0xFFF5F5F5);
const _outline = Color(0xFFDDDDDD);
const _accent = Color(0xFFFF7F7F);
const _invalid = Color(0xFFFF4D4D);
const _depthColor = Color(0xFFDFD9D9);
const _hintColor = Color(0xFFCCCCCC);
const _glowColor = Color(0x33FF7F7F);

// الألوان نفسها في الوضع الليلي.
const _nightFill = Color(0xFF2C2C32);
const _nightOutline = Color(0xFF3A3A40);
const _nightDepthColor = Color(0xFF17171A);
const _nightHintColor = Color(0xFF9B9BA3);

const _fontSize = 17.6;
const _borderWidth = 2.0;
const _radius = 24.0;
const _paddingX = 16.0;

// ارتفاع الخانة في الأصل 62.7، وسطر Cairo أطول من سطر المتصفح فتقل الحشوة ليبقى الارتفاع نفسه.
const _paddingY = 16.45;

const _restDepth = 6.4;
const _focusDepth = 9.6;
const _focusLift = 3.0;
const _focusGrow = .01;
const _glowBlur = 10.0;
const _hintSlide = 10.0;
const _transition = Duration(milliseconds: 300);

final _shakeSteps = TweenSequence<double>([
  for (final (begin, end) in const [(0.0, -5.0), (-5.0, 5.0), (5.0, -5.0), (-5.0, 0.0)])
    TweenSequenceItem(
      tween: Tween<double>(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 1,
    ),
]);

Duration _motion(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

/// خانة كتابة بارزة: ترتفع عند الكتابة فيها، وتحمرّ وتهتز إذا كان ما فيها غير صحيح.
class RaisedField extends StatefulWidget {
  const RaisedField({
    super.key,
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String value)? validator;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final int? minLines;
  final int? maxLines;

  @override
  State<RaisedField> createState() => _RaisedFieldState();
}

class _RaisedFieldState extends State<RaisedField> with SingleTickerProviderStateMixin {
  final _field = GlobalKey<FormFieldState<String>>();
  final _focus = FocusNode();
  late final _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final _shake = _shakeSteps.animate(_shakeController);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(RaisedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focus.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  /// يرجع لون الخانة الطبيعي بمجرد تصحيح ما فيها.
  void _onTextChanged() {
    final field = _field.currentState;
    if (field != null && field.hasError && widget.validator?.call(widget.controller.text) == null) {
      field.reset();
    }
  }

  String? _validate(String? _) {
    final error = widget.validator?.call(widget.controller.text);
    if (error != null && !MediaQuery.disableAnimationsOf(context)) {
      _shakeController.forward(from: 0);
    }
    return error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final night = theme.brightness == Brightness.dark;
    final style = theme.textTheme.bodyLarge!.copyWith(fontSize: _fontSize);
    return FormField<String>(
      key: _field,
      validator: _validate,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focus.requestFocus,
            child: _RaisedBox(
              focused: _focus.hasFocus,
              invalid: field.hasError,
              shake: _shake,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: widget.keyboardType,
                textDirection: widget.textDirection,
                textAlign: widget.textAlign,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                style: style.copyWith(color: _accent),
                cursorColor: _accent,
                // يبقى أسفل الخانة وعمقها ظاهرين فوق لوحة المفاتيح.
                scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hint: _Hint(
                    text: widget.hint,
                    gone: _focus.hasFocus,
                    style: style.copyWith(color: night ? _nightHintColor : _hintColor),
                    textDirection: widget.textDirection,
                    textAlign: widget.textAlign,
                    maxLines: widget.maxLines,
                  ),
                ),
              ),
            ),
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(_paddingX, 4, _paddingX, 0),
              child: Text(
                field.errorText!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// خانة اختيار بشكل خانة الكتابة، تبقى مرفوعة ما دامت قائمتها مفتوحة.
class RaisedPicker extends StatelessWidget {
  const RaisedPicker({super.key, required this.value, required this.open, required this.onTap});

  final String value;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(
          fontSize: _fontSize,
          color: _accent,
        );
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _RaisedBox(
          focused: open,
          invalid: false,
          shake: kAlwaysDismissedAnimation,
          child: Row(
            children: [
              Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
              const Icon(Icons.expand_more_rounded, size: 20, color: _accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// نص الخانة الفارغة: يتلاشى وينزلق عند بدء الكتابة، ثم يرجع بالتدرج نفسه.
class _Hint extends StatelessWidget {
  const _Hint({
    required this.text,
    required this.gone,
    required this.style,
    required this.textDirection,
    required this.textAlign,
    required this.maxLines,
  });

  final String text;
  final bool gone;
  final TextStyle style;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: gone ? 1 : 0),
      duration: _motion(context, _transition),
      curve: Curves.ease,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textDirection: textDirection,
        textAlign: textAlign,
        style: style,
      ),
      builder: (context, gone, child) => Opacity(
        opacity: 1 - gone,
        child: Transform.translate(offset: Offset(_hintSlide * gone, 0), child: child),
      ),
    );
  }
}

class _RaisedBox extends StatelessWidget {
  const _RaisedBox({
    required this.focused,
    required this.invalid,
    required this.shake,
    required this.child,
  });

  final bool focused;
  final bool invalid;
  final Animation<double> shake;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final transition = _motion(context, _transition);
    return Padding(
      padding: const EdgeInsets.only(bottom: _restDepth),
      child: AnimatedBuilder(
        animation: shake,
        builder: (context, box) => Transform.translate(offset: Offset(shake.value, 0), child: box),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: invalid ? 1 : 0),
          duration: transition,
          curve: Curves.easeInOutBack,
          builder: (context, invalid, _) => TweenAnimationBuilder<double>(
            tween: Tween<double>(end: focused ? 1 : 0),
            duration: transition,
            curve: Curves.easeInOutBack,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _paddingX + _borderWidth,
                vertical: _paddingY + _borderWidth,
              ),
              child: child,
            ),
            builder: (context, focus, content) => Transform.translate(
              offset: Offset(0, -_focusLift * focus),
              child: Transform.scale(
                scale: 1 + _focusGrow * focus,
                child: CustomPaint(
                  painter: _BoxPainter(focus: focus, invalid: invalid, night: night),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter({required this.focus, required this.invalid, required this.night});

  final double focus;
  final double invalid;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_radius));
    final depth = _restDepth + (_focusDepth - _restDepth) * focus;
    canvas
      ..drawRRect(
        box.shift(Offset(0, depth)),
        Paint()..color = night ? _nightDepthColor : _depthColor,
      )
      ..drawRRect(box, Paint()..color = night ? _nightFill : _fill);
    _paintGlow(canvas, box.deflate(_borderWidth));
    final border = Color.lerp(night ? _nightOutline : _outline, _accent, focus);
    canvas.drawRRect(
      box.deflate(_borderWidth / 2),
      Paint()
        ..color = Color.lerp(border, _invalid, invalid)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth,
    );
  }

  void _paintGlow(Canvas canvas, RRect shape) {
    if (focus <= 0) return;
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(shape.outerRect.inflate(_glowBlur * 3))
      ..addRRect(shape);
    canvas
      ..save()
      ..clipRRect(shape)
      ..drawPath(
        ring,
        Paint()
          ..color = _glowColor.withValues(alpha: _glowColor.a * focus.clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _glowBlur * focus / 2),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BoxPainter oldDelegate) =>
      oldDelegate.focus != focus || oldDelegate.invalid != invalid || oldDelegate.night != night;
}
