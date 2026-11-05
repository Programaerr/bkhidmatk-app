import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../auth/push_key.dart';
import '../auth/truck_scene.dart';
import '../widgets/quick_route.dart';
import '../widgets/ui.dart';
import 'craftsman_info_screen.dart';

const homeCream = Color(0xFFFFFEE2);
const homeNightGround = Colors.black;
const homeInk = Color(0xFF263238);
const homeNightInk = Color(0xFFF4F4EE);
const homeLabel = Color(0xFF383838);

/// عرض التصميم، ومنه تُشتق كل القياسات.
const homeDesignWidth = 391.0;

/// مقياس الصفحة الرئيسية على عرض معين. في الشاشات الكبيرة تتوسط الصفحة ولا تكبر بلا حد.
double homeUnit(double width) => math.min(width / homeDesignWidth, 1.25);

/// مقياس جانب الزر وقاعدته: أرفع من الشاشة الأولى حتى لا تتلامس أزرار هذه الصفحة.
const homeKeyChrome = .75;

// الجهة الصفراء: مستطيل ينتهي بقطع ناقص مركزه أقرب إلى اليسار، فحافتها اليسرى أوطأ من اليمنى.
const _hillCenterX = 189.0;
const _hillCenterY = 79.2;
const _hillRadiusX = 203.0;
const _hillRadiusY = 35.0;

// لا يدخل أول زر تحت شريط الحالة في الهواتف التي شريطها أطول من حافة التصميم.
const _statusBarGap = 10.0;
const _firstKeyTop = 30.85;

/// نزول الصفحة تحت شريط الحالة.
double homePageTop(double safeTop, double unit) =>
    math.max(0.0, safeTop + _statusBarGap - _firstKeyTop * unit);

/// أسفل الجهة الصفراء.
double homeHillBottom(double top, double unit) => top + (_hillCenterY + _hillRadiusY) * unit;

// الجهة الصفراء بعد أن تنطوي إلى شريط: ارتفاعه تحت شريط الحالة، وانحناء حافته، ومقياس ما فيه.
const _foldedBar = 54.0;
const _foldedRadiusY = 9.0;
const _foldedScale = .8;

// أبعد ما يتابعه الطي من تمرير الصفحة، فلا يعاد البناء بعده.
const _foldTrackLimit = 240.0;

/// حال الجهة الصفراء: مفتوحة بحجمها الكامل في أعلى الصفحة، أو منطوية إلى شريط رفيع حين تنزل الصفحة.
///
/// الجهة الكاملة تأخذ خُمس الشاشة في كل تبويب، فتنطوي كلما قرأ الزبون ما تحتها وتعود إذا رجع إلى الأعلى.
@immutable
class HomeHeaderMetrics {
  const HomeHeaderMetrics({
    required this.unit,
    required this.safeTop,
    required this.top,
    this.fold = 0,
  });

  final double unit;
  final double safeTop;

  /// نزول الصفحة تحت شريط الحالة، من [homePageTop].
  final double top;

  /// 0 مفتوحة، و1 شريط.
  final double fold;

  double get openHeight => homeHillBottom(top, unit);

  double get barHeight => math.min(safeTop + _foldedBar, openHeight);

  /// كم يلزم أن تنزل الصفحة حتى تنطوي الجهة كلها.
  double get foldDistance => math.max(openHeight - barHeight, 1.0);

  /// ارتفاعها الآن، بقوسها السفلي.
  double get height => openHeight + (barHeight - openHeight) * fold;

  /// مقياس ما فيها من أزرار وعنوان.
  double get scale => 1 + (_foldedScale - 1) * fold;

  /// وسط ما فيها رأسياً، من وسطه في التصميم المفتوح إلى وسط الشريط.
  double centerY(double designCenter) {
    final folded = safeTop + _foldedBar / 2 - 2;
    final open = top + designCenter * unit;
    return open + (folded - open) * fold;
  }

  double get _radiusY => _hillRadiusY * unit + (_foldedRadiusY - _hillRadiusY * unit) * fold;

  double get _curveCenterY => height - _radiusY;
}

/// يتابع تمرير الصفحة التي تحت الجهة الصفراء ليطويها.
class HeaderFold extends ValueNotifier<double> {
  HeaderFold() : super(0);

  /// يلف القائمة التي يتابع تمريرها.
  Widget track({required Widget child}) => NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
            value = notification.metrics.pixels.clamp(0.0, _foldTrackLimit);
          }
          return false;
        },
        child: child,
      );
}

/// الجهة الصفراء في أعلى الصفحة، بارتفاع يتبع طيّها. توضع داخل [Stack] فوق القائمة.
class FoldingHeader extends StatelessWidget {
  const FoldingHeader({
    super.key,
    required this.fold,
    required this.unit,
    required this.safeTop,
    required this.top,
    required this.builder,
  });

  final HeaderFold fold;
  final double unit;
  final double safeTop;
  final double top;
  final Widget Function(BuildContext context, HomeHeaderMetrics metrics) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: fold,
      builder: (context, offset, _) {
        final open = HomeHeaderMetrics(unit: unit, safeTop: safeTop, top: top);
        final metrics = HomeHeaderMetrics(
          unit: unit,
          safeTop: safeTop,
          top: top,
          fold: (offset / open.foldDistance).clamp(0.0, 1.0),
        );
        return Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: metrics.height,
          child: builder(context, metrics),
        );
      },
    );
  }
}

// عنوان الصفحة في الجهة الصفراء.
const _titleCenter = 61.5;
const _titleHeight = 32.0;
const _titleSize = 20.3;

// أزرار الاختيار: الأقصر منها بعرض التصميم، والأطول بقدر اسمها.
const _choiceMinWidth = 56.7;
const _choiceRadius = 10.7;
const _choiceTextSize = 11.0;
const _choicePadding = 10.0;

// عرض الزر يُقرَّب إلى هذا الحد، فتتشارك الأزرار المتقاربة صورة واحدة.
const _choiceWidthStep = 8.0;

// الأقسام: أربعة في الصف، ومراكزها من يمين الإطار إلى يساره، وهي في وسط الشاشة.
const homeSectionRightCenter = 333.5;
const homeSectionLeftCenter = 57.5;
const _sectionCenters = [homeSectionRightCenter, 241.5, 149.5, homeSectionLeftCenter];
const _sectionFace = 51.1;
const _sectionRowPitch = 86.0;
const _sectionLabelWidth = 90.0;
const _sectionLabelGap = 3.0;
const _sectionLabelSize = 10.5;
const _sectionIconSize = 25.0;

// الحرفيون: زران في الصف، ومكان وجه كل منهما من يسار الإطار.
const _craftsmanLefts = [200.0, 11.6];
const _craftsmanWidth = 173.0;
const _craftsmanHeight = 54.8;
const _craftsmanRowPitch = 69.65;
const _craftsmanRadius = 8.0;
const _craftsmanCircle = 37.0;
const _craftsmanCircleMargin = 10.2;
const _craftsmanTextGap = 6.5;
const _craftsmanTextMargin = 6.0;
const _craftsmanNameSize = 11.5;
const _craftsmanWorkSize = 9.5;
const _ratingMargin = 7.2;
const _ratingBottom = 5.0;
const _ratingRoom = 30.0;
const _ratingSize = 9.5;
const _ratingStarSize = 11.0;

/// الجهة الصفراء العليا بحافتها المنحنية من الأسفل.
class HomeHill extends StatelessWidget {
  const HomeHill({super.key, required this.width, required this.metrics});

  final double width;
  final HomeHeaderMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HillPainter(
        bottom: metrics._curveCenterY,
        centerX: _hillCenterX * width / homeDesignWidth,
        radiusX: _hillRadiusX * width / homeDesignWidth,
        radiusY: metrics._radiusY,
      ),
    );
  }
}

class _HillPainter extends CustomPainter {
  const _HillPainter({
    required this.bottom,
    required this.centerX,
    required this.radiusX,
    required this.radiusY,
  });

  final double bottom;
  final double centerX;
  final double radiusX;
  final double radiusY;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTRB(0, 0, size.width, bottom))
        ..addOval(Rect.fromCenter(
          center: Offset(centerX, bottom),
          width: radiusX * 2,
          height: radiusY * 2,
        )),
      Paint()..color = TruckSceneMetrics.hillColor,
    );
  }

  @override
  bool shouldRepaint(_HillPainter oldDelegate) =>
      oldDelegate.bottom != bottom ||
      oldDelegate.centerX != centerX ||
      oldDelegate.radiusX != radiusX ||
      oldDelegate.radiusY != radiusY;
}

/// الجهة الصفراء وعنوان الصفحة فيها.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.width,
    required this.metrics,
    required this.title,
    this.titleShift = 0,
  });

  final double width;
  final HomeHeaderMetrics metrics;
  final String title;

  /// بُعد العنوان عن وسط الشاشة نحو اليمين، بوحدات التصميم.
  final double titleShift;

  @override
  Widget build(BuildContext context) {
    final unit = metrics.unit;
    final height = _titleHeight * unit * metrics.scale;
    return Stack(
      fit: StackFit.expand,
      children: [
        HomeHill(width: width, metrics: metrics),
        Positioned(
          left: 2 * titleShift * unit,
          right: 0,
          top: metrics.centerY(_titleCenter) - height / 2,
          height: height,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: _titleSize * unit * metrics.scale,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: homeLabel,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// زر اختيار: أبيض، والمختار منها بلون أزرار الحرفيين.
class ChoiceKey extends StatelessWidget {
  const ChoiceKey({
    super.key,
    required this.label,
    required this.selected,
    required this.unit,
    required this.onPressed,
  });

  /// ارتفاع وجه الزر بوحدات التصميم.
  static const faceHeight = 25.7;

  /// مساحة اللمس فوق الزر وتحته بوحدات التصميم.
  static const touchMargin = 6.0;

  final String label;
  final bool selected;
  final double unit;
  final VoidCallback onPressed;

  double _faceWidth(BuildContext context, TextStyle style) {
    final text = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.rtl,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final needed = text.width + _choicePadding * 2 * unit;
    text.dispose();
    if (needed <= _choiceMinWidth * unit) return _choiceMinWidth * unit;
    final step = _choiceWidthStep * unit;
    return (needed / step).ceil() * step;
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final chrome = unit * homeKeyChrome;
    final faceHeight = ChoiceKey.faceHeight * unit;
    final style = TextStyle(
      fontFamily: 'Cairo',
      fontSize: _choiceTextSize * unit,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: night && !selected ? homeNightInk : homeInk,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: touchMargin * unit),
          child: SizedBox(
            width: _faceWidth(context, style) + PushKey.faceInset * 2 * chrome,
            height: faceHeight + PushKey.depth * chrome,
            child: PushKey(
              unit: chrome,
              faceHeight: faceHeight,
              faceRadius: _choiceRadius,
              lemon: selected,
              night: night ? kAlwaysCompleteAnimation : kAlwaysDismissedAnimation,
              child: ExcludeSemantics(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, maxLines: 1, style: style),
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

/// صورة الشخص، ورمز شخص إن لم تكن له صورة.
class PersonFace extends StatelessWidget {
  const PersonFace({
    super.key,
    required this.name,
    required this.imagePath,
    required this.size,
    required this.color,
  });

  final String name;
  final String? imagePath;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final hasImage = path != null && (path.startsWith('http') || fileExists(path));
    if (!hasImage) return Icon(Icons.person_rounded, size: size * .62, color: color);
    return AvatarCircle(name: name, size: size, imagePath: path, bg: Colors.white);
  }
}

/// زر قسم: دائرة بأيقونة القسم، واسمه تحتها. بلا قسم تظهر الدائرة فارغة إلى أن تصل البيانات.
class SectionKey extends StatelessWidget {
  const SectionKey({super.key, required this.unit, this.section, this.onOpen});

  final double unit;
  final Category? section;
  final ValueChanged<Category>? onOpen;

  @override
  Widget build(BuildContext context) {
    final section = this.section;
    final night = Theme.of(context).brightness == Brightness.dark;
    final chrome = unit * homeKeyChrome;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PushKeyCircle(
          diameter: _sectionFace * unit,
          unit: chrome,
          label: section?.name ?? '',
          onPressed: section == null || onOpen == null ? null : () => onOpen!(section),
          child: section == null
              ? const SizedBox.shrink()
              : Icon(
                  appIcon(section.icon),
                  size: _sectionIconSize * unit,
                  color: night ? homeNightInk : homeInk,
                ),
        ),
        SizedBox(height: _sectionLabelGap * unit),
        if (section != null)
          ExcludeSemantics(
            child: Text(
              section.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: _sectionLabelSize * unit,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: night ? homeNightInk : homeLabel,
              ),
            ),
          ),
      ],
    );
  }
}

/// الأقسام في صفوف، كل صف أربعة. بلا قائمة تظهر [placeholders] دوائر فارغة.
class SectionGrid extends StatelessWidget {
  const SectionGrid({
    super.key,
    required this.unit,
    this.sections,
    this.placeholders = 8,
    this.onOpen,
  });

  final double unit;
  final List<Category>? sections;
  final int placeholders;
  final ValueChanged<Category>? onOpen;

  static double heightOf(int count, double unit) =>
      (count / 4).ceil() * _sectionRowPitch * unit;

  @override
  Widget build(BuildContext context) {
    final sections = this.sections;
    final count = sections?.length ?? placeholders;
    return SizedBox(
      width: homeDesignWidth * unit,
      height: heightOf(count, unit),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: (_sectionCenters[i % 4] - _sectionLabelWidth / 2) * unit,
              width: _sectionLabelWidth * unit,
              top: (i ~/ 4) * _sectionRowPitch * unit,
              child: SectionKey(unit: unit, section: sections?[i], onOpen: onOpen),
            ),
        ],
      ),
    );
  }
}

/// زر حرفي أصفر: صورته، واسمه، ونوع شغله، وتقييمه. بلا حرفي يظهر الزر فارغاً إلى أن تصل البيانات.
class CraftsmanKey extends StatelessWidget {
  const CraftsmanKey({super.key, required this.unit, this.worker});

  final double unit;
  final Worker? worker;

  @override
  Widget build(BuildContext context) {
    final worker = this.worker;
    final chrome = unit * homeKeyChrome;
    final faceHeight = _craftsmanHeight * unit;
    return Semantics(
      button: true,
      enabled: worker != null,
      label: worker == null
          ? ''
          : '${worker.name}، ${worker.specialty}، التقييم ${worker.rating.toStringAsFixed(1)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: worker == null
            ? null
            : () => Navigator.push(
                  context,
                  QuickRoute(builder: (_) => CraftsmanInfoScreen(worker: worker)),
                ),
        child: SizedBox(
          width: _craftsmanWidth * unit + PushKey.faceInset * 2 * chrome,
          height: faceHeight + PushKey.depth * chrome,
          child: PushKey(
            unit: chrome,
            faceHeight: faceHeight,
            lemon: true,
            faceRadius: _craftsmanRadius,
            child: ExcludeSemantics(child: _face(worker)),
          ),
        ),
      ),
    );
  }

  Widget _face(Worker? worker) {
    final circle = _craftsmanCircle * unit;
    return Stack(
      children: [
        PositionedDirectional(
          start: _craftsmanCircleMargin * unit,
          top: (_craftsmanHeight - _craftsmanCircle) / 2 * unit,
          width: circle,
          height: circle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x59000000),
                  offset: Offset(0, 3 * unit),
                  blurRadius: 7 * unit,
                ),
              ],
            ),
            child: worker == null
                ? null
                : Center(
                    child: PersonFace(
                      name: worker.name,
                      imagePath: worker.avatarPath,
                      size: circle,
                      color: homeInk,
                    ),
                  ),
          ),
        ),
        if (worker != null) ...[
          PositionedDirectional(
            start: (_craftsmanCircleMargin + _craftsmanCircle + _craftsmanTextGap) * unit,
            end: _craftsmanTextMargin * unit,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: _craftsmanNameSize * unit,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: homeInk,
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.only(end: _ratingRoom * unit),
                  child: Text(
                    worker.specialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: _craftsmanWorkSize * unit,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: homeInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            end: _ratingMargin * unit,
            bottom: _ratingBottom * unit,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: _ratingStarSize * unit, color: homeInk),
                Text(
                  worker.rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: _ratingSize * unit,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: homeInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// الحرفيون في صفوف، كل صف زران. بلا قائمة تظهر [placeholders] أزرار فارغة.
class CraftsmanGrid extends StatelessWidget {
  const CraftsmanGrid({
    super.key,
    required this.unit,
    this.workers,
    this.placeholders = 6,
    this.lefts = _craftsmanLefts,
  });

  final double unit;
  final List<Worker>? workers;
  final int placeholders;

  /// مكان وجه الزر في كل عمود من يسار الإطار.
  final List<double> lefts;

  static double heightOf(int count, double unit) =>
      (count / 2).ceil() * _craftsmanRowPitch * unit;

  @override
  Widget build(BuildContext context) {
    final workers = this.workers;
    final count = workers?.length ?? placeholders;
    final chromeInset = PushKey.faceInset * unit * homeKeyChrome;
    return SizedBox(
      width: homeDesignWidth * unit,
      height: heightOf(count, unit),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: lefts[i % 2] * unit - chromeInset,
              top: (i ~/ 2) * _craftsmanRowPitch * unit,
              child: CraftsmanKey(unit: unit, worker: workers?[i]),
            ),
        ],
      ),
    );
  }
}
