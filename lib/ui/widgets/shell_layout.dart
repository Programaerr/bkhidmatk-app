import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FragmentProgram, ImageFilter, lerpDouble;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:uikit_tab_bar/uikit_tab_bar.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../auth/push_key.dart';

/// A single bottom-navigation destination definition used by all shells.
class NavItem {
  const NavItem(
    this.label,
    this.icon,
    this.activeIcon, {
    required this.symbol,
    this.minimizeOnScroll = true,
  });
  final String label;

  /// أيقونة التبويب غير المختار: خطوط Cupertino بأشكال رموز آبل.
  final IconData icon;

  /// أيقونته مختاراً، ممتلئة. شريط iOS الأقدم يعرضها للتبويبات كلها كما تفعل آبل.
  final IconData activeIcon;

  /// اسم الرمز في SF Symbols لشريط آبل الأصلي (iOS 26 وما بعده)، بالشكل الممتلئ الذي توصي به آبل
  /// لأشرطة التبويب.
  final String symbol;

  /// شريط آبل ينكمش مع النزول في هذه الصفحة. لا في صفحة الفيديو.
  final bool minimizeOnScroll;
}

/// الآيفون يأخذ شريط آبل (انظر [_AppleTabLayout])، وأندرويد يبقى على الشريط الزجاجي.
bool get _appleBar => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

class AppShellLayout extends StatefulWidget {
  const AppShellLayout({
    super.key,
    required this.index,
    required this.items,
    required this.pages,
    required this.onSelect,
    this.floatingActionButton,
    this.accent = AppColors.gold,
    this.extendBody = true,
  });

  final int index;
  final List<NavItem> items;
  final List<Widget> pages;
  final ValueChanged<int> onSelect;
  final Widget? floatingActionButton;
  final Color accent;

  /// الصفحات تمتد خلف الشريط الزجاجي وتحسب هي هامشها السفلي (صفحات الزبون المرسومة بالتصميم).
  /// الصفحات القوائم العادية، مثل لوحة التحكم، تُقصر فوق الشريط فلا يخفي آخرها.
  final bool extendBody;

  @override
  State<AppShellLayout> createState() => _AppShellLayoutState();
}

class _AppShellLayoutState extends State<AppShellLayout> {
  /// أكثر التبويبات ظهوراً حديثاً يبقى مبنياً، وما سواها يُترك فتتحرر ذاكرته.
  /// التبويب الأحدث في آخر القائمة. تبويبات الزبون الخمسة تبقى كلها: إعادة بناء تبويب
  /// تُرك كانت تعيد رسومه وتحميله فيتقطع الرجوع إليه، والفيديو يتحرر وحده حين يُخفى تبويبه.
  static const _maxAlive = 5;
  final _alive = <int>[];

  // التبويب الجديد يظهر فوراً بلا تلاشٍ ولا انزلاق، مثل إنستغرام (طلب المستخدم)، وما خلفه
  // يبقى محفوظاً.

  @override
  Widget build(BuildContext context) {
    final AppShellLayout(
      :index,
      :items,
      :pages,
      :onSelect,
      :floatingActionButton,
      :accent,
      :extendBody,
    ) = widget;
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    _alive
      ..remove(index)
      ..add(index);
    while (_alive.length > _maxAlive) {
      _alive.removeAt(0);
    }

    final body = IndexedStack(
      index: index,
      children: [
        for (final (i, page) in pages.indexed)
          // ما خلف التبويب الظاهر لا يتحرك ولا يجلب شيئاً.
          TickerMode(
            enabled: i == index,
            child: _alive.contains(i) ? page : const SizedBox.shrink(),
          ),
      ],
    );

    if (!wide) {
      if (_appleBar) {
        return _AppleTabLayout(
          index: index,
          items: items,
          body: body,
          onSelect: onSelect,
          accent: accent,
          extendBody: extendBody,
          floatingActionButton: floatingActionButton,
        );
      }
      return Scaffold(
        extendBody: extendBody,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: _GlassNavigationBar(
          index: index,
          items: items,
          accent: accent,
          onSelect: onSelect,
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 92,
            decoration: BoxDecoration(
              border:
                  Border(left: BorderSide(color: theme.colorScheme.outline)),
            ),
            child: SafeArea(
              child: NavigationRail(
                selectedIndex: index,
                onDestinationSelected: onSelect,
                labelType: NavigationRailLabelType.all,
                minWidth: 90,
                leading: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/images/logo.jpg',
                        width: 44, height: 44, cacheWidth: 88, cacheHeight: 88),
                  ),
                ),
                destinations: [
                  for (final item in items)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.activeIcon),
                      label: Text(item.label),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// شريط التنقل السفلي: لمسة واحدة تفتح التبويب، وتنتقل الفقاعة إليه ببوابة زمنية. والبقاء
/// على الفقاعة أو سحبها يكبّرها فتتبع الإصبع يميناً ويساراً وتكبّر ما تحتها، ويُفتح التبويب الذي
/// يُترك عليه.
/// ارتفاع أعلى زجاج شريط التنقل عن أسفل الشاشة، لما يُرسم فوقه مباشرة (مثل شريط تقدم الفيديو).
/// تحت الزجاج شريط النظام إن وُجد، ثم 4 بين الزجاج ومكانه. على الآيفون يقيسه شريط آبل نفسه.
double glassBarTop(BuildContext context) {
  final apple = context.dependOnInheritedWidgetOfExactType<_AppleBarTop>();
  if (apple != null) {
    return apple.top > 0 ? apple.top : MediaQuery.paddingOf(context).bottom;
  }
  return MediaQuery.viewPaddingOf(context).bottom +
      _GlassNavigationBarState._height +
      4;
}

/// شريط آبل على الآيفون (طلب المستخدم). على iOS 26 وما بعده هو شريط النظام نفسه:
/// UITabBarController بزجاج Liquid Glass من آبل، لا تقليد له. يطفو فوق الصفحات، ويتبع الوضع
/// الفاتح والداكن وإعدادات الوصول، وحركته ولمسه من النظام، وينكمش مع النزول في الصفحة كما في
/// تطبيقات آبل. وعلى iOS الأقدم شريط Cupertino المعتاد. الصفحات تمتد خلفه وتعرف ارتفاعه من
/// هامشها السفلي، كما مع الشريط الزجاجي.
class _AppleTabLayout extends StatefulWidget {
  const _AppleTabLayout({
    required this.index,
    required this.items,
    required this.body,
    required this.onSelect,
    required this.accent,
    required this.extendBody,
    this.floatingActionButton,
  });

  final int index;
  final List<NavItem> items;
  final Widget body;
  final ValueChanged<int> onSelect;
  final Color accent;
  final bool extendBody;
  final Widget? floatingActionButton;

  @override
  State<_AppleTabLayout> createState() => _AppleTabLayoutState();
}

class _AppleTabLayoutState extends State<_AppleTabLayout> {
  final _bar = UIKitTabBarController();

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  /// أعلى زجاج الشريط عن أسفل الشاشة، وصفر قبل أن يرسمه النظام أول مرة.
  static double _glassTop(UIKitTabBarGeometry geometry) {
    final bar = geometry.barRect;
    final glass = geometry.hitRects;
    if (bar == null || glass.isEmpty) return geometry.bottomInset;
    return bar.bottom - glass.map((rect) => rect.top).reduce(math.min);
  }

  @override
  Widget build(BuildContext context) {
    final _AppleTabLayout(:index, :items, :onSelect, :accent, :extendBody) =
        widget;
    // ينكمش مع النزول في الصفحة، إلا فوق الفيديو، وفي الصفحات التي لا تمتد خلفه، وما دامت فوقه
    // صفحة أو نافذة: السحب فيها لا يخصه.
    final shrinks = extendBody &&
        items[index].minimizeOnScroll &&
        (ModalRoute.isCurrentOf(context) ?? true);
    return UIKitTabScaffold(
      controller: _bar,
      tabBar: UIKitTabBar(
        tabs: [
          for (final (i, item) in items.indexed)
            UIKitTab(
              id: '$i',
              label: item.label,
              icon: UIKitTabIcon.symbol(item.symbol),
              // في شريط iOS الأقدم الأيقونات كلها ممتلئة، والمختارة بلون التطبيق، كما عند آبل.
              fallbackIcon: Icon(item.activeIcon),
            ),
        ],
        selectedId: '$index',
        // إن مُنع التبويب (الضيف) بقي المختار كما هو، فيرجع الشريط إليه.
        onSelected: (id) => onSelect(int.parse(id)),
        minimizeBehavior: shrinks
            ? UIKitTabBarMinimizeBehavior.onScrollDown
            : UIKitTabBarMinimizeBehavior.never,
        style: UIKitTabBarStyle(
          tintColor: accent,
          // يتبع وضع التطبيق الليلي، وهو يتبع وضع الآيفون ما لم يُختر غيره.
          brightness: Theme.of(context).brightness,
        ),
      ),
      body: ValueListenableBuilder<UIKitTabBarGeometry>(
        valueListenable: _bar.geometry,
        builder: (context, geometry, page) =>
            _AppleBarTop(top: _glassTop(geometry), child: page!),
        child: Scaffold(
          body: extendBody ? widget.body : _AboveAppleBar(child: widget.body),
          floatingActionButton: widget.floatingActionButton,
        ),
      ),
    );
  }
}

/// أعلى زجاج شريط آبل، لما يُرسم فوقه مباشرة. انظر [glassBarTop].
class _AppleBarTop extends InheritedWidget {
  const _AppleBarTop({required this.top, required super.child});

  final double top;

  @override
  bool updateShouldNotify(_AppleBarTop oldWidget) => oldWidget.top != top;
}

/// صفحة تقف فوق شريط آبل ولا تمتد خلفه، مثل قوائم لوحة التحكم.
class _AboveAppleBar extends StatelessWidget {
  const _AboveAppleBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: child,
        ),
      );
}

class _GlassNavigationBar extends StatefulWidget {
  const _GlassNavigationBar({
    required this.index,
    required this.items,
    required this.accent,
    required this.onSelect,
  });

  final int index;
  final List<NavItem> items;
  final Color accent;
  final ValueChanged<int> onSelect;

  @override
  State<_GlassNavigationBar> createState() => _GlassNavigationBarState();
}

// زجاج الفقاعة المتحركة، يُحمَّل مرة واحدة. لا يعمل إلا مع Impeller، وغيره يكتفي بمجهر عادي.
final Future<FragmentProgram?> _liquidGlass = ImageFilter.isShaderFilterSupported
    ? FragmentProgram.fromAsset('shaders/liquid_glass.frag')
        .then<FragmentProgram?>((program) => program, onError: (_) => null)
    : Future.value();

class _GlassNavigationBarState extends State<_GlassNavigationBar>
    with TickerProviderStateMixin {
  // بارتفاع شريط انستغرام (طلب المستخدم): بـ 60 صار الشريط كبيراً.
  static const _height = 50.0;
  // البقاء على الفقاعة هذه المدة، أو تحريك الإصبع هذه المسافة، يحوّلها إلى مجهر.
  static const _holdDelay = Duration(milliseconds: 180);
  static const _moveToLens = 8.0;

  final _barKey = GlobalKey();
  final _boundsKey = GlobalKey();
  bool _isDragging = false;
  FragmentProgram? _glassProgram;

  // المجهر حين يبقى الإصبع على الفقاعة.
  late final _lens = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  // سرعة الإصبع تمطّ الزجاج وتقوّي انكساره، ويعود مستوياً حين يقف الإصبع.
  late final _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  final _finger = ValueNotifier<double>(0);
  // البوابة الزمنية بين التبويبات (طلب المستخدم، للشريط وحده): انظر [_BarPortalPainter].
  late final _portal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final _glass = Listenable.merge([_lens, _settle, _finger, _portal]);
  int _portalFrom = 0;
  int _portalTo = 0;
  // التبويب الذي فُتح بترك المجهر: المجهر نفسه نقل الفقاعة إليه، فلا بوابة.
  int? _released;

  bool _lensOn = false;
  double _speed = 0;
  Duration? _movedAt;
  Offset? _downAt;
  Timer? _hold;
  // إصبع واحد يحرّك الشريط، وما يلمسه إصبع ثانٍ في الوقت نفسه يُهمل.
  int? _pointer;

  @override
  void initState() {
    super.initState();
    _liquidGlass.then((program) {
      if (mounted && program != null) setState(() => _glassProgram = program);
    });
  }

  @override
  void didUpdateWidget(covariant _GlassNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    final released = _released == widget.index;
    _released = null;
    if (released || _lensOn || MediaQuery.disableAnimationsOf(context)) return;
    // ضغطة أثناء البوابة تغلق البوابة التي كانت تنفتح.
    _portalFrom = _portal.isAnimating ? _portalTo : oldWidget.index;
    _portalTo = widget.index;
    _portal.forward(from: 0);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _portal.dispose();
    _lens.dispose();
    _settle.dispose();
    _finger.dispose();
    super.dispose();
  }

  int? _indexAt(Offset globalPosition) {
    final renderObject = _boundsKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || renderObject.size.width <= 0) return null;
    final local = renderObject.globalToLocal(globalPosition);
    final itemWidth = renderObject.size.width / widget.items.length;
    final logicalX = Directionality.of(context) == TextDirection.rtl
        ? renderObject.size.width - local.dx
        : local.dx;
    return (logicalX / itemWidth).floor().clamp(0, widget.items.length - 1);
  }

  void _scrub(Offset globalPosition) {
    final next = _indexAt(globalPosition);
    if (next != null && next != widget.index) widget.onSelect(next);
  }

  void _setDragging(bool value) {
    if (mounted && _isDragging != value) setState(() => _isDragging = value);
  }

  double _barX(Offset globalPosition) {
    final box = _barKey.currentContext?.findRenderObject();
    return box is RenderBox ? box.globalToLocal(globalPosition).dx : 0;
  }

  /// منتصف التبويب على الشاشة، من اليمين في العربية.
  double _tabCenter(int index, double width) {
    final itemWidth = width / widget.items.length;
    final start = itemWidth * index + itemWidth / 2;
    return Directionality.of(context) == TextDirection.rtl ? width - start : start;
  }

  // التبويب يُفتح بمجرد اللمس، والبقاء عليه أو السحب يحوّل فقاعته إلى مجهر.
  void _touchDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _downAt = event.position;
    _movedAt = null;
    _setDragging(true);
    _scrub(event.position);
    _hold?.cancel();
    _hold = Timer(_holdDelay, () => _startLens(event.position));
  }

  void _touchMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if (!_lensOn) {
      final down = _downAt;
      if (down == null || (event.position - down).distance < _moveToLens) {
        return;
      }
      _startLens(event.position);
    }
    final x = _barX(event.position);
    final last = _movedAt;
    if (last != null && event.timeStamp > last) {
      final seconds = (event.timeStamp - last).inMicroseconds / 1e6;
      _speed = (x - _finger.value).abs() / seconds;
      _settle
        ..value = 1
        ..animateTo(0, curve: Curves.easeOut);
    }
    _movedAt = event.timeStamp;
    _finger.value = x;
  }

  void _startLens(Offset globalPosition) {
    _hold?.cancel();
    if (!mounted || _lensOn) return;
    _lensOn = true;
    // المجهر يأخذ مكان البوابة.
    _portal.stop();
    _finger.value = _barX(globalPosition);
    _lens.forward();
  }

  // ترك المجهر يفتح التبويب الذي تحته، ويصغر المجهر إلى فقاعته هناك.
  void _touchUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _hold?.cancel();
    _downAt = null;
    _setDragging(false);
    if (!_lensOn) return;
    _lensOn = false;
    _finger.value = _barX(event.position);
    final next = _indexAt(event.position);
    if (next != null && next != widget.index) {
      _released = next;
      widget.onSelect(next);
    }
    _lens.reverse();
  }

  void _touchCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _hold?.cancel();
    _downAt = null;
    _setDragging(false);
    if (!_lensOn) return;
    _lensOn = false;
    _lens.reverse();
  }

  /// الزجاج المتحرك الآن: مجهر تحت الإصبع، أو فقاعة في طريقها إلى تبويب، أو لا شيء.
  ({double centre, double width, double height, double zoom, double refract, double presence})?
      _drop(double width, double itemWidth) {
    final bubbleWidth = itemWidth - 8;
    const bubbleHeight = _height - 8;
    final stretch = (_speed / 2500).clamp(0.0, .3) * _settle.value;
    if (_lens.value > 0) {
      final t = Curves.easeOutCubic.transform(_lens.value);
      final half = itemWidth / 2;
      final finger = _finger.value.clamp(half, width - half);
      return (
        // يكبر من مكان الفقاعة إلى الإصبع، وبعد تركه يصغر إلى فقاعة التبويب المختار.
        centre: lerpDouble(_tabCenter(widget.index, width), finger, t)!,
        width: lerpDouble(bubbleWidth, itemWidth + 18, t)! * (1 + stretch),
        height: lerpDouble(bubbleHeight, _height + 16, t)! * (1 - stretch * .4),
        zoom: lerpDouble(1, 1.3, t)!,
        refract: t * (.22 + stretch * 1.6),
        presence: t,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(_height / 2);
    final items = widget.items;

    // لا فراغ تحت الشريط: الـ 8 التي كانت تحته صارت فوقه، فينزل الزجاج ويبقى ارتفاع الشريط
    // كما هو فلا تتحرك الصفحات. فوق شريط النظام السفلي يبقى كما كان.
    final lift = math.max(0.0, 8 - MediaQuery.paddingOf(context).bottom);
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(16, 6 + lift, 16, 0),
      child: SizedBox(
        height: _height + 8,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SizedBox(
              height: _height,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final itemWidth = width / items.length;
                  return Stack(
                    key: _barKey,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: isDark ? .25 : .12),
                                blurRadius: 18,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: radius,
                            // زجاج: ما خلف الشريط يظهر مغبّشاً من تحت بياض خفيف.
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Listener(
                                key: const ValueKey('glass-navigation-bar'),
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: _touchDown,
                                onPointerMove: _touchMove,
                                onPointerUp: _touchUp,
                                onPointerCancel: _touchCancel,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      // ليلاً زجاج شفاف مثل النهار (طلب المستخدم): بياض خفيف فوق
                                      // التغبيش، لا لوح داكن يخفي ما تحته.
                                      colors: isDark
                                          ? [
                                              Colors.white
                                                  .withValues(alpha: .12),
                                              Colors.white
                                                  .withValues(alpha: .06),
                                            ]
                                          : [
                                              Colors.white
                                                  .withValues(alpha: .50),
                                              Colors.white
                                                  .withValues(alpha: .32),
                                            ],
                                    ),
                                    // بلا إطار أبيض حوله (طلب المستخدم).
                                    borderRadius: radius,
                                  ),
                                  child: Stack(
                                    key: _boundsKey,
                                    children: [
                                      // الفقاعة الساكنة، تختفي ما دام الزجاج يتحرك أو البوابة تعمل.
                                      PositionedDirectional(
                                        start: itemWidth * widget.index + 4,
                                        top: 4,
                                        bottom: 4,
                                        width: itemWidth - 8,
                                        child: AnimatedScale(
                                          scale: _isDragging ? 1.05 : 1,
                                          duration:
                                              const Duration(milliseconds: 180),
                                          curve: Curves.easeOutCubic,
                                          child: AnimatedBuilder(
                                            animation: _glass,
                                            builder: (context, bubble) => Opacity(
                                              opacity: _portal.isAnimating
                                                  ? 0
                                                  : 1 -
                                                      (_drop(width, itemWidth)
                                                              ?.presence ??
                                                          0),
                                              child: bubble,
                                            ),
                                            child: _bubble(isDark),
                                          ),
                                        ),
                                      ),
                                      // البوابة بين التبويبين، تحت الأيقونات، في طبقتها وحدها.
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: RepaintBoundary(
                                            child: CustomPaint(
                                              painter: _BarPortalPainter(
                                                portal: _portal,
                                                from: _tabCenter(
                                                    _portalFrom, width),
                                                to: _tabCenter(_portalTo, width),
                                                itemWidth: itemWidth,
                                                isDark: isDark,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          for (var i = 0; i < items.length; i++)
                                            Expanded(
                                              child: _GlassNavigationDestination(
                                                item: items[i],
                                                selected: i == widget.index,
                                                accent: widget.accent,
                                                onTap: () {
                                                  if (i != widget.index) {
                                                    widget.onSelect(i);
                                                  }
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _glass,
                        builder: (context, _) =>
                            _glassDrop(width, itemWidth, isDark),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // فقاعة التبويب المختار زجاج شفاف، حافتها بلونها نفسه، وأيقونتها وحدها بلون التطبيق.
  Widget _bubble(bool isDark) {
    final glass = Colors.white.withValues(alpha: isDark ? .16 : .34);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_height / 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glass,
            Colors.white.withValues(alpha: isDark ? .04 : .10),
          ],
        ),
        border: Border.all(color: glass),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .20 : .08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _glassDrop(double width, double itemWidth, bool isDark) {
    final drop = _drop(width, itemWidth);
    if (drop == null || drop.presence <= 0) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    // تحت الزجاج 4 ثم حافة الشاشة، فالعدسة الأطول من الشريط تكبر نحو الأعلى ولا تُقصّ.
    final room = _height + 4 + MediaQuery.paddingOf(context).bottom;
    final rect = Rect.fromCenter(
      center: Offset(
          drop.centre, math.min(_height / 2, room - drop.height / 2)),
      width: drop.width,
      height: drop.height,
    );
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Opacity(
          opacity: drop.presence,
          child: _refraction(rect, drop.zoom, drop.refract, isDark),
        ),
      ),
    );
  }

  // يكبّر ما تحت الزجاج ويكسره عند حافته. بلا Impeller يبقى التكبير وحده.
  Widget _refraction(Rect rect, double zoom, double refract, bool isDark) {
    final radius = BorderRadius.circular(rect.height / 2);
    // بلون الفقاعة الساكنة وحافتها: الإصبع يمسك الفقاعة نفسها فتكبر وتتبعه، ولا تختفي من تحته.
    final glass = Colors.white.withValues(alpha: isDark ? .16 : .34);
    final tint = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glass,
            Colors.white.withValues(alpha: isDark ? .04 : .10),
          ],
        ),
        border: Border.all(color: glass),
      ),
    );
    final program = _glassProgram;
    final bar = _barKey.currentContext?.findRenderObject();
    if (program != null && bar is RenderBox && bar.attached) {
      final ratio = MediaQuery.devicePixelRatioOf(context);
      final origin = bar.localToGlobal(rect.topLeft) * ratio;
      final shader = program.fragmentShader()
        ..setFloat(2, origin.dx)
        ..setFloat(3, origin.dy)
        ..setFloat(4, rect.width * ratio)
        ..setFloat(5, rect.height * ratio)
        ..setFloat(6, rect.height / 2 * ratio)
        ..setFloat(7, zoom)
        ..setFloat(8, refract)
        ..setFloat(9, ratio);
      return ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(filter: ImageFilter.shader(shader), child: tint),
      );
    }
    // بلا ظل: ظل المجهر يعتّم ما بداخله.
    return RawMagnifier(
      size: rect.size,
      magnificationScale: zoom,
      decoration: MagnifierDecoration(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      child: tint,
    );
  }
}

/// البوابة الزمنية في الشريط (طلب المستخدم، والصفحات تتبدل فوراً). على التبويب القديم تنطوي
/// الفقاعة في حلقة طاقة تدور حولها علامات كمينا الساعة، وتصغر حتى تختفي. وعلى الجديد تنفتح
/// بوابة: حلقة مضيئة تكبر بارتداد خفيف، تدور فيها الطاقة وحولها الدقائق بالعكس وشرارتان، ثم
/// تمتد فتصير الفقاعة الساكنة تماماً ويخبو ضوؤها. كل ما فيها صغير داخل الشريط، فهي خفيفة.
class _BarPortalPainter extends CustomPainter {
  _BarPortalPainter({
    required this.portal,
    required this.from,
    required this.to,
    required this.itemWidth,
    required this.isDark,
  }) : super(repaint: portal);

  final AnimationController portal;
  final double from;
  final double to;
  final double itemWidth;
  final bool isDark;

  static const _blue = AppColors.gold;
  static const _sky = Color(0xFF7CC4F2);

  /// قطر البوابة وهي دائرة، قبل أن تمتد إلى الفقاعة. تبقى هي وعلاماتها داخل الشريط.
  static const _ringSize = 30.0;

  static double _smooth(double x) {
    final v = x.clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!portal.isAnimating) return;
    final t = portal.value;
    final restWidth = itemWidth - 8;
    final restHeight = size.height - 8;
    final spin = t * math.pi * 2.4;
    final y = size.height / 2;

    // التبويب القديم: الفقاعة تستدير ثم تصغر في حلقتها حتى تختفي.
    final close = _smooth(t / .42);
    if (close < 1) {
      final shrink = Curves.easeInCubic.transform(close);
      final round = Curves.easeOutCubic.transform((close * 2).clamp(0.0, 1.0));
      final height = restHeight * (1 - shrink);
      final width = lerpDouble(restWidth, restHeight, round)! * (1 - shrink);
      final glow = math.sin(math.pi * close);
      _glassPill(canvas, Offset(from, y), width, height, 1 - close);
      _energy(canvas, Offset(from, y), width, height, spin, glow);
      _clock(canvas, Offset(from, y), height / 2, -spin, glow * .9);
    }

    // التبويب الجديد: بوابة تنفتح دائرةً ثم تمتد إلى الفقاعة.
    final open = ((t - .16) / .84).clamp(0.0, 1.0);
    if (open > 0) {
      final grow = Curves.easeOutBack.transform((open / .45).clamp(0.0, 1.0));
      final widen = Curves.easeInOutCubic.transform(((open - .4) / .6).clamp(0.0, 1.0));
      final height = lerpDouble(_ringSize * grow, restHeight, widen)!;
      final width = lerpDouble(height, restWidth, widen)!;
      final centre = Offset(to, y);
      final light = _smooth(open / .1) * (1 - _smooth((open - .68) / .32));
      final round = 1 - widen;
      // وهج داخلها وهي تنفتح.
      if (round > 0) {
        canvas.drawCircle(
          centre,
          height / 2,
          Paint()
            ..shader = RadialGradient(
              colors: [
                _sky.withValues(alpha: .05 * round),
                _sky.withValues(alpha: (isDark ? .45 : .35) * round * light),
              ],
            ).createShader(Rect.fromCircle(center: centre, radius: height / 2)),
        );
      }
      _glassPill(canvas, centre, width, height, _smooth((open - .25) / .45));
      _energy(canvas, centre, width, height, -spin, light);
      _clock(canvas, centre, height / 2, spin * .7, light * round);
      // شرارتان على حافتها تسبقانها في الدوران.
      if (round > 0) {
        final sparks = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: .9 * light * round);
        for (var i = 0; i < 2; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: centre, radius: height / 2 - 2),
            -spin * 1.8 + i * math.pi,
            .7,
            false,
            sparks,
          );
        }
      }
    }
  }

  /// زجاج الفقاعة الساكنة بظلها وحافتها، بشفافية [presence].
  void _glassPill(Canvas canvas, Offset centre, double width, double height,
      double presence) {
    if (presence <= 0 || height < 1) return;
    final rect = Rect.fromCenter(center: centre, width: width, height: height);
    final pill = RRect.fromRectAndRadius(rect, Radius.circular(height / 2));
    final glass = Colors.white.withValues(alpha: (isDark ? .16 : .34) * presence);
    canvas
      ..drawRRect(
        pill.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: (isDark ? .20 : .08) * presence)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawRRect(
        pill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              glass,
              Colors.white.withValues(alpha: (isDark ? .04 : .10) * presence),
            ],
          ).createShader(rect),
      )
      ..drawRRect(
        pill.deflate(.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = glass,
      );
  }

  /// حلقة الطاقة الدائرة حول الشكل، بلون التطبيق والسماوي والأبيض، وضوء خفيف حولها.
  void _energy(Canvas canvas, Offset centre, double width, double height,
      double spin, double strength) {
    if (strength <= 0 || height < 2) return;
    final rect = Rect.fromCenter(center: centre, width: width, height: height);
    final ring = RRect.fromRectAndRadius(rect, Radius.circular(height / 2));
    canvas
      ..drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = _sky.withValues(alpha: (isDark ? .5 : .4) * strength)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..shader = SweepGradient(
            colors: [
              _blue.withValues(alpha: strength),
              _sky.withValues(alpha: strength),
              Colors.white.withValues(alpha: strength),
              _sky.withValues(alpha: strength),
              _blue.withValues(alpha: strength),
            ],
            transform: GradientRotation(spin),
          ).createShader(rect),
      );
  }

  /// علامات الدقائق حول الدائرة، كل ثالثة أطول، تدور مع [spin].
  void _clock(Canvas canvas, Offset centre, double radius, double spin,
      double strength) {
    if (strength <= 0 || radius < 3) return;
    final ticks = Paint()..strokeCap = StrokeCap.round;
    final colour = isDark ? _sky : _blue;
    for (var i = 0; i < 24; i++) {
      final major = i % 3 == 0;
      final angle = i / 24 * 2 * math.pi + spin;
      final direction = Offset(math.cos(angle), math.sin(angle));
      ticks
        ..strokeWidth = major ? 1.6 : 1
        ..color = colour.withValues(alpha: (major ? .95 : .6) * strength);
      canvas.drawLine(
        centre + direction * (radius + 3),
        centre + direction * (radius + (major ? 8 : 6)),
        ticks,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPortalPainter oldDelegate) =>
      oldDelegate.portal != portal ||
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.itemWidth != itemWidth ||
      oldDelegate.isDark != isDark;
}

class _GlassNavigationDestination extends StatelessWidget {
  const _GlassNavigationDestination({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          // أيقونة وحدها بلا اسم تحتها (طلب المستخدم)، والاسم يبقى لقارئ الشاشة.
          child: SizedBox(
            height: double.infinity,
            child: Center(
              child: AnimatedScale(
                scale: selected ? 1.08 : 1,
                // الأيقونة المختارة تكبر فوراً مثل إنستغرام، بلا حركة بطيئة.
                duration: Duration.zero,
                curve: Curves.easeOutCubic,
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 23,
                  color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// زر دائري بأيقونة بشكل أزرار الصفحة الرئيسية، للأشرطة وللصفوف.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge = 0,
    this.tooltip,
    this.small = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final int badge;
  final String? tooltip;
  final bool small;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return PushKeyIconButton(
      icon: icon,
      onPressed: onTap,
      label: tooltip ?? '',
      badge: badge,
      small: small,
      color: color,
    );
  }
}

class PaymentMethodBadge extends StatelessWidget {
  const PaymentMethodBadge(
      {super.key, required this.method, this.last4, this.brand});

  final String method;
  final String? last4;
  final String? brand;

  @override
  Widget build(BuildContext context) {
    final isCard = method == 'card';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isCard ? Icons.credit_card_rounded : Icons.payments_outlined,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          isCard
              ? '${brand ?? 'Card'} •••• ${last4 ?? ''}'
              : tr('الدفع عند الوصول', 'Pay on arrival'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
