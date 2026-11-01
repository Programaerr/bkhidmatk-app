import 'package:flutter_test/flutter_test.dart';
import 'package:jaik/data/supabase_services.dart';

void main() {
  group('SupabaseServices.phoneE164', () {
    test('normalizes Iraqi local and international numbers', () {
      expect(SupabaseServices.phoneE164('07700000000'), '+9647700000000');
      expect(SupabaseServices.phoneE164('+964 770 000 0000'), '+9647700000000');
    });

    test('rejects invalid numbers before signing in', () {
      expect(
        () => SupabaseServices.phoneE164('12345'),
        throwsFormatException,
      );
    });
  });

  group('SupabaseServices.emailForPhone', () {
    test('uses the internal password-login alias for Iraqi numbers', () {
      expect(
        SupabaseServices.emailForPhone('07717506711'),
        '07717506711@jaik.app',
      );
    });

    test('rejects invalid numbers before generating an account alias', () {
      expect(
        () => SupabaseServices.emailForPhone('12345'),
        throwsFormatException,
      );
    });
  });
}
