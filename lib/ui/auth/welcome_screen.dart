import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../state/app_state.dart';
import 'day_night_switch.dart';
import 'login_screen.dart';
import 'push_key.dart';
import 'register_screen.dart';
import 'social_marks.dart';
import 'truck_scene.dart';

const _cream = Color(0xFFFFFEE2);
const _blue = Color(0xFF416F9E);
const _ink = Color(0xFF263238);
const _hint = Color(0xFF6B7378);
const _divider = Color(0xFFD3D0C2);
const _label = Color(0xFF383838);
const _wideLine = Color(0xFFDEDBCA);
const _shortLine = Color(0xFFBEB9B3);

// الألوان نفسها في الوضع الليلي: جهة السيارة تبقى صفراء، والخانة تحتها سوداء.
const _nightGround = Colors.black;
const _nightInk = Color(0xFFF4F4EE);
const _nightHint = Color(0xFF9B9BA3);
const _nightDivider = Color(0xFF3A3A40);
const _nightShortLine = Color(0xFF5F5F66);
const _nightError = Color(0xFFF87171);

/// ألوان شريطي النظام في بقية شاشات التطبيق.
SystemUiOverlayStyle _appSystemBars({required bool night}) => SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: night ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    );

/// مقاسات التصميم المعتمد بالبكسل (إطار 391×715)، ومنها تُشتق كل القياسات.
abstract final class _Design {
  static const width = 391.0;
  static const height = 715.0;
  static const blueBottom = 414.3;

  static const barCenter = 34.6;
  static const languageCenter = 35.5;
  static const languageSize = 13.0;
  static const switchLeft = 319.0;
  static const switchRight = 371.1;
  static const switchHeight = 27.25;

  static const codeLeft = 66.65;
  static const codeRight = 144.65;
  static const dividerLeft = 149.15;
  static const dividerRight = 150.65;
  static const numberLeft = 155.65;
  static const numberRight = 309.65;

  // الصف أعلى من الصورة بقليل: عمق الأزرار لا يظهر في الرسم، وبدون هذا تلتصق بزر الدخول.
  static const rowTop = buttonTop - 6 - keyHeight;
  static const dividerTop = rowTop + 1.57;
  static const dividerBottom = dividerTop + 31.1;
  static const faceHeight = 32.74;
  static const keyHeight = faceHeight + PushKey.depth;
  static const rowBottom = rowTop + keyHeight;

  static const buttonLeft = 126.05;
  static const buttonRight = 280.05;
  static const buttonTop = 514.9;
  static const buttonBottom = buttonTop + keyHeight;

  static const wideLineLeft = 99.65;
  static const wideLineRight = 306.48;
  static const wideLineTop = 566.38;
  static const wideLineHeight = 2.0;

  static const privacySize = 11.2;
  static const privacyCenterX = 197.7;
  static const privacyCenterY = 583.9;

  static const shortLineLeft = 179.8;
  static const shortLineRight = 220.95;
  static const privacyLineTop = 604.4;

  // من اليمين: فيسبوك ثم انستغرام ثم تيك توك، وبين قواعد الأزرار مسافة واضحة.
  static const socialCenters = [257.0, 200.0, 143.0];
  static const socialFaceWidth = 34.0;
  static const socialTop = 618.4;
  static const socialFaceHeight = 35.7;
  static const socialBottom = socialTop + socialFaceHeight + PushKey.depth;
  static const socialMarkSize = 19.0;

  static const contactSize = 10.0;
  static const contactCenterX = 198.2;
  static const contactCenterY = 676.4;

  /// لا يظهر هذا الخط في الصورة، وطلبته الملاحظة: بُعده عن الكلام كبُعد خط الخصوصية.
  static const contactLineTop = 695.4;
  static const contentBottom = contactLineTop + 1;

  /// لا تصغر الخانات عن هذا الحد في الهواتف الضيقة حتى تبقى مقروءة.
  static const minControlScale = .95;
}

/// نصوص الشاشة الأولى باللغتين.
class _Words {
  const _Words({
    required this.language,
    required this.changeLanguage,
    required this.nightMode,
    required this.iraqCode,
    required this.mobileNumber,
    required this.login,
    required this.wrongNumber,
    required this.privacy,
    required this.contact,
    required this.socials,
    required this.direction,
  });

  final String language;
  final String changeLanguage;
  final String nightMode;
  final String iraqCode;
  final String mobileNumber;
  final String login;
  final String wrongNumber;
  final String privacy;
  final String contact;
  final List<String> socials;
  final TextDirection direction;
}

const _socialMarks = [SocialMark.facebook, SocialMark.instagram, SocialMark.tiktok];

const _arabic = _Words(
  language: 'AR',
  changeLanguage: 'تغيير اللغة إلى الإنجليزية',
  nightMode: 'الوضع الليلي',
  iraqCode: 'رمز العراق',
  mobileNumber: 'رقم الموبايل',
  login: 'تسجيل الدخول',
  wrongNumber: 'أدخل رقم موبايل عراقي صحيح يبدأ بـ 07',
  privacy: 'سياسة و الخصوصية',
  contact: 'تواصلوا معنى',
  socials: ['فيسبوك', 'انستغرام', 'تيك توك'],
  direction: TextDirection.rtl,
);

const _english = _Words(
  language: 'EN',
  changeLanguage: 'Change language to Arabic',
  nightMode: 'Night mode',
  iraqCode: 'Iraq code',
  mobileNumber: 'Mobile number',
  login: 'Log in',
  wrongNumber: 'Enter a valid Iraqi mobile number starting with 07',
  privacy: 'Privacy Policy',
  contact: 'Contact us',
  socials: ['Facebook', 'Instagram', 'TikTok'],
  direction: TextDirection.ltr,
);

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
  bool _wrongNumber = false;
  bool _nightMode = false;

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
    if (status == AnimationStatus.completed) setState(() => _wrongNumber = false);
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
    SystemChrome.setSystemUIOverlayStyle(_appSystemBars(night: _nightMode));
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  /// لا يوجد تحقق برسالة SMS في التطبيق، لذلك لا يكفي الرقم وحده للدخول:
  /// الرقم المسجل يكمل بكلمة المرور، والرقم الجديد يكمل بإنشاء حساب.
  Future<void> _submit() async {
    final digits = _phone.text;
    final phone = digits.startsWith('0') ? digits : '0$digits';
    if (!validIraqiPhone(phone)) {
      setState(() => _wrongNumber = true);
      _alarm.forward(from: 0);
      return;
    }
    _alarm.reset();
    setState(() {
      _busy = true;
      _wrongNumber = false;
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
          value: _appSystemBars(night: _nightMode),
          child: registered ? LoginScreen(initialPhone: phone) : RegisterScreen(initialPhone: phone),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _nightMode = state.themeMode == ThemeMode.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _nightMode ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      builder: (context, night, _) => _screen(context, state, night),
    );
  }

  Widget _screen(BuildContext context, AppState state, double night) {
    final words = state.english ? _english : _arabic;
    final ground = Color.lerp(_cream, _nightGround, night)!;
    final ink = Color.lerp(_ink, _nightInk, night)!;
    final hint = Color.lerp(_hint, _nightHint, night)!;
    final label = Color.lerp(_label, _nightInk, night)!;
    final shortLine = Color.lerp(_shortLine, _nightShortLine, night)!;

    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeArea = MediaQuery.viewPaddingOf(context);
    final fit = math.min(size.width / _Design.width, size.height / _Design.height);
    final unit = math.max(fit, _Design.minControlScale);

    final blueBottom = size.height * _Design.blueBottom / _Design.height;

    // الهواتف الأطول توزع مساحتها الزائدة فوق الأزرار وتحتها بنسب التصميم.
    final spaceAbove = _Design.rowTop - _Design.blueBottom;
    final spaceBelow = _Design.height - _Design.contentBottom;
    final freeSpace = size.height -
        safeArea.bottom -
        blueBottom -
        (_Design.contentBottom - _Design.rowTop) * unit;
    final rowTop = blueBottom + math.max(freeSpace, 0.0) * spaceAbove / (spaceAbove + spaceBelow);
    double x(double design) => size.width / 2 + (design - _Design.width / 2) * unit;
    double y(double design) => rowTop + (design - _Design.rowTop) * unit;

    // زرا اللغة والوضع يبقيان في زاويتي الشاشة وتحت شريط الحالة في كل الهواتف.
    final barCenter = math.max(
      size.height * _Design.barCenter / _Design.height,
      safeArea.top + 4 + _Design.switchHeight / 2 * unit,
    );
    final switchWidth = (_Design.switchRight - _Design.switchLeft) * unit;
    final switchRight = size.width - (_Design.width - _Design.switchRight) * unit;

    final contentBottom = y(_Design.buttonBottom) + 12;
    final lift = math.max(0.0, contentBottom - (size.height - keyboard));

    // الشاشات القصيرة تعرض الباقي بالسحب، والأطول لا تتحرك.
    final pageHeight = math.max(
      size.height,
      y(_Design.contentBottom) + 12 + safeArea.bottom,
    );

    // هامش اللمس يكمل الأزرار إلى 48 بكسل دون تغيير حجمها الظاهر.
    final touchMargin = 3 * unit;
    const minTouch = 48.0;
    final faceHeight = _Design.faceHeight * unit;

    Widget line(double left, double right, double top, double height, Color color) => Positioned(
          left: x(left),
          width: (right - left) * unit,
          top: y(top),
          height: height * unit,
          child: ColoredBox(color: color),
        );

    Widget caption(String text, double fontSize, double centerX, double centerY) => Positioned(
          left: x(centerX) - 120,
          width: 240,
          top: y(centerY) - 15,
          height: 30,
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: fontSize * unit,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: label,
              ),
            ),
          ),
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _nightMode ? _nightGround : _cream,
        systemNavigationBarIconBrightness: _nightMode ? Brightness.light : Brightness.dark,
      ),
      child: Directionality(
        textDirection: words.direction,
        child: Scaffold(
          backgroundColor: ground,
          resizeToAvoidBottomInset: false,
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _focus.unfocus,
            child: SingleChildScrollView(
              child: SizedBox(
                height: pageHeight,
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
                        child: TruckScene(scale: fit, english: state.english),
                      ),
                      Positioned(
                        left: _Design.languageCenter * unit - minTouch / 2,
                        width: minTouch,
                        top: barCenter - minTouch / 2,
                        height: minTouch,
                        child: Semantics(
                          button: true,
                          label: words.changeLanguage,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => state.setEnglish(!state.english),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  words.language,
                                  key: ValueKey(words.language),
                                  textDirection: TextDirection.ltr,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: _Design.languageSize * unit,
                                    height: 1,
                                    letterSpacing: .8 * unit,
                                    fontWeight: FontWeight.w900,
                                    color: _label,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: switchRight - switchWidth,
                        width: switchWidth,
                        top: barCenter - minTouch / 2,
                        height: minTouch,
                        child: Semantics(
                          button: true,
                          toggled: _nightMode,
                          label: words.nightMode,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => state.setTheme(!_nightMode),
                            child: Center(
                              child: SizedBox(
                                width: double.infinity,
                                height: _Design.switchHeight * unit,
                                child: DayNightSwitch(night: _nightMode),
                              ),
                            ),
                          ),
                        ),
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
                          night: night,
                          child: Center(
                            child: Semantics(
                              label: words.iraqCode,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '🇮🇶 +964',
                                  textDirection: TextDirection.ltr,
                                  style: _textStyle(unit, ink),
                                ),
                              ),
                            ),
                          ),
                        ),
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
                              night: night,
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
                                  style: _textStyle(unit, Color.lerp(ink, Colors.white, alarm)!),
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
                                    hintText: alarm > 0 ? '07XX XXX XXXX' : words.mobileNumber,
                                    hintTextDirection:
                                        alarm > 0 ? TextDirection.ltr : words.direction,
                                    hintStyle: _textStyle(
                                      unit,
                                      Color.lerp(hint, Colors.white, alarm)!,
                                    ).copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      line(
                        _Design.dividerLeft,
                        _Design.dividerRight,
                        _Design.dividerTop,
                        _Design.dividerBottom - _Design.dividerTop,
                        Color.lerp(_divider, _nightDivider, night)!,
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
                          night: night,
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
                                        words.login,
                                        style: _textStyle(unit, ink)
                                            .copyWith(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      line(
                        _Design.wideLineLeft,
                        _Design.wideLineRight,
                        _Design.wideLineTop,
                        _Design.wideLineHeight,
                        Color.lerp(_wideLine, _nightDivider, night)!,
                      ),
                      caption(
                        words.privacy,
                        _Design.privacySize,
                        _Design.privacyCenterX,
                        _Design.privacyCenterY,
                      ),
                      line(
                        _Design.shortLineLeft,
                        _Design.shortLineRight,
                        _Design.privacyLineTop,
                        1,
                        shortLine,
                      ),
                      for (final (index, mark) in _socialMarks.indexed)
                        _touchArea(
                          left: x(_Design.socialCenters[index]) -
                              (_Design.socialFaceWidth / 2 + PushKey.faceInset) * unit,
                          right: x(_Design.socialCenters[index]) +
                              (_Design.socialFaceWidth / 2 + PushKey.faceInset) * unit,
                          top: y(_Design.socialTop),
                          bottom: y(_Design.socialBottom),
                          above: touchMargin,
                          below: touchMargin,
                          onTap: null,
                          child: PushKey(
                            unit: unit,
                            faceHeight: _Design.socialFaceHeight * unit,
                            night: night,
                            child: Semantics(
                              button: true,
                              label: words.socials[index],
                              child: Center(
                                child: SizedBox.square(
                                  dimension: _Design.socialMarkSize * unit,
                                  child: CustomPaint(
                                    painter: SocialMarkPainter(mark, night: night),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      caption(
                        words.contact,
                        _Design.contactSize,
                        _Design.contactCenterX,
                        _Design.contactCenterY,
                      ),
                      line(
                        _Design.shortLineLeft,
                        _Design.shortLineRight,
                        _Design.contactLineTop,
                        1,
                        shortLine,
                      ),
                      if (_wrongNumber)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: pageHeight - y(_Design.rowTop) + 4 * unit,
                          child: AnimatedBuilder(
                            animation: _alarm,
                            builder: (context, child) => Opacity(
                              opacity: (_alarmLevel * 2).clamp(0.0, 1.0),
                              child: child,
                            ),
                            child: Text(
                              words.wrongNumber,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12 * unit,
                                fontWeight: FontWeight.w700,
                                color: Color.lerp(AppColors.danger, _nightError, night),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _textStyle(double unit, Color color) => TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13 * unit,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: color,
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
