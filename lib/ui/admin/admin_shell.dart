import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../widgets/quick_route.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'admin_bookings.dart';
import 'admin_dashboard.dart';
import 'admin_more.dart';
import 'admin_services.dart';
import 'admin_works.dart';
import '../customer/customer_shell.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _items = [
    NavItem('الرئيسية', Icons.space_dashboard_outlined,
        Icons.space_dashboard_rounded),
    NavItem('الحجوزات', Icons.event_note_outlined, Icons.event_note_rounded),
    NavItem('الخدمات', Icons.handyman_outlined, Icons.handyman_rounded),
    NavItem(
        'الأعمال', Icons.video_library_outlined, Icons.video_library_rounded),
    NavItem('المزيد', Icons.more_horiz_rounded, Icons.more_horiz_rounded),
  ];

  void _go(int index) => setState(() => _index = index);

  // تبقى هي نفسها بين البناءات، فتبديل التبويب لا يعيد بناء التبويبات كلها.
  late final _pages = [
    AdminDashboard(
      onOpenBookings: () => _go(1),
      onOpenMessages: () => _go(4),
      onOpenWorks: () => _go(3),
      onPreviewApp: () => Navigator.push(
        context,
        QuickRoute(
          builder: (_) => CustomerShell(
            adminPreview: true,
            onOpenAdminDashboard: () => Navigator.pop(context),
          ),
        ),
      ),
    ),
    const AdminBookings(),
    const AdminServices(),
    const AdminWorks(),
    AdminMore(onNavigate: _go),
  ];

  @override
  Widget build(BuildContext context) {
    return AppShellLayout(
      index: _index,
      items: _items,
      pages: _pages,
      onSelect: _go,
    );
  }
}

class AdminHeader extends StatelessWidget {
  const AdminHeader({
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(showBack ? 8 : 18, 12, 18, 10),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: () => Navigator.pop(context),
              )
            else
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 10),
                child: BrandLogo(size: 42, radius: 12),
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
                      if (!showBack) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text('مدير',
                              style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink)),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 10.5)),
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
