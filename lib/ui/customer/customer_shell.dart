import 'package:flutter/material.dart';

import '../widgets/shell_layout.dart';
import 'bookings_tab.dart';
import 'home_tab.dart';
import 'our_work_tab.dart';
import 'profile_tab.dart';
import 'services_tab.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({
    super.key,
    this.adminPreview = false,
    this.onOpenAdminDashboard,
  });

  final bool adminPreview;
  final VoidCallback? onOpenAdminDashboard;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  // تبقى هي نفسها بين البناءات، فتبديل التبويب لا يعيد بناء التبويبات كلها.
  late final _home = HomeTab(onOpenProfile: () => _go(4));
  late final _services = SafeArea(
    bottom: false,
    child: Column(
      children: [
        CustomerHeader(
          title: 'كل الخدمات',
          subtitle: 'اختر الخدمة المناسبة واحجز خلال دقيقة',
        ),
        const Expanded(child: ServicesTab()),
      ],
    ),
  );
  late final _bookings = BookingsTab(onBrowse: () => _go(1));
  late final _profile = ProfileTab(
    onOpenBookings: () => _go(2),
    onOpenAdminDashboard: widget.onOpenAdminDashboard,
  );

  static const _items = [
    NavItem('الرئيسية', Icons.home_outlined, Icons.home_rounded),
    NavItem('الخدمات', Icons.grid_view_outlined, Icons.grid_view_rounded),
    NavItem('حجوزاتي', Icons.event_note_outlined, Icons.event_note_rounded),
    NavItem(
        'أعمالنا', Icons.video_library_outlined, Icons.video_library_rounded),
    NavItem('حسابي', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return AppShellLayout(
      index: _index,
      items: _items,
      pages: [
        _home,
        _services,
        _bookings,
        _index == 3 ? const OurWorkTab() : const OurWorkTab(isActive: false),
        _profile,
      ],
      onSelect: _go,
      topBanner: widget.adminPreview
          ? Material(
              color: const Color(0xFFFFF3B0),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('العودة إلى لوحة المدير'),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
