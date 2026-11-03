import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jaik/ui/widgets/shell_layout.dart';

void main() {
  testWidgets('glass navigation stays at bottom and selects while touching',
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
    expect(find.text('page 0'), findsOneWidget);
    final navigationRect =
        tester.getRect(find.byKey(const ValueKey('glass-navigation-bar')));
    expect(navigationRect.bottom, greaterThan(800));
    expect(navigationRect.bottom, lessThanOrEqualTo(844));

    await tester.tap(find.text('الخدمات'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final entrance = tester.widget<FadeTransition>(find
        .ancestor(of: find.text('page 1'), matching: find.byType(FadeTransition))
        .first);
    expect(entrance.opacity.value, lessThan(1));
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

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('الرئيسية')));
    await tester.pump();
    expect(selectedIndex, 0);
    await gesture.moveTo(tester.getCenter(find.text('الخدمات')));
    await tester.pumpAndSettle();
    expect(selectedIndex, 1);
    expect(find.text('page 1'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.text('حسابي')));
    await tester.pumpAndSettle();
    expect(selectedIndex, 2);
    expect(find.text('page 2'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
