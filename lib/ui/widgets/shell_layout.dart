import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../core/utils.dart';

/// A single bottom-navigation destination definition used by both shells.
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
    this.headerBadge,
    this.topBanner,
  });

  final int index;
  final List<NavItem> items;
  final List<Widget> pages;
  final ValueChanged<int> onSelect;
  final Widget? floatingActionButton;
  final Color accent;
  final Widget? headerBadge;
  final Widget? topBanner;

  @override
  State<AppShellLayout> createState() => _AppShellLayoutState();
}

class _AppShellLayoutState extends State<AppShellLayout> {
  // التبويب لا يُبنى ولا يجلب بياناته قبل أول فتح له.
  final _opened = <int>{};

  @override
  Widget build(BuildContext context) {
    final AppShellLayout(
      :index,
      :items,
      :pages,
      :onSelect,
      :floatingActionButton,
      :topBanner,
    ) = widget;
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final body = IndexedStack(index: index, children: pages);

    if (!wide) {
      return Scaffold(
        extendBody: true,
        body: topBanner == null
            ? body
            : Column(
                children: [
                  topBanner,
                  Expanded(child: body),
                ],
              ),
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
          Expanded(
            child: topBanner == null
                ? body
                : Column(
                    children: [
                      topBanner,
                      Expanded(child: body),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
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

class _GlassNavigationBarState extends State<_GlassNavigationBar> {
  final _navigationBoundsKey = GlobalKey();
  bool _isDragging = false;

  void _selectAt(Offset globalPosition) {
    final renderObject =
        _navigationBoundsKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || renderObject.size.width <= 0) return;

    final localPosition = renderObject.globalToLocal(globalPosition);
    final itemWidth = renderObject.size.width / widget.items.length;
    final direction = Directionality.of(context);
    final logicalX = direction == TextDirection.rtl
        ? renderObject.size.width - localPosition.dx
        : localPosition.dx;
    final nextIndex =
        (logicalX / itemWidth).floor().clamp(0, widget.items.length - 1);
    if (nextIndex != widget.index) widget.onSelect(nextIndex);
  }

  void _startDrag(Offset globalPosition) {
    setState(() => _isDragging = true);
    _selectAt(globalPosition);
  }

  void _updateDrag(Offset globalPosition) {
    _selectAt(globalPosition);
  }

  void _endDrag() {
    if (mounted) setState(() => _isDragging = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SizedBox(
        height: 82,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SizedBox(
              height: 66,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? .25 : .12),
                      blurRadius: 22,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth =
                            constraints.maxWidth / widget.items.length;
                        return Listener(
                          key: const ValueKey('glass-navigation-bar'),
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) => _startDrag(event.position),
                          onPointerMove: (event) => _updateDrag(event.position),
                          onPointerUp: (_) => _endDrag(),
                          onPointerCancel: (_) => _endDrag(),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  theme.colorScheme.surface
                                      .withValues(alpha: isDark ? .78 : .72),
                                  theme.colorScheme.surface
                                      .withValues(alpha: isDark ? .62 : .56),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(
                                color: Colors.white
                                    .withValues(alpha: isDark ? .16 : .48),
                              ),
                            ),
                            child: Stack(
                              key: _navigationBoundsKey,
                              children: [
                                AnimatedPositionedDirectional(
                                  duration: const Duration(milliseconds: 480),
                                  curve: Curves.easeOutBack,
                                  start: itemWidth * widget.index + 4,
                                  top: 4,
                                  bottom: 4,
                                  width: itemWidth - 8,
                                  child: AnimatedScale(
                                    scale: _isDragging ? 1.06 : 1,
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(32),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            widget.accent
                                                .withValues(alpha: .30),
                                            widget.accent
                                                .withValues(alpha: .13),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: widget.accent
                                              .withValues(alpha: .28),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: widget.accent
                                                .withValues(alpha: .13),
                                            blurRadius: 12,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    for (var i = 0;
                                        i < widget.items.length;
                                        i++)
                                      Expanded(
                                        child: _GlassNavigationDestination(
                                          item: widget.items[i],
                                          selected: i == widget.index,
                                          accent: widget.accent,
                                          onTap: () => widget.onSelect(i),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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
                  color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: selected ? 10 : 9,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerHeader extends StatelessWidget {
  const CustomerHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
            bottom: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: .6))),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showBack)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _CircleIconButton(
                  icon: Icons.arrow_forward_rounded,
                  onTap: () => Navigator.maybePop(context),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge = 0,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
    if (badge <= 0) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(100),
              border:
                  Border.all(color: theme.scaffoldBackgroundColor, width: 2),
            ),
            child: Text(
              badge > 9 ? '9+' : '$badge',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String newInvoiceNumber(int bookingId, DateTime date) =>
    invoiceNumber(bookingId, date);

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

StatusKind statusKind(String status) => switch (status) {
      BookingStatus.completed => StatusKind.success,
      BookingStatus.cancelled => StatusKind.danger,
      BookingStatus.pending => StatusKind.warning,
      _ => StatusKind.info,
    };

enum StatusKind { success, danger, warning, info }
