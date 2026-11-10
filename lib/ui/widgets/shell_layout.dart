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

/// شريط التنقل السفلي: لمسة واحدة تفتح التبويب، وتقفز الفقاعة إليه كقطرة ماء ثم تستقر. والبقاء
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
  // قفزة الفقاعة من تبويب إلى آخر كقطرة ماء (طلب المستخدم، بدل قفزة الهلام).
  late final _trip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  // سرعة الإصبع تمطّ الزجاج وتقوّي انكساره، ويعود مستوياً حين يقف الإصبع.
  late final _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  final _finger = ValueNotifier<double>(0);
  late final _glass = Listenable.merge([_lens, _trip, _settle, _finger]);

  bool _lensOn = false;
  double _speed = 0;
  Duration? _movedAt;
  Offset? _downAt;
  Timer? _hold;
  // إصبع واحد يحرّك الشريط، وما يلمسه إصبع ثانٍ في الوقت نفسه يُهمل.
  int? _pointer;
  // التبويب الذي فُتح بترك المجهر، فلا رحلة إليه.
  int? _released;
  // من أين يكبر المجهر: من الفقاعة الساكنة، أو من مكان الفقاعة القافزة إن أُمسكت وهي في الهواء.
  double _lensFrom = 0;
  // أُمسكت الفقاعة في قفزتها: لا تظهر الساكنة في آخر الطريق حتى يُترك المجهر.
  bool _caughtInHop = false;
  double _tripFrom = 0;
  int _tripTo = 0;
  double _width = 0;

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
    if (released || _lensOn || _width == 0) return;
    _tripFrom = _trip.isAnimating
        ? _tripCentre(_width)
        : _tabCenter(oldWidget.index, _width);
    _tripTo = widget.index;
    // الصفحة تتبدل فوراً، والفقاعة تقفز إليها كقطرة ماء (طلب المستخدم).
    _trip.forward(from: 0);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _lens.dispose();
    _trip.dispose();
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

  /// مكان الفقاعة القافزة الآن، ومنه تبدأ قفزة جديدة إن ضُغط تبويب آخر قبل أن تهبط.
  double _tripCentre(double width) => lerpDouble(
        _tripFrom,
        _tabCenter(_tripTo, width),
        _WaterHop.travel(_trip.value),
      )!;

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
    _caughtInHop = _trip.isAnimating;
    _lensFrom = _caughtInHop
        ? _tripCentre(_width)
        : _tabCenter(widget.index, _width);
    _trip.stop();
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
    _caughtInHop = false;
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
    _caughtInHop = false;
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
        centre: lerpDouble(
            _lensOn ? _lensFrom : _tabCenter(widget.index, width), finger, t)!,
        width: lerpDouble(bubbleWidth, itemWidth + 18, t)! * (1 + stretch),
        height: lerpDouble(bubbleHeight, _height + 16, t)! * (1 - stretch * .4),
        zoom: lerpDouble(1, 1.3, t)!,
        refract: t * (.22 + stretch * 1.6),
        presence: t,
      );
    }
    // في القفز بين التبويبات ترسم الفقاعةَ [_WaterPainter]، لا الزجاج.
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
                  _width = width;
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
                                      // الفقاعة الساكنة، تختفي ما دام الزجاج يتحرك.
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
                                              opacity: _trip.isAnimating ||
                                                      _caughtInHop
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
                                      // الفقاعة في قفزتها، بلون الفقاعة الساكنة وحافتها. تُرسم
                                      // في طبقتها وحدها مع كل إطار، بلا إعادة بناء.
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: RepaintBoundary(
                                            child: CustomPaint(
                                              painter: _WaterPainter(
                                                trip: _trip,
                                                from: _tripFrom,
                                                to: _tabCenter(_tripTo, width),
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

/// قفزة الفقاعة من تبويب إلى آخر كقطرة ماء (طلب المستخدم): تتجمع قليلاً، ثم تنفصل فتنساب في
/// قوس صغير داخل الشريط، مقدمتها مستديرة وذيلها يدق خلفها كقطرة تجري، وعلى سطحها لمعة. حين
/// تلمس مكانها تنبسط كالماء ثم تتموج موجات تخبو حتى تسكن على شكل الفقاعة الساكنة تماماً، وتنداح
/// حلقة خفيفة من حيث قامت وحيث نزلت. كل الحركات متصلة بلا قفزات، فتبقى ناعمة.
abstract final class _WaterHop {
  /// نهاية التجمع قبل الانطلاق، ولحظة الملامسة.
  static const takeoff = .10;
  static const land = .66;

  static double _flight(double t) =>
      ((t - takeoff) / (land - takeoff)).clamp(0.0, 1.0);

  /// انتقال متصل بلا حواف بين 0 و1.
  static double _smooth(double x) {
    final v = x.clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  /// كم قطعت من الطريق: صفر قبل الانطلاق، وواحد من لحظة الملامسة.
  static double travel(double t) => Curves.easeInOutSine.transform(_flight(t));

  /// ارتفاعها عن مكانها نسبةً إلى أعلى القوس.
  static double rise(double t) => math.sin(math.pi * _flight(t));

  /// عرضها وارتفاعها نسبةً إلى الفقاعة الساكنة، وكم يدق ذيلها (0 بلا ذيل).
  static (double, double, double) shape(double t) {
    if (t < takeoff) {
      final gather = _smooth(t / takeoff);
      return (1 + .07 * gather, 1 - .09 * gather, 0);
    }
    if (t < land) {
      final flight = _flight(t);
      // تمتد مع سرعتها، وتخف انضغاطة التجمع، وتنبسط قبيل الملامسة.
      final pull = math.sin(math.pi * flight);
      final gather = 1 - _smooth(flight / .3);
      final touch = _smooth((flight - .8) / .2);
      return (
        1 + .20 * pull + .07 * gather + .12 * touch,
        1 - .17 * pull - .09 * gather - .13 * touch,
        pull,
      );
    }
    // موجات تخبو، تبدأ من انبساطة الملامسة وتنتهي ساكنة بلا ارتداد.
    final settle = (t - land) / (1 - land);
    final ripple = math.cos(math.pi * 2.2 * settle) *
        math.pow(1 - settle, 2.2).toDouble();
    return (1 + .12 * ripple, 1 - .13 * ripple, 0);
  }

  /// حلقة الماء من حيث قامت (0 إلى 1)، ثم حيث نزلت.
  static double takeoffRing(double t) => ((t - takeoff) / .42).clamp(0.0, 1.0);
  static double landingRing(double t) =>
      ((t - land) / (1 - land)).clamp(0.0, 1.0);
}

class _WaterPainter extends CustomPainter {
  _WaterPainter({
    required this.trip,
    required this.from,
    required this.to,
    required this.itemWidth,
    required this.isDark,
  }) : super(repaint: trip);

  final AnimationController trip;
  final double from;
  final double to;
  final double itemWidth;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // خارج القفزة ترسم الفقاعةَ الساكنة نفسها.
    if (!trip.isAnimating) return;
    final t = trip.value;
    final restWidth = itemWidth - 8;
    final restHeight = size.height - 8;
    final glass = Colors.white.withValues(alpha: isDark ? .16 : .34);

    _ring(canvas, from, size, restWidth, restHeight, _WaterHop.takeoffRing(t));
    _ring(canvas, to, size, restWidth, restHeight, _WaterHop.landingRing(t));

    final (stretchX, stretchY, taper) = _WaterHop.shape(t);
    final height = restHeight * stretchY;
    final width = math.max(restWidth * stretchX, height);
    // مقدمتها نصف دائرة بارتفاعها، وذيلها أصغر بقدر سرعتها.
    final front = height / 2;
    final back = front * (1 - .38 * taper);
    final length = width - front - back;
    // تقف على أرض الشريط وهي تتجمع وتنبسط، وتعلو في القفز أكثر كلما بعد التبويب.
    final distance = ((to - from).abs() / (itemWidth * 3)).clamp(0.0, 1.0);
    final bottom = size.height - 4 - (4 + 2 * distance) * _WaterHop.rise(t);
    final centreX = lerpDouble(from, to, _WaterHop.travel(t))!;
    final ahead = to >= from ? 1.0 : -1.0;

    // ترسم متجهة إلى اليمين، وتنقلب إن كانت ذاهبة إلى اليسار.
    canvas
      ..save()
      ..translate(centreX, bottom - front)
      ..scale(ahead, 1)
      ..translate(-(length + front - back) / 2, 0);
    final drop = _dropPath(back, front, length);
    final bounds = drop.getBounds();
    canvas
      ..drawPath(
        drop.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: isDark ? .20 : .08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawPath(
        drop,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [glass, Colors.white.withValues(alpha: isDark ? .04 : .10)],
          ).createShader(bounds),
      )
      ..drawPath(
        drop,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = glass,
      );
    // لمعة الماء على مقدمتها وهي تجري.
    if (taper > .01) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(length + front * .1, -front * .45),
          width: front * .8,
          height: front * .3,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: (isDark ? .28 : .55) * taper)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
    canvas.restore();
  }

  /// كبسولة ماء: دائرة الذيل في المبدأ ودائرة المقدمة على بعد [length]، يجمعهما خطّا مماس.
  static Path _dropPath(double back, double front, double length) {
    if (length < .5) {
      return Path()
        ..addOval(Rect.fromCircle(center: Offset(length, 0), radius: front));
    }
    // عمودي خطّي المماس على اتجاه الحركة.
    final k = ((back - front) / length).clamp(-1.0, 1.0);
    final h = math.sqrt(1 - k * k);
    final angle = math.atan2(h, k);
    return Path()
      ..moveTo(back * k, back * h)
      ..lineTo(length + front * k, front * h)
      ..arcTo(Rect.fromCircle(center: Offset(length, 0), radius: front), angle,
          -2 * angle, false)
      ..lineTo(back * k, -back * h)
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: back), -angle,
          -(2 * math.pi - 2 * angle), false)
      ..close();
  }

  /// حلقة ماء تتسع من حول الفقاعة وتخبو، ويقصّها حد الشريط.
  void _ring(Canvas canvas, double centre, Size size, double restWidth,
      double restHeight, double progress) {
    if (progress <= 0 || progress >= 1) return;
    final fade = math.pow(1 - progress, 1.6).toDouble();
    final spread = Curves.easeOutCubic.transform(progress);
    final rect = Rect.fromCenter(
      center: Offset(centre, size.height / 2),
      width: restWidth * (1 + .45 * spread),
      height: restHeight * (1 + .14 * spread),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (isDark ? Colors.white : Colors.black)
            .withValues(alpha: (isDark ? .30 : .10) * fade),
    );
  }

  @override
  bool shouldRepaint(_WaterPainter oldDelegate) =>
      oldDelegate.trip != trip ||
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
