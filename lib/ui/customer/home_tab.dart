import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../auth/auth_route.dart';
import '../auth/push_key.dart';
import '../widgets/quick_route.dart';
import '../widgets/realtime_refresh.dart';
import 'guest_gate.dart';
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

  /// يفتح تبويب الحرفيين على نوع الشغل المضغوط عليه، أو على كلهم إن لم يُعطَ نوع.
  final ValueChanged<String?>? onOpenSection;

  /// يأخذ الأقسام والحرفيين بعد كل جلب، فيفتح منهما تبويب الفنيين فوراً.
  final void Function(List<Category> sections, List<Worker> craftsmen)?
      onLoaded;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with RealtimeRefresh<HomeTab> {
  Future<_HomeData>? _future;
  final _fold = HeaderFold();
  String? _loadedCity;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fold.dispose();
    super.dispose();
  }

  void _load() {
    final state = context.read<AppState>();
    final user = state.user;
    _loadedCity = user?.city?.trim();
    setState(() {
      _future = _fetch(state, state.repo, user?.id);
    });
  }

  Future<_HomeData> _fetch(AppState state, Repository repo, int? userId) async {
    // الضيف بلا حساب، فلا رسائل له ولا إشعارات. والسيرفر قد يمنعه من قراءة الأقسام والحرفيين،
    // فتظهر الأقسام من قائمة التطبيق نفسها بأيقوناتها، ولا يبقى الحرفيون أزراراً فارغة.
    final guest = userId == null;
    final results = await Future.wait([
      guest
          ? repo.listCategories().catchError((Object _) => <Category>[])
          : repo.listCategories(),
      guest
          ? repo
              .listWorkers(onlyAvailable: true)
              .catchError((Object _) => <Worker>[])
          : repo.listWorkers(onlyAvailable: true),
      userId == null ? Future.value(0) : repo.unreadForCustomer(userId),
      userId == null ? Future.value(0) : _unreadNotifications(state),
    ]);
    final sections = customerSections(results[0] as List<Category>);
    final allCraftsmen = results[1] as List<Worker>;
    // «بالقرب منك» لأهل محافظة الزبون فقط. بقية التطبيق (تبويب الحرفيين)
    // يأخذ القائمة كاملة، فيبقى شاملاً لكل المحافظات.
    final city = state.user?.city?.trim();
    final nearby = city == null || city.isEmpty
        ? allCraftsmen
        : allCraftsmen.where((worker) => worker.city == city).toList();
    widget.onLoaded?.call(sections, allCraftsmen);
    return _HomeData(
      sections: sections,
      craftsmen: nearby,
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
    final user = context.watch<AppState>().user;
    final city = user?.city?.trim();
    if (city != _loadedCity) {
      // تغيير المحافظة من «حسابي» يحدّث «بالقرب منك» فور الرجوع للرئيسية.
      _loadedCity = city;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // شريط الحالة فوق الجهة الزرقاء دائماً، نهاراً وليلاً، فأيقوناته بيضاء.
      value: appSystemBars(night: true),
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
                        child: _fold.track(
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            // يبقى آخر صف فوق شريط التنقل الزجاجي.
                            padding: EdgeInsets.only(
                                bottom: MediaQuery.paddingOf(context).bottom),
                            children: [
                              _page(data, width, unit, left, top, night),
                            ],
                          ),
                        ),
                      ),
                    ),
                    FoldingHeader(
                      fold: _fold,
                      unit: unit,
                      safeTop: safeTop,
                      top: top,
                      builder: (context, metrics) =>
                          _header(user, data, width, left, metrics, night),
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

  /// الجهة الزرقاء: صورة الحساب واسمه، وزرا الرسائل والإشعارات. تنطوي إلى شريط مع نزول الصفحة،
  /// فيصغر ما فيها بالتحويل لا بتغيير مقاسه، حتى لا تُرسم الأزرار من جديد مع كل إطار.
  Widget _header(
    AppUser? user,
    _HomeData? data,
    double width,
    double left,
    HomeHeaderMetrics metrics,
    bool night,
  ) {
    final unit = metrics.unit;
    final scale = metrics.scale;
    final ink = night ? homeNightInk : homeInk;
    final chrome = unit * homeKeyChrome;
    final inset = PushKey.faceInset * chrome;
    final profileFace = _Design.profileFace * unit;
    final smallFace = _Design.smallFace * unit;
    final profileRight = left + _Design.profileRight * unit;
    final touchMargin = _Design.smallTouchMargin * unit;
    final depth = PushKey.depth * chrome;

    // يصغر حول وجه الزر نفسه لا حول مربعه الذي فيه جانبه وقاعدته.
    Widget shrunk(double face, Widget child) => Transform.scale(
          scale: scale,
          alignment: Alignment(0, -depth / (face + depth)),
          child: child,
        );

    Widget small({
      required double centerX,
      required String label,
      required IconData icon,
      required int badge,
      required Widget page,
    }) {
      return Positioned(
        left: left + centerX * unit - smallFace / 2 - inset - touchMargin,
        top: metrics.centerY(_Design.smallCenter) - smallFace / 2 - touchMargin,
        child: shrunk(
          smallFace,
          PushKeyCircle(
            diameter: smallFace,
            unit: chrome,
            touchMargin: touchMargin,
            onColour: true,
            label: label,
            onPressed: () {
              if (hasAccount(context)) _open(page);
            },
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
        ),
      );
    }

    final profileTop = metrics.centerY(_Design.profileCenter) - profileFace / 2;
    return Stack(
      fit: StackFit.expand,
      children: [
        HomeHill(width: width, metrics: metrics),
        Positioned(
          right: profileRight - inset,
          top: profileTop,
          child: shrunk(
            profileFace,
            PushKeyCircle(
              diameter: profileFace,
              unit: chrome,
              onColour: true,
              label: tr('الملف الشخصي', 'Profile'),
              onPressed: widget.onOpenProfile,
              child: PersonFace(
                name: user?.name ?? '',
                imagePath: user?.avatarPath,
                size: profileFace,
                color: ink,
              ),
            ),
          ),
        ),
        // الاسم في وسط الدائرة كلها، بوجهها وحلقتها، وبعيد عن حلقتها.
        Positioned(
          right: profileRight +
              profileFace * scale +
              inset +
              _Design.nameGap * unit,
          left: left +
              (_Design.messagesCenterX +
                      _Design.smallFace / 2 +
                      _Design.nameMargin) *
                  unit +
              inset,
          top: profileTop,
          height: profileFace + depth,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              user?.name ?? tr('ضيف', 'Guest'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: _Design.nameSize * unit * scale,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: AppColors.onGold,
              ),
            ),
          ),
        ),
        small(
          centerX: _Design.messagesCenterX,
          label: tr('الرسائل', 'Messages'),
          icon: Icons.chat_bubble_outline_rounded,
          badge: data?.unreadMessages ?? 0,
          page: const MessagesScreen(),
        ),
        small(
          centerX: _Design.notificationsCenterX,
          label: tr('الإشعارات', 'Notifications'),
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
    // الضيف قد لا يصله حرفيون من السيرفر، فلا تظهر له بطاقات فارغة ثم تختفي (طلب المستخدم).
    final placeholders =
        context.watch<AppState>().user == null ? 0 : _homeCraftsmen;
    final craftsmenRows =
        CraftsmanGrid.heightOf(craftsmen?.length ?? placeholders, unit);
    final right = width - left - homeDesignWidth * unit;
    final titleStyle = TextStyle(
      fontFamily: 'Cairo',
      fontSize: _Design.titleSize * unit,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: ink,
    );

    // «عرض الكل» وسهمه في وسط الدائرة اليسرى.
    Widget showAll(double center, VoidCallback onPressed) => Positioned(
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
              onPressed: onPressed,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('عرض الكل', 'See all'),
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
                child: Text(tr('الأقسام', 'Categories'),
                    maxLines: 1, style: titleStyle),
              ),
            ),
          ),
          showAll(
            _Design.sectionsAllCenter,
            () => _open(AllSectionsScreen(
              sections: data?.sections,
              onOpenSection: widget.onOpenSection,
            )),
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
                child: Text(tr('حرفي بالقرب منك', 'Craftsmen near you'),
                    maxLines: 1, style: titleStyle),
              ),
            ),
          ),
          // كل الحرفيين هم تبويب الحرفيين نفسه، فلا صفحة ثانية تكرره.
          showAll(_Design.craftsmenAllCenter,
              () => widget.onOpenSection?.call(null)),
          Positioned(
            left: left,
            top: top + _Design.craftsmenTop * unit,
            child: craftsmen != null && craftsmen.isEmpty
                ? SizedBox(
                    width: homeDesignWidth * unit,
                    child: Text(
                      tr('لا يوجد حرفيون متاحون الآن',
                          'No craftsmen available right now'),
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
                    unit: unit, workers: craftsmen, placeholders: placeholders),
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
