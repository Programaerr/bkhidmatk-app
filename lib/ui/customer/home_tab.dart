import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../auth/auth_route.dart';
import '../auth/push_key.dart';
import '../auth/truck_scene.dart';
import '../widgets/quick_route.dart';
import '../widgets/realtime_refresh.dart';
import 'home_keys.dart';
import 'home_lists_screens.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';
import 'workers_scene.dart';

/// مقاسات التصميم المعتمد بالبكسل (إطار عرضه 391).
abstract final class _Design {
  // الجهة الصفراء: مستطيل ينتهي بقطع ناقص مركزه أقرب إلى اليسار، فحافتها اليسرى أوطأ من اليمنى.
  static const hillCenterX = 189.0;
  static const hillCenterY = 79.2;
  static const hillRadiusX = 203.0;
  static const hillRadiusY = 35.0;

  static const profileFace = 42.9;
  static const profileRight = 22.7;
  static const profileCenter = 52.3;
  static const nameGap = 10.0;
  static const nameSize = 13.0;
  static const nameMargin = 8.0;

  static const smallFace = 32.7;
  static const smallCenter = 52.9;
  static const messagesCenterX = 91.1;
  static const notificationsCenterX = 38.1;
  static const smallIconSize = 18.0;
  static const smallTouchMargin = 3.0;
  static const badgeSize = 9.0;

  // لا يختفي الزر تحت شريط الحالة في الهواتف التي شريطها أطول من حافة التصميم.
  static const statusBarGap = 10.0;

  static const sceneTop = 128.2;

  static const titleSize = 18.0;
  static const allSize = 13.4;
  static const titleHeight = 32.0;
  static const allHeight = 44.0;
  static const allPadding = 8.0;
  static const allArrowSize = 15.0;
  static const allArrowGap = 3.0;
  static const allWidth = 110.0;
  static const titleRoom = 125.0;
  static const sectionsTitleWidth = 150.0;

  static const sectionsTitleCenter = 350.4;
  static const sectionsAllCenter = 352.4;
  static const sectionsTop = 383.6;

  static const craftsmenTitleCenter = 592.5;
  static const craftsmenTitleRight = 15.2;
  static const craftsmenAllCenter = 592.5;
  static const craftsmenTop = 636.1;
  static const pageBottom = 19.6;
}

const _homeSections = 8;
const _homeCraftsmen = 6;

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onOpenProfile});

  final VoidCallback onOpenProfile;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with RealtimeRefresh<HomeTab> {
  Future<_HomeData>? _future;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final state = context.read<AppState>();
    final user = state.user!;
    setState(() {
      _future = _fetch(state, state.repo, user.id!);
    });
  }

  Future<_HomeData> _fetch(AppState state, Repository repo, int userId) async {
    final results = await Future.wait([
      repo.listCategories(),
      repo.listWorkers(onlyAvailable: true),
      repo.unreadForCustomer(userId),
      _unreadNotifications(state),
    ]);
    return _HomeData(
      sections: results[0] as List<Category>,
      craftsmen: results[1] as List<Worker>,
      unreadMessages: results[2] as int,
      unreadNotifications: results[3] as int,
    );
  }

  /// فشل جلب العدد لا يوقف الصفحة، فالإشعارات نفسها تُجلب عند فتحها.
  Future<int> _unreadNotifications(AppState state) async {
    final services = state.cloudServices;
    if (services == null) return 0;
    try {
      final notifications = await services.notifications();
      return notifications.where((n) => !n.isRead).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, QuickRoute(builder: (_) => page));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AppState>().user!;
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // شريط الحالة فوق الجهة الصفراء دائماً، نهاراً وليلاً.
      value: appSystemBars(night: false),
      child: ColoredBox(
        color: night ? homeNightGround : homeCream,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final unit = homeUnit(width);
            final left = (width - homeDesignWidth * unit) / 2;
            final top = math.max(
              0.0,
              safeTop +
                  _Design.statusBarGap -
                  (_Design.profileCenter - _Design.profileFace / 2) * unit,
            );
            final hillBottom = top + (_Design.hillCenterY + _Design.hillRadiusY) * unit;
            return FutureBuilder<_HomeData>(
              future: _future,
              builder: (context, snapshot) {
                final data = snapshot.data;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: RefreshIndicator(
                        edgeOffset: hillBottom,
                        onRefresh: () async => _load(),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          children: [
                            _page(data, width, unit, left, top, night),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: hillBottom,
                      child: _header(user, data, width, unit, left, top, night),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _header(
    AppUser user,
    _HomeData? data,
    double width,
    double unit,
    double left,
    double top,
    bool night,
  ) {
    final ink = night ? homeNightInk : homeInk;
    final chrome = unit * homeKeyChrome;
    final inset = PushKey.faceInset * chrome;
    final profileFace = _Design.profileFace * unit;
    final smallFace = _Design.smallFace * unit;
    final profileRight = left + _Design.profileRight * unit;
    final touchMargin = _Design.smallTouchMargin * unit;

    Widget small({
      required double centerX,
      required String label,
      required IconData icon,
      required int badge,
      required Widget page,
    }) {
      return Positioned(
        left: left + centerX * unit - smallFace / 2 - inset - touchMargin,
        top: top + _Design.smallCenter * unit - smallFace / 2 - touchMargin,
        child: PushKeyCircle(
          diameter: smallFace,
          unit: chrome,
          touchMargin: touchMargin,
          label: label,
          onPressed: () => _open(page),
          child: SizedBox.expand(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: _Design.smallIconSize * unit, color: ink),
                if (badge > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _CountBadge(count: badge, unit: unit),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _HillPainter(
            bottom: top + _Design.hillCenterY * unit,
            centerX: _Design.hillCenterX * width / homeDesignWidth,
            radiusX: _Design.hillRadiusX * width / homeDesignWidth,
            radiusY: _Design.hillRadiusY * unit,
          ),
        ),
        Positioned(
          right: profileRight - inset,
          top: top + _Design.profileCenter * unit - profileFace / 2,
          child: PushKeyCircle(
            diameter: profileFace,
            unit: chrome,
            label: 'الملف الشخصي',
            onPressed: widget.onOpenProfile,
            child: PersonFace(
              name: user.name,
              imagePath: user.avatarPath,
              size: profileFace,
              color: ink,
            ),
          ),
        ),
        // الاسم في وسط الدائرة كلها، بوجهها وحلقتها، وبعيد عن حلقتها.
        Positioned(
          right: profileRight + profileFace + inset + _Design.nameGap * unit,
          left: left +
              (_Design.messagesCenterX + _Design.smallFace / 2 + _Design.nameMargin) * unit +
              inset,
          top: top + _Design.profileCenter * unit - profileFace / 2,
          height: profileFace + PushKey.depth * chrome,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: _Design.nameSize * unit,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: homeInk,
              ),
            ),
          ),
        ),
        small(
          centerX: _Design.messagesCenterX,
          label: 'الرسائل',
          icon: Icons.chat_bubble_outline_rounded,
          badge: data?.unreadMessages ?? 0,
          page: const MessagesScreen(),
        ),
        small(
          centerX: _Design.notificationsCenterX,
          label: 'الإشعارات',
          icon: Icons.notifications_none_rounded,
          badge: data?.unreadNotifications ?? 0,
          page: const NotificationsScreen(),
        ),
      ],
    );
  }

  Widget _page(
    _HomeData? data,
    double width,
    double unit,
    double left,
    double top,
    bool night,
  ) {
    final ink = night ? homeNightInk : homeLabel;
    final sections = data?.sections.take(_homeSections).toList();
    final craftsmen = data?.craftsmen.take(_homeCraftsmen).toList();
    final craftsmenRows = CraftsmanGrid.heightOf(craftsmen?.length ?? _homeCraftsmen, unit);
    final right = width - left - homeDesignWidth * unit;
    final titleStyle = TextStyle(
      fontFamily: 'Cairo',
      fontSize: _Design.titleSize * unit,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: ink,
    );

    // «عرض الكل» وسهمه في وسط الدائرة اليسرى.
    Widget showAll(double center, Widget page) => Positioned(
          left: left + (homeSectionLeftCenter - _Design.allWidth / 2) * unit,
          width: _Design.allWidth * unit,
          top: top + (center - _Design.allHeight / 2) * unit,
          height: _Design.allHeight * unit,
          child: Center(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: ink,
                padding: EdgeInsets.symmetric(horizontal: _Design.allPadding * unit),
                minimumSize: Size(0, _Design.allHeight * unit),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _open(page),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'عرض الكل',
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: _Design.allSize * unit,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    SizedBox(width: _Design.allArrowGap * unit),
                    // يتجه إلى اليسار دائماً، فلا ينعكس مع اتجاه الكتابة.
                    Icon(
                      Icons.arrow_back,
                      size: _Design.allArrowSize * unit,
                      color: ink,
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return SizedBox(
      height: top + (_Design.craftsmenTop + _Design.pageBottom) * unit + craftsmenRows,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: top + _Design.sceneTop * unit,
            height: workersSceneHeight * unit,
            child: WorkersScene(scale: unit, left: left),
          ),
          // «الأقسام» في وسط الدائرة اليمنى.
          Positioned(
            left: left + (homeSectionRightCenter - _Design.sectionsTitleWidth / 2) * unit,
            width: _Design.sectionsTitleWidth * unit,
            top: top + (_Design.sectionsTitleCenter - _Design.titleHeight / 2) * unit,
            height: _Design.titleHeight * unit,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('الأقسام', maxLines: 1, style: titleStyle),
              ),
            ),
          ),
          showAll(_Design.sectionsAllCenter, const AllSectionsScreen()),
          Positioned(
            left: left,
            top: top + _Design.sectionsTop * unit,
            child: SectionGrid(unit: unit, sections: sections, placeholders: _homeSections),
          ),
          Positioned(
            right: right + _Design.craftsmenTitleRight * unit,
            left: left + _Design.titleRoom * unit,
            top: top + (_Design.craftsmenTitleCenter - _Design.titleHeight / 2) * unit,
            height: _Design.titleHeight * unit,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('حرفي بالقرب منك', maxLines: 1, style: titleStyle),
              ),
            ),
          ),
          showAll(_Design.craftsmenAllCenter, const AllCraftsmenScreen()),
          Positioned(
            left: left,
            top: top + _Design.craftsmenTop * unit,
            child: craftsmen != null && craftsmen.isEmpty
                ? SizedBox(
                    width: homeDesignWidth * unit,
                    child: Text(
                      'لا يوجد حرفيون متاحون الآن',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: _Design.allSize * unit,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  )
                : CraftsmanGrid(unit: unit, workers: craftsmen, placeholders: _homeCraftsmen),
          ),
        ],
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.sections,
    required this.craftsmen,
    required this.unreadMessages,
    required this.unreadNotifications,
  });

  final List<Category> sections;
  final List<Worker> craftsmen;
  final int unreadMessages;
  final int unreadNotifications;
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.unit});

  final int count;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: 14 * unit),
      padding: EdgeInsets.symmetric(horizontal: 3 * unit),
      decoration: BoxDecoration(
        color: const Color(0xFFD92D20),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: _Design.badgeSize * unit,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// الجهة الصفراء العليا بحافتها المنحنية من الأسفل.
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
