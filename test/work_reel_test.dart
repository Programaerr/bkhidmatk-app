import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:jaik/data/models.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/customer/work_reel.dart';

import 'fake_repository.dart';

class _WorkCommentsRepo extends FakeRepo {
  final List<WorkComment> comments = [
    WorkComment(
      id: 1,
      workId: 7,
      userId: 3,
      userName: 'عميل سابق',
      body: 'تعليق موجود',
      createdAt: DateTime(2026),
    ),
  ];
  bool failReload = false;

  @override
  Future<List<WorkComment>> workComments(
    int workId, {
    int? viewerId,
    bool isAdmin = false,
  }) async {
    if (failReload) throw StateError('Comments refresh failed');
    return comments;
  }

  @override
  Future<int> addWorkComment(WorkComment comment) async {
    final id = comments.length + 1;
    comments.add(
      WorkComment(
        id: id,
        workId: comment.workId,
        userId: comment.userId,
        parentCommentId: comment.parentCommentId,
        userName: comment.userName,
        body: comment.body,
        createdAt: comment.createdAt,
      ),
    );
    failReload = true;
    return id;
  }
}

void main() {
  testWidgets('reel actions stay above the bottom navigation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: WorkReel(
            work: OurWork(
              id: 7,
              title: 'عمل تجريبي',
              videoUrl: '',
              createdAt: DateTime(2026),
            ),
            isActive: false,
            onChanged: () {},
          ),
          bottomNavigationBar: const SizedBox(
            key: ValueKey('test-bottom-navigation'),
            height: 82,
          ),
        ),
      ),
    );

    final actionRect = tester.getRect(find.byIcon(Icons.mode_comment_rounded));
    final navigationRect =
        tester.getRect(find.byKey(const ValueKey('test-bottom-navigation')));
    expect(actionRect.bottom, lessThan(navigationRect.top));
  });

  testWidgets('posted reel comment remains visible if refresh fails',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = _WorkCommentsRepo();
    final state = AppState(repository: repository)
      ..user = AppUser(
        id: 3,
        name: 'عميل جديد',
        phone: '07701234567',
        passwordHash: '',
        createdAt: DateTime(2026),
      );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: WorkReel(
                work: OurWork(
                  id: 7,
                  title: 'عمل تجريبي',
                  videoUrl: '',
                  createdAt: DateTime(2026),
                ),
                isActive: false,
                onChanged: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.mode_comment_rounded));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('التعليقات'), findsOneWidget);
    expect(find.text('تعليق موجود'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'تعليقي الجديد');
    await tester.tap(find.byIcon(Icons.send_rounded));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('تعليقي الجديد'), findsOneWidget);
    expect(find.text('تعليق موجود'), findsOneWidget);
    expect(find.text('تعذر تحديث بعض التعليقات'), findsOneWidget);
  });
}

void _noop() {}
