import 'package:flutter_test/flutter_test.dart';

import 'package:jaik/data/models.dart';

void main() {
  test('user records no longer include reward-point data', () {
    final user = AppUser(
      name: 'Test',
      phone: '07701234567',
      passwordHash: 'hash',
      createdAt: DateTime(2026),
    );

    expect(user.toMap(), isNot(contains('points')));
    expect(AppUser.fromMap(user.toMap()).toMap(), isNot(contains('points')));
  });
}
