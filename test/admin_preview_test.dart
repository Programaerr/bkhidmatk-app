import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/data/preview_repository.dart';
import 'package:jaik/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local admin preview opens an admin session without Supabase', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      repository: PreviewRepository(),
      developmentAdminPreview: true,
    );

    await state.boot();

    expect(state.isAdmin, isTrue);
    expect(state.isLoggedIn, isTrue);
    expect(state.usesCloudAuth, isFalse);
    expect(state.user?.phone, '07700000000');
    state.dispose();
  });
}
