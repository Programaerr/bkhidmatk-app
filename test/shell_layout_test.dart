import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jaik/ui/widgets/shell_layout.dart';

void main() {
  testWidgets('glass navigation selects tabs by tap and RTL swipe',
      (tester) async {
    var selectedIndex = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Directionality(
            textDirection: TextDirection.rtl,
            child: AppShellLayout(
              index: selectedIndex,
              items: const [
                NavItem('الرئيسية', Icons.home_outlined, Icons.home),
                NavItem('الخدمات', Icons.grid_view_outlined, Icons.grid_view),
                NavItem('حسابي', Icons.person_outline, Icons.person),
              ],
              pages: const [
                Center(child: Text('page 0')),
                Center(child: Text('page 1')),
                Center(child: Text('page 2')),
              ],
              onSelect: (index) => setState(() => selectedIndex = index),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsOneWidget);
    expect(find.text('page 0'), findsOneWidget);

    await tester.tap(find.text('الخدمات'));
    await tester.pumpAndSettle();
    expect(selectedIndex, 1);
    expect(find.text('page 1'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('glass-navigation-bar')),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    expect(selectedIndex, 2);
    expect(find.text('page 2'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('حسابي')),
    );
    await tester.pump(const Duration(milliseconds: 140));
    await gesture.moveTo(tester.getCenter(find.text('الخدمات')));
    await tester.pumpAndSettle();
    expect(selectedIndex, 1);
    expect(find.text('page 1'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.text('الرئيسية')));
    await tester.pumpAndSettle();
    expect(selectedIndex, 0);
    expect(find.text('page 0'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
