import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../widgets/ui.dart';

// تصميم الخانة من Uiverse.io (0xnihilism)، والمقاسات محسوبة من rem في أصله (1rem = 16).
const _fill = Color(0xFFF5F5F5);
const _outline = Color(0xFFDDDDDD);
const _invalid = Color(0xFFFF4D4D);
const _depthColor = Color(0xFFDFD9D9);
const _hintColor = Color(0xFFCCCCCC);

// وردي الأصل (#FF7F7F) يشبه لون الخطأ، فصار الأحمر للخطأ وحده: الكتابة وإطارها بالأسود.
const _focusColor = AppColors.ink;
const _glowAlpha = .2;

// الألوان نفسها في الوضع الليلي.
const _nightFill = Color(0xFF2C2C32);
const _nightOutline = Color(0xFF3A3A40);
const _nightDepthColor = Color(0xFF17171A);
const _nightHintColor = Color(0xFF9B9BA3);
const _nightFocusColor = Color(0xFFF4F4EE);

const _fontSize = 17.6;
const _borderWidth = 2.0;
const _radius = 24.0;
const _paddingX = 16.0;

// ارتفاع الخانة في الأصل 62.7، وسطر Cairo أطول من سطر المتصفح فتقل الحشوة ليبقى الارتفاع نفسه.
const _paddingY = 16.45;

const _eyeSize = 20.0;

// منطقة لمس العين بعرض يكفي الإصبع وبارتفاع الخانة كله، والعين في مكان سهم خانة الاختيار.
const _trailingWidth = (_paddingX + _borderWidth) * 2 + _eyeSize;

const _restDepth = 6.4;
const _focusDepth = 9.6;
const _focusLift = 3.0;
const _focusGrow = .01;
const _glowBlur = 10.0;
const _hintSlide = 10.0;
const _transition = Duration(milliseconds: 300);
const _shakeDuration = Duration(milliseconds: 500);

// عند الوصول إلى خانة خطأ تقف قرب أعلى الشاشة، فيظهر عنوانها فوقها ورسالتها تحتها.
const _errorAlignment = .3;
const _labelRoom = 32.0;

final _shakeSteps = TweenSequence<double>([
  for (final (begin, end) in const [(0.0, -5.0), (-5.0, 5.0), (5.0, -5.0), (-5.0, 0.0)])
    TweenSequenceItem(
      tween: Tween<double>(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 1,
    ),
]);

Duration _motion(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

/// يفحص الاستمارة، وإذا وجد خطأ ينقل الصفحة إلى أول خانة خطأ ما لم تكن ظاهرة بالكامل.
bool validateAndShowFirstError(FormState form) {
  final invalid = form.validateGranularly();
  if (invalid.isEmpty) return true;
  // رسائل الخطأ تغيّر مواضع الخانات، فيُحسب المكان بعد ظهورها.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final field = invalid.first;
    if (field.mounted) _showField(field.context);
  });
  return false;
}

void _showField(BuildContext field) {
  final box = field.findRenderObject()! as RenderBox;
  final viewport = Scrollable.of(field).context.findRenderObject()! as RenderBox;
  final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
  if (top >= _labelRoom && top + box.size.height <= viewport.size.height) return;
  Scrollable.ensureVisible(
    field,
    alignment: _errorAlignment,
    duration: _motion(field, _transition),
    curve: Curves.easeInOut,
  );
}

/// عنوان خانة كتابة مطلوبة: تختفي نقطته الحمراء بمجرد ملء الخانة، وترجع إذا فُرّغت.
class RequiredFieldLabel extends StatelessWidget {
  const RequiredFieldLabel(this.text, {super.key, required this.controller});

  final String text;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => FieldLabel(
          text,
          required_: true,
          filled: controller.text.trim().isNotEmpty,
        ),
      );
}

/// خانة كتابة بارزة: ترتفع عند الكتابة فيها، وتحمرّ وتهتز إذا كان ما فيها غير صحيح،
/// وتختفي حمرتها بمجرد الكتابة فيها حتى يعيد زر الإرسال فحصها.
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
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.onToggleObscure,
    this.clearErrorWith,
    this.onTyped,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String value)? validator;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final int? minLines;
  final int? maxLines;
  final TextCapitalization textCapitalization;
  final bool obscureText;

  /// إذا وُجد تظهر في الخانة عين تُظهر كلمة المرور وتخفيها.
  final VoidCallback? onToggleObscure;

  /// خانة تعتمد عليها هذه الخانة، فتختفي حمرتها أيضاً عند الكتابة في تلك.
  final TextEditingController? clearErrorWith;

  /// عند تغيّر النص بالكتابة، لا عند تحريك المؤشر.
  final VoidCallback? onTyped;

  @override
  State<RaisedField> createState() => _RaisedFieldState();
}

class _RaisedFieldState extends State<RaisedField> with SingleTickerProviderStateMixin {
  final _field = GlobalKey<FormFieldState<String>>();
  final _focus = FocusNode();
  late final _shakeController = AnimationController(vsync: this, duration: _shakeDuration);
  late final _shake = _shakeSteps.animate(_shakeController);
  late String _text;
  String? _linkedText;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    _text = widget.controller.text;
    _linkedText = widget.clearErrorWith?.text;
    widget.controller.addListener(_onTextChanged);
    widget.clearErrorWith?.addListener(_onLinkedTextChanged);
  }

  @override
  void didUpdateWidget(RaisedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      _text = widget.controller.text;
      widget.controller.addListener(_onTextChanged);
    }
    if (oldWidget.clearErrorWith != widget.clearErrorWith) {
      oldWidget.clearErrorWith?.removeListener(_onLinkedTextChanged);
      _linkedText = widget.clearErrorWith?.text;
      widget.clearErrorWith?.addListener(_onLinkedTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.clearErrorWith?.removeListener(_onLinkedTextChanged);
    _focus.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  void _clearError() {
    final field = _field.currentState;
    if (field != null && field.hasError) field.reset();
  }

  // تحريك المؤشر يُبلّغ عنه أيضاً، فلا تختفي الحمرة إلا إذا تغيّر النص.
  void _onTextChanged() {
    final text = widget.controller.text;
    if (text == _text) return;
    _text = text;
    _clearError();
    widget.onTyped?.call();
  }

  void _onLinkedTextChanged() {
    final text = widget.clearErrorWith!.text;
    if (text == _linkedText) return;
    _linkedText = text;
    _clearError();
  }

  String? _validate(String? _) {
    final error = widget.validator?.call(widget.controller.text);
    if (error != null && !MediaQuery.disableAnimationsOf(context)) {
      _shakeController.forward(from: 0);
    }
    return error;
  }

  Widget _eye() => Semantics(
        button: true,
        label: widget.obscureText ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onToggleObscure,
          child: Center(
            child: Icon(
              widget.obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: _eyeSize,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final night = theme.brightness == Brightness.dark;
    final style = theme.textTheme.bodyLarge!.copyWith(
      fontSize: _fontSize,
      color: theme.colorScheme.onSurface,
    );
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
              trailing: widget.onToggleObscure == null ? null : _eye(),
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: widget.keyboardType,
                textDirection: widget.textDirection,
                textAlign: widget.textAlign,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                textCapitalization: widget.textCapitalization,
                obscureText: widget.obscureText,
                style: style,
                cursorColor: theme.colorScheme.onSurface,
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
          if (field.hasError) _ErrorText(field.errorText!),
        ],
      ),
    );
  }
}

/// خانة اختيار بشكل خانة الكتابة: تبدأ فارغة، وتبقى مرفوعة ما دامت قائمتها مفتوحة،
/// وتحمرّ وتهتز إذا ضُغط زر الإرسال قبل الاختيار.
class RaisedPicker extends StatefulWidget {
  const RaisedPicker({
    super.key,
    required this.value,
    required this.hint,
    required this.emptyError,
    required this.open,
    required this.onTap,
  });

  final String? value;
  final String hint;
  final String emptyError;
  final bool open;
  final VoidCallback onTap;

  @override
  State<RaisedPicker> createState() => _RaisedPickerState();
}

class _RaisedPickerState extends State<RaisedPicker> with SingleTickerProviderStateMixin {
  late final _shakeController = AnimationController(vsync: this, duration: _shakeDuration);
  late final _shake = _shakeSteps.animate(_shakeController);

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  String? _validate(String? _) {
    if (widget.value != null) return null;
    if (!MediaQuery.disableAnimationsOf(context)) _shakeController.forward(from: 0);
    return widget.emptyError;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final night = theme.brightness == Brightness.dark;
    final style = theme.textTheme.bodyLarge!.copyWith(
      fontSize: _fontSize,
      color: theme.colorScheme.onSurface,
    );
    final value = widget.value;
    return FormField<String>(
      validator: _validate,
      builder: (field) {
        // الاختيار يصحح الخطأ فوراً، فلا تبقى الحمرة حتى الإرسال التالي.
        final invalid = field.hasError && value == null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: _RaisedBox(
                  focused: widget.open,
                  invalid: invalid,
                  shake: _shake,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          value ?? widget.hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: value != null
                              ? style
                              : style.copyWith(color: night ? _nightHintColor : _hintColor),
                        ),
                      ),
                      Icon(Icons.expand_more_rounded, size: 20, color: theme.colorScheme.onSurface),
                    ],
                  ),
                ),
              ),
            ),
            if (invalid) _ErrorText(field.errorText!),
          ],
        );
      },
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(_paddingX, 4, _paddingX, 0),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
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
    this.trailing,
  });

  final bool focused;
  final bool invalid;
  final Animation<double> shake;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final transition = _motion(context, _transition);
    final content = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        _paddingX + _borderWidth,
        _paddingY + _borderWidth,
        trailing == null ? _paddingX + _borderWidth : _trailingWidth,
        _paddingY + _borderWidth,
      ),
      child: child,
    );
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
            child: trailing == null
                ? content
                : Stack(
                    fit: StackFit.passthrough,
                    children: [
                      content,
                      PositionedDirectional(
                        top: 0,
                        bottom: 0,
                        end: 0,
                        width: _trailingWidth,
                        child: trailing!,
                      ),
                    ],
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

  Color get _focusTone => night ? _nightFocusColor : _focusColor;

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
    final border = Color.lerp(night ? _nightOutline : _outline, _focusTone, focus);
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
          ..color = _focusTone.withValues(alpha: _glowAlpha * focus.clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _glowBlur * focus / 2),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BoxPainter oldDelegate) =>
      oldDelegate.focus != focus || oldDelegate.invalid != invalid || oldDelegate.night != night;
}
