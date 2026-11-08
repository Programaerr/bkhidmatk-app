import 'package:flutter/material.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../auth/push_key.dart';

/// A single bottom-navigation destination definition used by all shells.
class NavItem {
  const NavItem(this.label, this.icon, this.activeIcon, {this.darkBar = false});
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// صفحة فيديو: شريط التنقل داكن فوقها كما في إنستغرام.
  final bool darkBar;
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
      return Scaffold(
        extendBody: extendBody,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: _InstagramBar(
          index: index,
          items: items,
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

/// ارتفاع أعلى شريط التنقل عن أسفل الشاشة، لما يُرسم فوقه مباشرة (مثل شريط تقدم الفيديو).
double glassBarTop(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).bottom + _InstagramBar.height;

/// شريط التنقل السفلي مثل إنستغرام (طلب المستخدم): شريط مسطح بعرض الشاشة وفوقه خط رفيع،
/// أيقونة التبويب المختار ممتلئة وغيرها مفرغة، بلا فقاعة ولا حركة، واللمسة تفتح التبويب فوراً.
/// على صفحة الأعمال (الفيديو) يصير الشريط داكناً كما في إنستغرام.
class _InstagramBar extends StatelessWidget {
  const _InstagramBar({
    required this.index,
    required this.items,
    required this.onSelect,
  });

  /// ارتفاع الشريط فوق شريط النظام.
  static const height = 50.0;

  final int index;
  final List<NavItem> items;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final video = items[index].darkBar;
    final (Color background, Color line, Color ink) = video
        ? (Colors.black, const Color(0xFF262626), Colors.white)
        : night
            ? (const Color(0xFF212121), const Color(0xFF363636), Colors.white)
            : (Colors.white, const Color(0xFFDBDBDB), const Color(0xFF262626));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: line, width: .5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final (i, item) in items.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: item.label,
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                        child: Center(
                          child: Icon(
                            i == index ? item.activeIcon : item.icon,
                            size: 26,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
