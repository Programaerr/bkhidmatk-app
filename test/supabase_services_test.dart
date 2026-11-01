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
}
