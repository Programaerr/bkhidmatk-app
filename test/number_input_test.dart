import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jaik/core/utils.dart';

TextEditingValue _type(
  TextInputFormatter formatter,
  String before,
  String after, {
  int? cursorBefore,
  int? cursorAfter,
}) =>
    formatter.formatEditUpdate(
      TextEditingValue(
        text: before,
        selection: TextSelection.collapsed(offset: cursorBefore ?? before.length),
      ),
      TextEditingValue(
        text: after,
        selection: TextSelection.collapsed(offset: cursorAfter ?? after.length),
      ),
    );

void main() {
  group('رقم الموبايل', () {
    const phone = IraqiPhoneFormatter();

    test('الأحرف والكلمات والرموز تُرفض', () {
      expect(_type(phone, '', 'abc').text, isEmpty);
      expect(_type(phone, '', 'أحمد').text, isEmpty);
      expect(_type(phone, '', '0770-abc_12!').text, '077012');
    });

    test('الأرقام العربية تتحول، و+964 تُحذف', () {
      expect(_type(phone, '', '٠٧٧٠').text, '0770');
      expect(_type(phone, '', '۰۷۷۰').text, '0770');
      expect(_type(phone, '', '+964 770 123 4567').text, '7701234567');
    });

    test('الطول 11 رقماً بالصفر و10 بدونه', () {
      expect(_type(phone, '', '077012345678999').text, '07701234567');
      expect(_type(phone, '', '77012345678999').text, '7701234567');
    });

    test('الحرف المرفوض وسط الرقم لا يحرّك المؤشر', () {
      final result = _type(phone, '07701', '07a701', cursorBefore: 2, cursorAfter: 3);
      expect(result.text, '07701');
      expect(result.selection.baseOffset, 2);
    });

    test('الرقم الصحيح يمر كما هو والمؤشر في مكانه', () {
      final result = _type(phone, '07701', '077901', cursorBefore: 3, cursorAfter: 4);
      expect(result.text, '077901');
      expect(result.selection.baseOffset, 4);
    });
  });

  group('العدد', () {
    const number = MaxDigitsFormatter(2);

    test('الأرقام فقط وبالحد الأقصى', () {
      expect(_type(number, '', 'abc').text, isEmpty);
      expect(_type(number, '', '2a8').text, '28');
      expect(_type(number, '', '٢٨').text, '28');
      expect(_type(number, '', '123').text, '12');
    });
  });
}
