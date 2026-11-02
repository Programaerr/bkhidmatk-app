import 'package:flutter_test/flutter_test.dart';

/// يمر على إطارات انتقال الصفحة كما تحدث في الهاتف: 200 مللي ثانية بإطارات عادية،
/// لأن الإطار المتأخر لا يُقدّم الحركة.
Future<void> pumpRouteFrames(WidgetTester tester) async {
  for (var i = 0; i < 13; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
