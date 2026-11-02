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
  const HomeHill({super.key, required this.width, required this.unit, required this.top});

  final double width;
  final double unit;
  final double top;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HillPainter(
        bottom: top + _hillCenterY * unit,
        centerX: _hillCenterX * width / homeDesignWidth,
        radiusX: _hillRadiusX * width / homeDesignWidth,
        radiusY: _hillRadiusY * unit,
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
