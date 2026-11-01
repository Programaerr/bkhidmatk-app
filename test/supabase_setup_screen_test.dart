import 'package:flutter_test/flutter_test.dart';
import 'package:jaik/ui/auth/supabase_setup_screen.dart';

void main() {
  testWidgets('explains that web requires Supabase configuration',
      (tester) async {
    await tester.pumpWidget(const SupabaseSetupApp());

    expect(
      find.text('إعداد Supabase مطلوب لتشغيل التطبيق في المتصفح'),
      findsOneWidget,
    );
    expect(
      find.textContaining('--dart-define=SUPABASE_URL='),
      findsOneWidget,
    );
  });
}
