import 'package:flutter/material.dart';

import '../widgets/shell_layout.dart';
import 'bookings_tab.dart';
import 'create_post_screen.dart';
import 'feed_tab.dart';
import 'home_tab.dart';
import 'profile_tab.dart';
import 'services_tab.dart';
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;
  int _feedTick = 0;

  static const _items = [
    NavItem('الرئيسية', Icons.home_outlined, Icons.home_rounded),
    NavItem('الخدمات', Icons.grid_view_outlined, Icons.grid_view_rounded),
    NavItem('حجوزاتي', Icons.event_note_outlined, Icons.event_note_rounded),
    NavItem('الأعمال', Icons.video_library_outlined, Icons.video_library_rounded),
    NavItem('حسابي', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  Future<void> _createPost() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (created == true && mounted) {
      setState(() {
        _feedTick++;
        _index = 3;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(
        onBrowseServices: () => setState(() => _index = 1),
        onOpenFeed: () => setState(() => _index = 3),
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
      FeedTab(refreshTick: _feedTick, onCreate: _createPost),
      ProfileTab(
        onOpenBookings: () => setState(() => _index = 2),
        onOpenFeed: () => setState(() => _index = 3),
      ),
    ];

    return AppShellLayout(
      index: _index,
      items: _items,
      pages: pages,
      onSelect: (i) => setState(() => _index = i),
      floatingActionButton: _index == 3
          ? FloatingActionButton.extended(
              onPressed: _createPost,
              backgroundColor: const Color(0xFFFFD400),
              foregroundColor: const Color(0xFF0B0B0D),
              icon: const Icon(Icons.videocam_rounded),
              label: const Text('انشر عملك',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            )
          : null,
    );
  }
}
