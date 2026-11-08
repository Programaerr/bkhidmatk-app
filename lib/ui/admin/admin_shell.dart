import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';


import '../../core/language.dart';
import '../../core/theme.dart';
import '../auth/push_key.dart';
import '../widgets/shell_layout.dart';
import 'admin_bookings.dart';
import 'admin_dashboard.dart';
import 'admin_more.dart';
import 'admin_services.dart';
import 'admin_works.dart';

/// لوحة التحكم: تُفتح من صفحة حساب المدير، ويرجع منها زر الرجوع الاعتيادي إلى التطبيق.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  // تُبنى مع كل بناء، فتتبع لغة التطبيق. أيقونات بأشكال رموز آبل، وعلى الآيفون الرموز نفسها.
  static List<NavItem> get _items => [
    NavItem(tr('الرئيسية', 'Home'), CupertinoIcons.square_grid_2x2,
        CupertinoIcons.square_grid_2x2_fill,
        symbol: 'square.grid.2x2.fill'),
    NavItem(tr('الحجوزات', 'Bookings'), CupertinoIcons.calendar, CupertinoIcons.calendar,
        symbol: 'calendar'),
    NavItem(tr('الخدمات', 'Services'), CupertinoIcons.wrench, CupertinoIcons.wrench_fill,
        symbol: 'wrench.and.screwdriver.fill'),
    NavItem(tr('الأعمال', 'Works'), CupertinoIcons.play_rectangle,
        CupertinoIcons.play_rectangle_fill,
        symbol: 'play.rectangle.fill'),
    NavItem(tr('المزيد', 'More'), CupertinoIcons.ellipsis_circle,
        CupertinoIcons.ellipsis_circle_fill,
        symbol: 'ellipsis.circle.fill'),
  ];

  void _go(int index) => setState(() => _index = index);

  final _bookingsFilter = ValueNotifier<BookingsFilterRequest?>(null);

  /// يفتح تبويب الحجوزات على حالة معينة، مثل الطلبات الجديدة بانتظار موافقتك.
  void _openBookings(String? status) {
    _bookingsFilter.value = BookingsFilterRequest(status);
    _go(1);
  }

  @override
  void dispose() {
    _bookingsFilter.dispose();
    super.dispose();
  }

  // تبقى هي نفسها بين البناءات، فتبديل التبويب لا يعيد بناء التبويبات كلها.
  late final _pages = [
    AdminDashboard(
      onOpenBookings: _openBookings,
      onOpenWorks: () => _go(3),
    ),
    AdminBookings(filterRequest: _bookingsFilter),
    const AdminServices(),
    const AdminWorks(),
    const AdminMore(),
  ];

  @override
  Widget build(BuildContext context) {
    // رجوع الهاتف يعود إلى الرئيسية أولاً، ثم يخرج إلى التطبيق.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: AppShellLayout(
        index: _index,
        items: _items,
        pages: _pages,
        onSelect: _go,
        // قوائم اللوحة عادية بهامش 26 فقط، فلو امتدت خلف الشريط لخفي آخر ما فيها ولم يمكن النزول إليه.
        extendBody: false,
      ),
    );
  }
}

/// رأس صفحات لوحة التحكم: زر الرجوع إلى التطبيق، والعنوان، والإجراءات.
class AdminHeader extends StatelessWidget {
  const AdminHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        child: Row(
          children: [
            if (Navigator.canPop(context))
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: SizedBox(
                  width: PushKeyBack.width * pushKeyUnit(context),
                  child: const PushKeyBack(),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontSize: 19)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(tr('مدير', 'Admin'),
                            style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.onGold)),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 10.5)),
                  ],
                ],
              ),
            ),
            for (final action in actions) ...[
              const SizedBox(width: 6),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
