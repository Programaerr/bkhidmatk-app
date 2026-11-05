import 'dart:async';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

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
  /// أكثر التبويبات ظهوراً حديثاً يبقى مبنياً، وما سواها يُترك فتتحرر ذاكرته
  /// (الرسوم والصور والفيديو). التبويب الأحدث في آخر القائمة.
  static const _maxAlive = 3;
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

/// شريط التنقل السفلي: لمسة واحدة تفتح التبويب. والبقاء على الفقاعة أو سحبها يحوّلها إلى مجهر
/// يتحرك يميناً ويساراً ويكبّر ما تحته، ويُفتح التبويب الذي يُترك عليه.
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

class _GlassNavigationBarState extends State<_GlassNavigationBar>
    with SingleTickerProviderStateMixin {
  static const _height = 60.0;
  // البقاء على الفقاعة هذه المدة، أو تحريك الإصبع هذه المسافة، يحوّلها إلى مجهر.
  static const _holdDelay = Duration(milliseconds: 180);
  static const _moveToLens = 8.0;

  final _barKey = GlobalKey();
  final _boundsKey = GlobalKey();
  bool _isDragging = false;

  late final _lens = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  bool _lensOn = false;
  double _fingerX = 0;
  Offset? _downAt;
  Timer? _hold;
  // إصبع واحد يحرّك الشريط، وما يلمسه إصبع ثانٍ في الوقت نفسه يُهمل.
  int? _pointer;

  @override
  void dispose() {
    _hold?.cancel();
    _lens.dispose();
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
    final globalPosition = event.position;
    _setDragging(true);
    _scrub(globalPosition);
    _downAt = globalPosition;
    _hold?.cancel();
    _hold = Timer(_holdDelay, () => _startLens(globalPosition));
  }

  void _touchMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final globalPosition = event.position;
    if (!_lensOn) {
      final down = _downAt;
      if (down == null || (globalPosition - down).distance < _moveToLens) {
        return;
      }
      _startLens(globalPosition);
    }
    setState(() => _fingerX = _barX(globalPosition));
  }

  void _startLens(Offset globalPosition) {
    _hold?.cancel();
    if (!mounted || _lensOn) return;
    setState(() {
      _lensOn = true;
      _fingerX = _barX(globalPosition);
    });
    _lens.forward();
  }

  // ترك المجهر يفتح التبويب الذي تحته، ويصغر المجهر إلى فقاعته.
  void _touchUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    final globalPosition = event.position;
    _hold?.cancel();
    _downAt = null;
    _setDragging(false);
    if (!_lensOn) return;
    setState(() {
      _lensOn = false;
      _fingerX = _barX(globalPosition);
    });
    _scrub(globalPosition);
    _lens.reverse();
  }

  void _touchCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _hold?.cancel();
    _downAt = null;
    _setDragging(false);
    if (!_lensOn) return;
    setState(() => _lensOn = false);
    _lens.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(_height / 2);
    final items = widget.items;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 6, 16, 8),
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
                        // مع ظهور المجهر يصغر الشريط وأيقوناته، ويبقى المجهر بحجمه.
                        child: AnimatedBuilder(
                          animation: _lens,
                          builder: (context, bar) => Transform.scale(
                            scale: 1 -
                                .08 * Curves.easeOutCubic.transform(_lens.value),
                            child: bar,
                          ),
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
                                      colors: isDark
                                          ? [
                                              theme.colorScheme.surface
                                                  .withValues(alpha: .62),
                                              theme.colorScheme.surface
                                                  .withValues(alpha: .46),
                                            ]
                                          : [
                                              Colors.white
                                                  .withValues(alpha: .50),
                                              Colors.white
                                                  .withValues(alpha: .32),
                                            ],
                                    ),
                                    borderRadius: radius,
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: isDark ? .18 : .70),
                                    ),
                                  ),
                                  child: Stack(
                                    key: _boundsKey,
                                    children: [
                                      AnimatedPositionedDirectional(
                                        // تحت المجهر تقفز الفقاعة إلى مكانها الجديد دون حركة.
                                        duration: _lensOn || _lens.value > 0
                                            ? Duration.zero
                                            : const Duration(milliseconds: 380),
                                        curve: Curves.easeOutBack,
                                        start: itemWidth * widget.index + 4,
                                        top: 4,
                                        bottom: 4,
                                        width: itemWidth - 8,
                                        child: AnimatedScale(
                                          scale: _isDragging ? 1.05 : 1,
                                          duration:
                                              const Duration(milliseconds: 180),
                                          curve: Curves.easeOutCubic,
                                          child: FadeTransition(
                                            opacity: ReverseAnimation(_lens),
                                            child: _bubble(isDark),
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
                      ),
                      AnimatedBuilder(
                        animation: _lens,
                        builder: (context, _) =>
                            _magnifier(width, itemWidth, isDark),
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

  // فقاعة التبويب المختار زجاج شفاف، حافتها بلونها نفسه، وأيقونتها وحدها صفراء.
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

  // المجهر: يكبر من مكان الفقاعة ويتبع الإصبع، ويكبّر الأيقونات التي تحته.
  Widget _magnifier(double width, double itemWidth, bool isDark) {
    final t = Curves.easeOutCubic.transform(_lens.value);
    if (t == 0) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    final half = itemWidth / 2;
    final finger = _fingerX.clamp(half, width - half);
    final center = lerpDouble(_tabCenter(widget.index, width), finger, t)!;
    final lensWidth = lerpDouble(itemWidth - 8, itemWidth + 18, t)!;
    final lensHeight = lerpDouble(_height - 8, _height + 16, t)!;
    final radius = BorderRadius.circular(lensHeight / 2);
    return Positioned(
      left: center - lensWidth / 2,
      top: (_height - lensHeight) / 2,
      width: lensWidth,
      height: lensHeight,
      child: IgnorePointer(
        child: Opacity(
          opacity: t,
          child: RawMagnifier(
            size: Size(lensWidth, lensHeight),
            magnificationScale: lerpDouble(1, 1.35, t)!,
            // بلا ظل: ظل المجهر يعتّم ما بداخله.
            decoration: MagnifierDecoration(
              shape: RoundedRectangleBorder(borderRadius: radius),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? .14 : .30),
                    Colors.white.withValues(alpha: isDark ? .03 : .06),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? .14 : .30),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
          child: SizedBox(
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    size: 23,
                    color:
                        selected ? accent : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
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
              : 'الدفع عند الوصول',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
