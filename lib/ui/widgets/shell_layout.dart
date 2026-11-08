import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FragmentProgram, ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../auth/push_key.dart';

/// A single bottom-navigation destination definition used by all shells.
class NavItem {
  const NavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

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

class _AppShellLayoutState extends State<AppShellLayout>
    with SingleTickerProviderStateMixin {
  /// أكثر التبويبات ظهوراً حديثاً يبقى مبنياً، وما سواها يُترك فتتحرر ذاكرته.
  /// التبويب الأحدث في آخر القائمة. تبويبات الزبون الخمسة تبقى كلها: إعادة بناء تبويب
  /// تُرك كانت تعيد رسومه وتحميله فيتقطع الرجوع إليه، والفيديو يتحرر وحده حين يُخفى تبويبه.
  static const _maxAlive = 5;
  final _alive = <int>[];

  // التبويب الجديد يظهر بتلاشٍ وانزلاق قصير، وما خلفه يبقى محفوظاً.
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final _fade =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
  late final _slide = Tween<Offset>(
    begin: const Offset(0.035, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic));

  @override
  void didUpdateWidget(AppShellLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _entrance.forward(from: 0);
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

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
            child: FadeTransition(
              opacity: i == index ? _fade : kAlwaysCompleteAnimation,
              child: SlideTransition(
                position: i == index
                    ? _slide
                    : const AlwaysStoppedAnimation(Offset.zero),
                child: _alive.contains(i) ? page : const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );

    if (!wide) {
      return Scaffold(
        extendBody: extendBody,
        body: body,
        floatingActionButton: floatingActionButton,
        // الشريط يبقى بترتيبه العربي في اللغتين: الرئيسية في اليمين (طلب المستخدم).
        bottomNavigationBar: Directionality(
          textDirection: TextDirection.rtl,
          child: _GlassNavigationBar(
            index: index,
            items: items,
            accent: accent,
            onSelect: onSelect,
          ),
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
                  BorderDirectional(end: BorderSide(color: theme.colorScheme.outline)),
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

/// شريط التنقل السفلي: لمسة واحدة تفتح التبويب، وتقفز الفقاعة إليه كالهلام ثم تستقر. والبقاء
/// على الفقاعة أو سحبها يكبّرها فتتبع الإصبع يميناً ويساراً وتكبّر ما تحتها، ويُفتح التبويب الذي
/// يُترك عليه.
/// ارتفاع أعلى زجاج شريط التنقل عن أسفل الشاشة، لما يُرسم فوقه مباشرة (مثل شريط تقدم الفيديو).
/// تحت الزجاج شريط النظام إن وُجد، ثم 4 بين الزجاج ومكانه.
double glassBarTop(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).bottom +
    _GlassNavigationBarState._height +
    4;

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
  // قفزة الفقاعة من تبويب إلى آخر كالهلام (طلب المستخدم بدل حركة فينوم).
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
        _JellyHop.travel(_trip.value),
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
    // في القفز بين التبويبات ترسم الفقاعةَ [_JellyPainter]، لا الزجاج.
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
                                      // الفقاعة في قفزتها، بلون الفقاعة الساكنة وحافتها.
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: AnimatedBuilder(
                                            animation: _trip,
                                            builder: (context, _) =>
                                                _trip.isAnimating
                                                    ? CustomPaint(
                                                        painter: _JellyPainter(
                                                          from: _tripFrom,
                                                          to: _tabCenter(
                                                              _tripTo, width),
                                                          t: _trip.value,
                                                          itemWidth: itemWidth,
                                                          isDark: isDark,
                                                        ),
                                                      )
                                                    : const SizedBox.shrink(),
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

/// قفزة الفقاعة الهلامية من تبويب إلى آخر (طلب المستخدم بدل حركة فينوم): تنضغط قبل القفز،
/// وتطير في قوس صغير داخل الشريط وهي ممطوطة مع اتجاهها، ثم تهبط فتنضغط وتهتز كالهلام حتى تسكن
/// على شكل الفقاعة الساكنة تماماً.
abstract final class _JellyHop {
  /// نهاية الانضغاط قبل القفز، ولحظة الهبوط.
  static const takeoff = .14;
  static const land = .64;

  static double _flight(double t) =>
      ((t - takeoff) / (land - takeoff)).clamp(0.0, 1.0);

  /// كم قطعت من الطريق: صفر قبل القفز، وواحد من لحظة الهبوط.
  static double travel(double t) => Curves.easeInOutCubic.transform(_flight(t));

  /// ارتفاعها عن مكانها نسبةً إلى أعلى القوس.
  static double rise(double t) => math.sin(math.pi * _flight(t));

  /// عرضها وارتفاعها نسبةً إلى الفقاعة الساكنة.
  static (double, double) shape(double t) {
    if (t < takeoff) {
      final squash = math.sin(math.pi / 2 * t / takeoff);
      return (1 + .12 * squash, 1 - .14 * squash);
    }
    if (t < land) {
      final flight = _flight(t);
      final stretch = math.sin(math.pi * flight);
      final squash = 1 - (flight / .2).clamp(0.0, 1.0);
      return (1 + .16 * stretch + .12 * squash, 1 - .2 * stretch - .14 * squash);
    }
    final settle = (t - land) / (1 - land);
    final wobble =
        math.sin(settle * math.pi * 3) * math.pow(1 - settle, 2).toDouble();
    return (1 + .14 * wobble, 1 - .16 * wobble);
  }
}

class _JellyPainter extends CustomPainter {
  const _JellyPainter({
    required this.from,
    required this.to,
    required this.t,
    required this.itemWidth,
    required this.isDark,
  });

  final double from;
  final double to;
  final double t;
  final double itemWidth;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final (stretchX, stretchY) = _JellyHop.shape(t);
    final width = (itemWidth - 8) * stretchX;
    final height = (size.height - 8) * stretchY;
    // تقف على أرض الشريط وهي تنضغط، وتعلو في القفز أكثر كلما بعد التبويب، ولا تخرج من الشريط.
    final distance = ((to - from).abs() / (itemWidth * 3)).clamp(0.0, 1.0);
    final bottom = size.height - 4 - (5 + 2 * distance) * _JellyHop.rise(t);
    final centreX = lerpDouble(from, to, _JellyHop.travel(t))!;
    final rect = Rect.fromLTRB(
      centreX - width / 2,
      bottom - height,
      centreX + width / 2,
      bottom,
    );
    final jelly = RRect.fromRectAndRadius(rect, Radius.circular(height / 2));

    // ألوان الفقاعة الساكنة وظلها وحافتها.
    final glass = Colors.white.withValues(alpha: isDark ? .16 : .34);
    canvas
      ..drawRRect(
        jelly.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: isDark ? .20 : .08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawRRect(
        jelly,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [glass, Colors.white.withValues(alpha: isDark ? .04 : .10)],
          ).createShader(rect),
      )
      ..drawRRect(
        jelly.deflate(.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = glass,
      );
  }

  @override
  bool shouldRepaint(_JellyPainter oldDelegate) =>
      oldDelegate.t != t ||
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
                duration: const Duration(milliseconds: 260),
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
