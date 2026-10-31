import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../state/app_state.dart';
import 'login_screen.dart';
import 'push_key.dart';
import 'register_screen.dart';
import 'truck_scene.dart';

const _cream = Color(0xFFFFFEE2);
const _blue = Color(0xFF416F9E);
const _ink = Color(0xFF263238);
const _hint = Color(0xFF6B7378);
const _divider = Color(0xFFD3D0C2);

/// ألوان شريطي النظام في بقية شاشات التطبيق.
const _appSystemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.black,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// مقاسات التصميم المعتمد بالبكسل (إطار 391×715)، ومنها تُشتق كل القياسات.
abstract final class _Design {
  static const width = 391.0;
  static const height = 715.0;
  static const blueBottom = 414.3;

  static const codeLeft = 68.0;
  static const codeRight = 146.0;
  static const dividerLeft = 150.5;
  static const dividerRight = 152.0;
  static const dividerTop = 539.4;
  static const dividerBottom = 570.5;
  static const numberLeft = 157.0;
  static const numberRight = 311.0;
  static const rowTop = 537.76;
  static const faceHeight = 32.74;
  static const keyHeight = faceHeight + PushKey.depth;
  static const rowBottom = rowTop + keyHeight;

  static const buttonLeft = 127.3;
  static const buttonRight = 281.3;
  static const buttonTop = rowBottom + 6;
  static const buttonBottom = buttonTop + keyHeight;

  /// لا تصغر الخانات عن هذا الحد في الهواتف الضيقة حتى تبقى مقروءة.
  static const minControlScale = .95;
}

/// أرقام الموبايل فقط: يحوّل الأرقام العربية ويحذف +964 عند اللصق.
class _IraqiPhoneFormatter extends TextInputFormatter {
  const _IraqiPhoneFormatter();

  static const _eastern = '٠١٢٣٤٥٦٧٨٩';
  static const _persian = '۰۱۲۳۴۵۶۷۸۹';

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final buffer = StringBuffer();
    for (final char in newValue.text.characters) {
      final eastern = _eastern.indexOf(char);
      final persian = _persian.indexOf(char);
      if (eastern >= 0) {
        buffer.write(eastern);
      } else if (persian >= 0) {
        buffer.write(persian);
      } else if (RegExp(r'\d').hasMatch(char)) {
        buffer.write(char);
      }
    }
    var digits = buffer.toString();
    if (digits.startsWith('964')) digits = digits.substring(3);
    final limit = digits.startsWith('0') ? 11 : 10;
    if (digits.length > limit) digits = digits.substring(0, limit);
    if (digits == newValue.text) return newValue;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  final _phone = TextEditingController();
  final _focus = FocusNode();
  late final _alarm = AnimationController(vsync: this, duration: _alarmDuration)
    ..addStatusListener(_onAlarmStatus);
  bool _busy = false;
  String? _error;

  static const _alarmDuration = Duration(milliseconds: 2800);
  static const _alarmHoldSeconds = .4;

  /// الخانة تصير حمراء بالكامل لحظة الخطأ، ثم ترجع ببطء إلى لونها الطبيعي.
  double get _alarmLevel {
    if (!_alarm.isAnimating) return 0;
    final total = _alarmDuration.inMilliseconds / 1000;
    final seconds = _alarm.value * total;
    if (seconds < _alarmHoldSeconds) return 1;
    final fade = (seconds - _alarmHoldSeconds) / (total - _alarmHoldSeconds);
    return 1 - Curves.easeInOut.transform(fade);
  }

  void _onAlarmStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) setState(() => _error = null);
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _alarm.dispose();
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _phone.dispose();
    SystemChrome.setSystemUIOverlayStyle(_appSystemBars);
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  /// لا يوجد تحقق برسالة SMS في التطبيق، لذلك لا يكفي الرقم وحده للدخول:
  /// الرقم المسجل يكمل بكلمة المرور، والرقم الجديد يكمل بإنشاء حساب.
  Future<void> _submit() async {
    final digits = _phone.text;
    final phone = digits.startsWith('0') ? digits : '0$digits';
    if (!validIraqiPhone(phone)) {
      setState(() => _error = 'أدخل رقم موبايل عراقي صحيح يبدأ بـ 07');
      _alarm.forward(from: 0);
      return;
    }
    _alarm.reset();
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = context.read<AppState>().repo;
    final registered = await repo.phoneExists(phone);
    if (!mounted) return;
    setState(() => _busy = false);
    _focus.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: _appSystemBars,
          child: registered ? LoginScreen(initialPhone: phone) : RegisterScreen(initialPhone: phone),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final fit = math.min(size.width / _Design.width, size.height / _Design.height);
    final unit = math.max(fit, _Design.minControlScale);

    final blueBottom = size.height * _Design.blueBottom / _Design.height;
    final rowTop = blueBottom +
        (size.height - blueBottom) *
            (_Design.rowTop - _Design.blueBottom) /
            (_Design.height - _Design.blueBottom);
    double x(double design) => size.width / 2 + (design - _Design.width / 2) * unit;
    double y(double design) => rowTop + (design - _Design.rowTop) * unit;

    final errorTop = y(_Design.buttonBottom) + 8 * unit;
    final contentBottom = (_error == null ? y(_Design.buttonBottom) : errorTop + 22 * unit) + 12;
    final lift = math.max(0.0, contentBottom - (size.height - keyboard));

    // هامش اللمس يكمل الأزرار إلى 48 بكسل دون تغيير حجمها الظاهر.
    final touchMargin = 3 * unit;
    final faceHeight = _Design.faceHeight * unit;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _cream,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _cream,
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _focus.unfocus,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: lift),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            builder: (context, value, child) =>
                Transform.translate(offset: Offset(0, -value), child: child),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: blueBottom,
                  child: TruckScene(scale: fit),
                ),
                _touchArea(
                  left: x(_Design.codeLeft),
                  right: x(_Design.codeRight),
                  top: y(_Design.rowTop),
                  bottom: y(_Design.rowBottom),
                  above: touchMargin,
                  below: touchMargin,
                  onTap: _focus.requestFocus,
                  child: PushKey(
                    unit: unit,
                    faceHeight: faceHeight,
                    child: Center(
                      child: Semantics(
                        label: 'رمز العراق',
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '🇮🇶 +964',
                            textDirection: TextDirection.ltr,
                            style: _textStyle(unit),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: x(_Design.dividerLeft),
                  width: (_Design.dividerRight - _Design.dividerLeft) * unit,
                  top: y(_Design.dividerTop),
                  bottom: size.height - y(_Design.dividerBottom),
                  child: const ColoredBox(color: _divider),
                ),
                _touchArea(
                  left: x(_Design.numberLeft),
                  right: x(_Design.numberRight),
                  top: y(_Design.rowTop),
                  bottom: y(_Design.rowBottom),
                  above: touchMargin,
                  below: touchMargin,
                  onTap: _focus.requestFocus,
                  child: AnimatedBuilder(
                    animation: _alarm,
                    builder: (context, _) {
                      final alarm = _alarmLevel;
                      return PushKey(
                        unit: unit,
                        faceHeight: faceHeight,
                        alarm: alarm,
                        borderColor: _focus.hasFocus ? _blue : null,
                        child: Center(
                          child: TextField(
                            controller: _phone,
                            focusNode: _focus,
                            enabled: !_busy,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.center,
                            textAlignVertical: TextAlignVertical.center,
                            cursorColor: Color.lerp(_blue, Colors.white, alarm),
                            inputFormatters: const [_IraqiPhoneFormatter()],
                            style: _textStyle(unit).copyWith(
                              color: Color.lerp(_ink, Colors.white, alarm),
                            ),
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              hintText: alarm > 0 ? '07XX XXX XXXX' : 'رقم الموبايل',
                              hintTextDirection:
                                  alarm > 0 ? TextDirection.ltr : TextDirection.rtl,
                              hintStyle: _textStyle(unit).copyWith(
                                color: Color.lerp(_hint, Colors.white, alarm),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _touchArea(
                  left: x(_Design.buttonLeft),
                  right: x(_Design.buttonRight),
                  top: y(_Design.buttonTop),
                  bottom: y(_Design.buttonBottom),
                  above: touchMargin,
                  below: touchMargin,
                  onTap: _busy ? null : _submit,
                  child: PushKey(
                    unit: unit,
                    faceHeight: faceHeight,
                    held: _busy,
                    child: Semantics(
                      button: true,
                      enabled: !_busy,
                      child: Center(
                        child: _busy
                            ? SizedBox(
                                width: 16 * unit,
                                height: 16 * unit,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _blue,
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'تسجيل الدخول',
                                  style: _textStyle(unit).copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: errorTop,
                    child: AnimatedBuilder(
                      animation: _alarm,
                      builder: (context, child) => Opacity(
                        opacity: (_alarmLevel * 2).clamp(0.0, 1.0),
                        child: child,
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12 * unit,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _textStyle(double unit) => TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13 * unit,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: _ink,
      );

  Widget _touchArea({
    required double left,
    required double right,
    required double top,
    required double bottom,
    required double above,
    required double below,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return Positioned(
      left: left,
      width: right - left,
      top: top - above,
      height: bottom - top + above + below,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(top: above, bottom: below),
          child: child,
        ),
      ),
    );
  }
}
