import 'package:flutter/material.dart';

import '../widgets/shell_layout.dart';
import 'bookings_tab.dart';
import 'home_tab.dart';
import 'our_work_tab.dart';
import 'profile_tab.dart';
import 'services_tab.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;
  final int _tick = 0;

  static const _items = [
    NavItem('الرئيسية', Icons.home_outlined, Icons.home_rounded),
    NavItem('الخدمات', Icons.grid_view_outlined, Icons.grid_view_rounded),
    NavItem('حجوزاتي', Icons.event_note_outlined, Icons.event_note_rounded),
    NavItem('أعمالنا', Icons.video_library_outlined, Icons.video_library_rounded),
    NavItem('حسابي', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(
        onBrowseServices: () => setState(() => _index = 1),
        onOpenWorks: () => setState(() => _index = 3),
        onOpenBookings: () => setState(() => _index = 2),
      ),
      SafeArea(
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
      ),
      BookingsTab(onBrowse: () => setState(() => _index = 1)),
      OurWorkTab(refreshTick: _tick),
      ProfileTab(
        onOpenBookings: () => setState(() => _index = 2),
      ),
    ];

    return AppShellLayout(
      index: _index,
      items: _items,
      pages: pages,
      onSelect: (i) => setState(() => _index = i),
    );
  }
}
