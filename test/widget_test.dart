import 'package:flutter_test/flutter_test.dart';

import 'package:bkhidmatk/data/repository.dart';

void main() {
  test('نقاط المكافأة: 10 نقاط لكل نجمة تقييم', () {
    expect(pointsForRating(1), 10);
    expect(pointsForRating(3), 30);
    expect(pointsForRating(5), 50);
  });

  test('التقييم خارج النطاق يُحدَّد إلى 1..5', () {
    expect(pointsForRating(0), 10);
    expect(pointsForRating(9), 50);
  });
}
