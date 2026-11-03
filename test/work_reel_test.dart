import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/customer/customer_shell.dart';
import 'package:jaik/ui/customer/our_work_tab.dart';
import 'package:jaik/ui/customer/work_reel.dart';

import 'fake_repository.dart';

final _customer = AppUser(
  id: 3,
  name: 'عميل جديد',
  phone: '07701234567',
  passwordHash: '',
  createdAt: DateTime(2026),
);

final _work = OurWork(
  id: 7,
  title: 'عمل تجريبي',
  description: 'وصف العمل',
  videoUrl: '',
  views: 38,
  likes: 1,
  commentCount: 2,
  createdAt: DateTime(2025, 11, 1),
);

class _WorksRepo extends FakeRepo {
  _WorksRepo() : super(customer: _customer);

  @override
  Future<List<OurWork>> listWorks({
    bool onlyActive = true,
    String query = '',
    int? limit,
    int? viewerId,
  }) async =>
      [_work];
}

/// فيديو مئة ثانية جاهز، يسجّل كل انتقال فيه.
class _FakeVideo extends ValueNotifier<VideoPlayerValue> implements VideoPlayerController {
  _FakeVideo()
      : super(const VideoPlayerValue(
          duration: Duration(seconds: 100),
          isInitialized: true,
        ));

  final seeks = <Duration>[];

  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    value = value.copyWith(position: position);
  }

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);

  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);

  @override
  Future<void> dispose() async {
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// مقاس هاتف المستخدم مع شريط الحالة وأزرار النظام.
void _userPhone(WidgetTester tester) {
  const padding = FakeViewPadding(top: 38.4, bottom: 48);
  tester.view
    ..physicalSize = const Size(392.7, 872.7)
    ..devicePixelRatio = 1
    ..padding = padding
    ..viewPadding = padding;
  addTearDown(tester.view.reset);
}

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

  testWidgets('the works video fills the screen under the status bar, with white status icons',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _userPhone(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(repository: _WorksRepo())..user = _customer,
        child: const MaterialApp(
          home: Scaffold(body: OurWorkTab(isActive: false)),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getRect(find.byType(WorkReel)), const Rect.fromLTWH(0, 0, 392.7, 872.7));
    final bars = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.ancestor(
        of: find.byType(WorkReel),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(bars.value.statusBarIconBrightness, Brightness.light);
  });

  testWidgets(
      'only the logo, the name and the date sit at the bottom left, '
      'level with the actions at the bottom right, just above the bar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _userPhone(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(repository: _WorksRepo())..user = _customer,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const CustomerShell(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('أعمالنا'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    Finder inReel(Finder finder) => find.descendant(of: find.byType(WorkReel), matching: finder);
    expect(inReel(find.text('جايك')), findsOneWidget);
    expect(inReel(find.text('01/11/2025')), findsOneWidget);
    for (final gone in ['عمل تجريبي', 'وصف العمل', '38 مشاهدة', '· 01/11/2025']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(inReel(find.byIcon(Icons.visibility_outlined)), findsNothing);

    final logo = tester.getRect(
      find.ancestor(of: inReel(find.byType(ClipOval)), matching: find.byType(Container)).first,
    );
    final name = tester.getRect(inReel(find.text('جايك')));
    final date = tester.getRect(inReel(find.text('01/11/2025')));
    // على الحافة اليسرى، والترتيب كما كان: الشعار ثم جايك ثم التاريخ.
    expect(date.left, closeTo(16, .01));
    expect(date.right, lessThan(name.left));
    expect(name.right, lessThan(logo.left));

    final share = tester.getRect(inReel(find.text('مشاركة')));
    final shareIcon = tester.getRect(inReel(find.byIcon(Icons.share_rounded)));
    final heart = tester.getRect(inReel(find.byIcon(Icons.favorite_outline_rounded)));
    expect(shareIcon.center.dx, closeTo(392.7 - 12 - 26, .01));
    expect(logo.right, lessThan(shareIcon.left));
    expect(heart.bottom, lessThan(shareIcon.top));
    // الصفّان على مستوى واحد، وبينهما وبين شريط التنقل الزجاجي هامش الشريط نفسه.
    final bar = tester.getRect(find.byKey(const ValueKey('glass-navigation-bar')));
    expect(logo.bottom, closeTo(share.bottom, .01));
    expect(bar.top - logo.bottom, closeTo(16, .01));
  });

  testWidgets('in Arabic the progress bar fills from the right and dragging left moves forward',
      (tester) async {
    final video = _FakeVideo();
    addTearDown(video.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(width: 400, child: ReelProgressBar(controller: video)),
            ),
          ),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(ReelProgressBar));

    // لمسة قرب اليسار قرب نهاية الفيديو، وقرب اليمين قرب أوله.
    await tester.tapAt(Offset(bar.left + 100, bar.center.dy));
    expect(video.seeks.last.inMilliseconds, closeTo(75000, 1));
    await tester.tapAt(Offset(bar.left + 300, bar.center.dy));
    expect(video.seeks.last.inMilliseconds, closeTo(25000, 1));

    // السحب من اليمين إلى اليسار يقدّم الفيديو خطوة بعد خطوة.
    video.seeks.clear();
    final finger = await tester.startGesture(Offset(bar.left + 300, bar.center.dy));
    for (var step = 0; step < 10; step++) {
      await finger.moveBy(const Offset(-20, 0));
      await tester.pump();
    }
    await finger.up();
    expect(video.seeks.length, greaterThan(2));
    for (var i = 1; i < video.seeks.length; i++) {
      expect(video.seeks[i], greaterThan(video.seeks[i - 1]));
    }
    expect(video.seeks.last.inMilliseconds, closeTo(75000, 1));

    // الجزء الممتلئ يبدأ من الحافة اليمنى.
    final played = tester.renderObject<RenderBox>(find.byType(LinearProgressIndicator).last);
    expect(played.localToGlobal(Offset.zero).dx, closeTo(bar.right, .01));
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
