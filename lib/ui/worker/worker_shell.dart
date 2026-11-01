import 'package:flutter/material.dart';

import '../customer/profile_tab.dart';
import '../customer/reels_tab.dart';
import '../widgets/shell_layout.dart';

/// غلاف الموظف بالتوظيف: يرى فقط ما تسمح به الإدارة —
/// قسم «أعمالنا» وحسابه الشخصي، دون حجوزات أو خدمات أو منشورات.
class WorkerShell extends StatefulWidget {
  const WorkerShell({super.key});

  @override
  State<WorkerShell> createState() => _WorkerShellState();
}

class _WorkerShellState extends State<WorkerShell> {
  int _index = 0;

  static const _items = [
    NavItem('أعمالنا', Icons.play_circle_outline_rounded,
        Icons.play_circle_fill_rounded),
    NavItem('حسابي', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      ReelsTab(active: _index == 0),
      ProfileTab(
        workerMode: true,
        onOpenBookings: () => setState(() => _index = 0),
      ),
    ];

    return AppShellLayout(
      index: _index,
      items: _items,
      pages: pages,
      onSelect: (i) => setState(() => _index = i),
      darkNavigation: _index == 0,
    );
  }
}
