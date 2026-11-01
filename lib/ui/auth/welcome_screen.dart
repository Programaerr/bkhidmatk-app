import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../state/app_state.dart';
import 'craftsman_screen.dart';
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
  static const barGap = 24.0;
  static const languageLeft = 27.3;
  static const languageSize = 13.0;
  static const globeSize = 16.0;
  static const switchLeft = 319.0;
  static const switchRight = 371.1;
  static const switchHeight = 27.25;

  // طرفا الصف على طرفي الصف الذي تحته، فيبدوان عموداً واحداً.
  static const codeLeft = craftsmanLeft;
  static const codeRight = 146.1;
  static const dividerLeft = 150.65;
  static const dividerRight = 152.15;
  static const numberLeft = 160.6;
  static const numberRight = buttonRight;

  // الصف أعلى من الصورة بقليل: عمق الأزرار لا يظهر في الرسم، وبدون هذا تلتصق بزر الدخول.
  static const rowTop = buttonTop - 6 - keyHeight;
  static const dividerTop = rowTop + 1.57;
  static const dividerBottom = dividerTop + 31.1;
  static const faceHeight = 32.74;
  static const keyHeight = faceHeight + PushKey.depth;
  static const rowBottom = rowTop + keyHeight;

  // زرا الحرفي والدخول في صف واحد، والصف في منتصف الشاشة.
  static const craftsmanLeft = 67.2;
  static const craftsmanRight = 188.6;
  static const buttonLeft = 202.4;
  static const buttonRight = 323.8;
  static const buttonTop = 483.14;
  static const buttonBottom = buttonTop + keyHeight;

  // زر الحساب صف كامل تحتهما، والمسافة فوقه 80% من مسافة الصفين الأولين كما في الصورة.
  static const accountTop = buttonBottom + 4.8;
  static const accountBottom = accountTop + keyHeight;

  static const wideLineLeft = 92.63;
  static const wideLineRight = 299.46;
  static const wideLineTop = accountBottom + 6.74;
  static const wideLineHeight = 2.0;

  static const privacySize = 11.2;
  static const privacyCenterX = 191.2;
  static const privacyCenterY = 601.68;

  static const shortLineLeft = 172.64;
  static const shortLineRight = 213.79;
  static const privacyLineTop = 622.18;

  // من اليمين: فيسبوك ثم انستغرام ثم تيك توك، وبين قواعد الأزرار مسافة واضحة.
  static const socialCenters = [250.0, 193.0, 136.0];
  static const socialFaceWidth = 34.0;
  static const socialTop = 636.18;
  static const socialFaceHeight = 35.7;
  static const socialBottom = socialTop + socialFaceHeight + PushKey.depth;
  static const socialMarkSize = 19.0;

  static const contactSize = 10.0;
  static const contactCenterX = 191.2;
  static const contactCenterY = 694.18;

  /// لا يظهر هذا الخط في الصورة، وطلبته الملاحظة: بُعده عن الكلام كبُعد خط الخصوصية.
  static const contactLineTop = 713.18;
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
    required this.craftsman,
    required this.account,
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
  final String craftsman;
  final String account;
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
  craftsman: 'حرفي',
  account: 'هل لديك حساب',
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
  craftsman: 'Craftsman',
  account: 'Have an account?',
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

/// انتقال الصفحة المعتاد نفسه، لكنه أسرع منه بأكثر من الضعف.
class _QuickRoute extends MaterialPageRoute<void> {
  _QuickRoute({required super.builder});

  static const _duration = Duration(milliseconds: 200);

  @override
  Duration get transitionDuration => _duration;

  @override
  Duration get reverseTransitionDuration => _duration;
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  final _phone = TextEditingController();
  final _focus = FocusNode();
  late final _alarm = AnimationController(vsync: this, duration: _alarmDuration)
    ..addStatusListener(_onAlarmStatus);
  late final _nightController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  late final _night = CurvedAnimation(parent: _nightController, curve: Curves.easeInOut);
  late final _alarmAndNight = Listenable.merge([_alarm, _night]);
  late final AppState _appState;
  bool _busy = false;
  bool _wrongNumber = false;
  bool _nightMode = false;
  bool _reduceMotion = false;

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

  void _onAppStateChanged() {
    final night = _appState.themeMode == ThemeMode.dark;
    if (night == _nightMode) return;
    _nightMode = night;
    if (_reduceMotion) {
      _nightController.value = night ? 1 : 0;
    } else if (night) {
      _nightController.forward();
    } else {
      _nightController.reverse();
    }
  }

  void _onNightStatus(AnimationStatus status) => setState(() {});

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    _appState = context.read<AppState>()..addListener(_onAppStateChanged);
    _nightMode = _appState.themeMode == ThemeMode.dark;
    _nightController
      ..value = _nightMode ? 1 : 0
      ..addStatusListener(_onNightStatus);
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    _night.dispose();
    _nightController.dispose();
    _alarm.dispose();
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _phone.dispose();
    SystemChrome.setSystemUIOverlayStyle(_appSystemBars(night: _nightMode));
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  String get _typedPhone {
    final digits = _phone.text;
    return digits.startsWith('0') ? digits : '0$digits';
  }

  void _openCraftsman() => _openWithPhone((phone) => CraftsmanScreen(initialPhone: phone));

  void _openLogin() => _openWithPhone((phone) => LoginScreen(initialPhone: phone));

  void _openWithPhone(Widget Function(String? phone) page) {
    final phone = _typedPhone;
    _focus.unfocus();
    Navigator.push(
      context,
      _QuickRoute(
        builder: (_) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: _appSystemBars(night: _nightMode),
          child: page(validIraqiPhone(phone) ? phone : null),
        ),
      ),
    );
  }

  /// لا يوجد تحقق برسالة SMS في التطبيق، لذلك لا يكفي الرقم وحده للدخول:
  /// الرقم المسجل يكمل بكلمة المرور، والرقم الجديد يكمل بإنشاء حساب.
  Future<void> _submit() async {
    final phone = _typedPhone;
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
          child:
              registered ? LoginScreen(initialPhone: phone) : RegisterScreen(initialPhone: phone),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final words = state.english ? _english : _arabic;

    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeArea = MediaQuery.viewPaddingOf(context);
    final fit = math.min(size.width / _Design.width, size.height / _Design.height);
    final unit = math.max(fit, _Design.minControlScale);

    final blueBottom = size.height * _Design.blueBottom / _Design.height;

    // الفراغ فوق الأزرار مثل الفراغ تحتها. شريط التنقل بلون الصفحة، فيمتد الفراغ السفلي إلى أيقوناته.
    const navIconsGap = 14.0;
    final freeSpace = size.height -
        safeArea.bottom -
        blueBottom -
        (_Design.contentBottom - _Design.rowTop) * unit;
    final rowTop = blueBottom + math.max(freeSpace + navIconsGap, 0.0) / 2;
    double x(double design) => size.width / 2 + (design - _Design.width / 2) * unit;
    double y(double design) => rowTop + (design - _Design.rowTop) * unit;

    // زرا اللغة والوضع يبقيان في زاويتي الشاشة وتحت شريط الحالة في كل الهواتف.
    final barCenter = math.max(
      size.height * _Design.barCenter / _Design.height,
      safeArea.top + _Design.barGap + _Design.switchHeight / 2 * unit,
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
    const languageMargin = 12.0;
    final faceHeight = _Design.faceHeight * unit;

    Widget line(double left, double right, double top, double height, Color day, Color dark) =>
        Positioned(
          left: x(left),
          width: (right - left) * unit,
          top: y(top),
          height: height * unit,
          child: _dayNight((night) => ColoredBox(color: night ? dark : day)),
        );

    Widget caption(String text, double fontSize, double centerX, double centerY) => Positioned(
          left: x(centerX) - 120,
          width: 240,
          top: y(centerY) - 15,
          height: 30,
          child: Center(
            child: _dayNight(
              (night) => Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: fontSize * unit,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: night ? _nightInk : _label,
                ),
              ),
            ),
          ),
        );

    return AnimatedBuilder(
      animation: _night,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Color.lerp(_cream, _nightGround, _night.value),
          systemNavigationBarIconBrightness: _night.value < .5 ? Brightness.dark : Brightness.light,
        ),
        child: child!,
      ),
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _dayNight((night) => ColoredBox(color: night ? _nightGround : _cream)),
            Directionality(
              textDirection: words.direction,
              child: Scaffold(
                backgroundColor: Colors.transparent,
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
                              left: _Design.languageLeft * unit - languageMargin,
                              top: barCenter - minTouch / 2,
                              height: minTouch,
                              child: Semantics(
                                button: true,
                                label: words.changeLanguage,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => state.setEnglish(!state.english),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: languageMargin),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      textDirection: TextDirection.ltr,
                                      children: [
                                        Icon(
                                          Icons.public,
                                          size: _Design.globeSize * unit,
                                          color: _label,
                                        ),
                                        SizedBox(width: 4 * unit),
                                        AnimatedSwitcher(
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
                                      ],
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
                                night: _night,
                                child: Center(
                                  child: Semantics(
                                    label: words.iraqCode,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _dayNight(
                                        (night) => Text(
                                          '🇮🇶 +964',
                                          textDirection: TextDirection.ltr,
                                          style: _textStyle(unit, night ? _nightInk : _ink),
                                        ),
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
                                // لون الأرقام المكتوبة وحده يحتاج إعادة البناء مع تدرج الليل.
                                animation: _phone.text.isEmpty ? _alarm : _alarmAndNight,
                                builder: (context, _) {
                                  final alarm = _alarmLevel;
                                  final hintStyle = _textStyle(unit, Colors.white)
                                      .copyWith(fontWeight: FontWeight.w600);
                                  return PushKey(
                                    unit: unit,
                                    faceHeight: faceHeight,
                                    alarm: alarm,
                                    night: _night,
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
                                        style: _textStyle(
                                          unit,
                                          Color.lerp(
                                            Color.lerp(_ink, _nightInk, _night.value),
                                            Colors.white,
                                            alarm,
                                          )!,
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
                                          // صيغة الرقم تذوب أولاً ثم يظهر نص الخانة، فلا يتداخلان ولا يقفزان.
                                          hint: alarm >= .5
                                              ? Text(
                                                  '07XX XXX XXXX',
                                                  textAlign: TextAlign.center,
                                                  textDirection: TextDirection.ltr,
                                                  style: hintStyle.copyWith(
                                                    color: Colors.white.withValues(
                                                      alpha: (alarm - .5) * 2,
                                                    ),
                                                  ),
                                                )
                                              : _dayNight(
                                                  (night) => Text(
                                                    words.mobileNumber,
                                                    textAlign: TextAlign.center,
                                                    textDirection: words.direction,
                                                    style: hintStyle.copyWith(
                                                      color: (night ? _nightHint : _hint)
                                                          .withValues(alpha: (.5 - alarm) * 2),
                                                    ),
                                                  ),
                                                ),
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
                              _divider,
                              _nightDivider,
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
                                night: _night,
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
                                            child: _dayNight(
                                              (night) => Text(
                                                words.login,
                                                style: _textStyle(unit, night ? _nightInk : _ink)
                                                    .copyWith(fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            _touchArea(
                              left: x(_Design.craftsmanLeft),
                              right: x(_Design.craftsmanRight),
                              top: y(_Design.buttonTop),
                              bottom: y(_Design.buttonBottom),
                              above: touchMargin,
                              below: touchMargin,
                              onTap: _busy ? null : _openCraftsman,
                              child: PushKey(
                                unit: unit,
                                faceHeight: faceHeight,
                                night: _night,
                                child: Semantics(
                                  button: true,
                                  enabled: !_busy,
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _dayNight(
                                        (night) => Text(
                                          words.craftsman,
                                          style: _textStyle(unit, night ? _nightInk : _ink)
                                              .copyWith(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _touchArea(
                              left: x(_Design.craftsmanLeft),
                              right: x(_Design.buttonRight),
                              top: y(_Design.accountTop),
                              bottom: y(_Design.accountBottom),
                              above: touchMargin,
                              below: touchMargin,
                              onTap: _busy ? null : _openLogin,
                              child: PushKey(
                                unit: unit,
                                faceHeight: faceHeight,
                                night: _night,
                                yellow: true,
                                child: Semantics(
                                  button: true,
                                  enabled: !_busy,
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      // الزر أصفر نهاراً وليلاً، فكتابته داكنة دائماً.
                                      child: Text(
                                        words.account,
                                        style: _textStyle(unit, _ink)
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
                              _wideLine,
                              _nightDivider,
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
                              _shortLine,
                              _nightShortLine,
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
                                  night: _night,
                                  child: Semantics(
                                    button: true,
                                    label: words.socials[index],
                                    child: Center(
                                      child: SizedBox.square(
                                        dimension: _Design.socialMarkSize * unit,
                                        child: _socialMark(mark),
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
                              _shortLine,
                              _nightShortLine,
                            ),
                            if (_wrongNumber)
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: pageHeight - y(_Design.rowTop) + 4 * unit,
                                child: AnimatedBuilder(
                                  animation: _alarmAndNight,
                                  builder: (context, _) => Opacity(
                                    opacity: (_alarmLevel * 2).clamp(0.0, 1.0),
                                    child: Text(
                                      words.wrongNumber,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12 * unit,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            Color.lerp(AppColors.danger, _nightError, _night.value),
                                      ),
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
          ],
        ),
      ),
    );
  }

  /// جزء يتدرج بين شكليه بطبقة ليلية تذوب فوقه، فلا يُعاد بناؤه ولا رسمه مع كل إطار.
  Widget _dayNight(Widget Function(bool night) builder) {
    if (!_nightController.isAnimating) return builder(_nightMode);
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.passthrough,
      children: [
        builder(false),
        FadeTransition(opacity: _night, child: builder(true)),
      ],
    );
  }

  Widget _socialMark(SocialMark mark) {
    Widget paint(bool night) => CustomPaint(painter: SocialMarkPainter(mark, night: night));
    return mark == SocialMark.tiktok ? _dayNight(paint) : paint(false);
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
    // بداية الزر على بكسل كامل من الشاشة، فتبقى صورته حادة الحواف.
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    double onPixel(double value) => (value * pixelRatio).roundToDouble() / pixelRatio;
    return Positioned(
      left: onPixel(left),
      width: onPixel(right) - onPixel(left),
      top: onPixel(top) - above,
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
