import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../auth/auth_route.dart';
import '../auth/push_key.dart';
import '../widgets/quick_route.dart';
import '../widgets/realtime_refresh.dart';
import 'home_keys.dart';
import 'home_lists_screens.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';
import 'workers_scene.dart';

/// مقاسات التصميم المعتمد بالبكسل (إطار عرضه 391).
abstract final class _Design {
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
  const HomeTab(
      {super.key,
      required this.onOpenProfile,
      this.onOpenSection,
      this.onLoaded});

  final VoidCallback onOpenProfile;

  /// يفتح تبويب الفنيين على نوع الشغل المضغوط عليه.
  final ValueChanged<String>? onOpenSection;

  /// يأخذ الأقسام والحرفيين بعد كل جلب، فيفتح منهما تبويب الفنيين فوراً.
  final void Function(List<Category> sections, List<Worker> craftsmen)?
      onLoaded;

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
    final sections = customerSections(results[0] as List<Category>);
    final craftsmen = results[1] as List<Worker>;
    widget.onLoaded?.call(sections, craftsmen);
    return _HomeData(
      sections: sections,
      craftsmen: craftsmen,
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

  // عند الرجوع تعيد الصفحة تحميل بياناتها وحدها بعد انتهاء الانتقال.
  void _open(Widget page) {
    Navigator.push(context, QuickRoute(builder: (_) => page));
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
            final top = homePageTop(safeTop, unit);
            final hillBottom = homeHillBottom(top, unit);
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
        HomeHill(width: width, unit: unit, top: top),
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
              (_Design.messagesCenterX +
                      _Design.smallFace / 2 +
                      _Design.nameMargin) *
                  unit +
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
    final craftsmenRows =
        CraftsmanGrid.heightOf(craftsmen?.length ?? _homeCraftsmen, unit);
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
                padding:
                    EdgeInsets.symmetric(horizontal: _Design.allPadding * unit),
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
      height: top +
          (_Design.craftsmenTop + _Design.pageBottom) * unit +
          craftsmenRows,
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
            left: left +
                (homeSectionRightCenter - _Design.sectionsTitleWidth / 2) *
                    unit,
            width: _Design.sectionsTitleWidth * unit,
            top: top +
                (_Design.sectionsTitleCenter - _Design.titleHeight / 2) * unit,
            height: _Design.titleHeight * unit,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('الأقسام', maxLines: 1, style: titleStyle),
              ),
            ),
          ),
          showAll(
            _Design.sectionsAllCenter,
            AllSectionsScreen(
                sections: data?.sections, onOpenSection: widget.onOpenSection),
          ),
          Positioned(
            left: left,
            top: top + _Design.sectionsTop * unit,
            child: SectionGrid(
              unit: unit,
              sections: sections,
              placeholders: _homeSections,
              onOpen: (section) => widget.onOpenSection?.call(section.name),
            ),
          ),
          Positioned(
            right: right + _Design.craftsmenTitleRight * unit,
            left: left + _Design.titleRoom * unit,
            top: top +
                (_Design.craftsmenTitleCenter - _Design.titleHeight / 2) * unit,
            height: _Design.titleHeight * unit,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('حرفي بالقرب منك', maxLines: 1, style: titleStyle),
              ),
            ),
          ),
          showAll(_Design.craftsmenAllCenter,
              AllCraftsmenScreen(workers: data?.craftsmen)),
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
                : CraftsmanGrid(
                    unit: unit,
                    workers: craftsmen,
                    placeholders: _homeCraftsmen),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 158,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF0C0C0E), Color(0xFF3B3408)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -30,
              top: -50,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: .12),
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 18,
              child: SizedBox(
                width: 140,
                height: 140,
                child: Opacity(
                  opacity: .9,
                  child: Image.asset('assets/images/logo.jpg',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
            ),
            Positioned(
              top: 18,
              right: 18,
              left: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text('عرض هذا الأسبوع',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'خصم 15% على\nتصليح الغسالات',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('احجز الآن',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink)),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_left_rounded,
                                  size: 14, color: AppColors.ink),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('لفترة محدودة',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 8.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceMiniCard extends StatelessWidget {
  const _ServiceMiniCard({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(service.categoryColor ?? 0xFFFFD400);
    return SizedBox(
      width: 168,
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ServiceDetailScreen(service: service)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 62,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: .28),
                    color.withValues(alpha: .08)
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.handyman_rounded, color: color, size: 26),
            ),
            const SizedBox(height: 9),
            Text(service.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontSize: 12.5, height: 1.4)),
            const Spacer(),
            Row(
              children: [
                Text(fmtMoney(service.price),
                    style:
                        theme.textTheme.titleSmall?.copyWith(fontSize: 11.5)),
                const Spacer(),
                const Icon(Icons.star_rounded,
                    size: 12, color: Color(0xFFF5A623)),
                Text(service.rating.toStringAsFixed(1),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
