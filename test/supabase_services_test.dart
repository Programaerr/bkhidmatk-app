import 'package:flutter_test/flutter_test.dart';
import 'package:jaik/data/supabase_services.dart';

void main() {
  test('phone password login uses the internal email alias', () {
    expect(
      SupabaseServices.emailForPhone('07701234567'),
      '07701234567@jaik.app',
    );
  });

  test('rejects invalid numbers before building the login alias', () {
    expect(
      () => SupabaseServices.emailForPhone('12345'),
      throwsFormatException,
    );
  });
}
