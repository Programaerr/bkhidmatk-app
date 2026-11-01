import 'dart:io';

import 'package:flutter/services.dart';

const _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

String fmtMoney(num value) {
  final n = value.round();
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$buf د.ع';
}

String fmtNumber(num value) {
  final s = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String fmtDateShort(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String fmtWeekday(DateTime d) => _weekdays[d.weekday - 1];

String fmtTimeOfDay(DateTime d) {
  final h24 = d.hour;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${h24 < 12 ? 'ص' : 'م'}';
}

String fmtDateTime(DateTime d) => '${fmtDate(d)} • ${fmtTimeOfDay(d)}';

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
  if (diff.inDays == 1) return 'أمس';
  if (diff.inDays < 30) return 'قبل ${diff.inDays} يوم';
  return fmtDate(d);
}

String fmtDuration(int minutes) {
  if (minutes < 60) return '$minutes دقيقة';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h ساعة' : '$h ساعة و$m دقيقة';
}

/// Renders a time string stored as "HH:mm" (24h) into 12h Arabic style.
String fmtSlot(String slot) {
  final parts = slot.split(':');
  if (parts.length != 2) return slot;
  final h24 = int.tryParse(parts[0]) ?? 0;
  final m = parts[1];
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h:$m ${h24 < 12 ? 'ص' : 'م'}';
}

String invoiceNumber(int id, DateTime date) =>
    'BKD-${date.year}-${id.toString().padLeft(5, '0')}';

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '؟';
  final first = parts.first.substring(0, 1);
  if (parts.length == 1) return first;
  return '$first${parts[1].substring(0, 1)}';
}

bool fileExists(String? path) {
  if (path == null || path.isEmpty) return false;
  return File(path).existsSync();
}

String? safeFileName(String path) {
  try {
    return path.split(Platform.pathSeparator).last;
  } catch (_) {
    return null;
  }
}

/// Luhn check for card numbers (test mode validation only).
bool luhnValid(String digits) {
  final clean = digits.replaceAll(RegExp(r'\D'), '');
  if (clean.length < 13 || clean.length > 19) return false;
  var sum = 0;
  var double_ = false;
  for (var i = clean.length - 1; i >= 0; i--) {
    var d = int.parse(clean[i]);
    if (double_) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    double_ = !double_;
  }
  return sum % 10 == 0;
}

String cardBrand(String digits) {
  final clean = digits.replaceAll(RegExp(r'\D'), '');
  if (clean.startsWith('4')) return 'Visa';
  if (clean.startsWith('5') || clean.startsWith('2')) return 'Mastercard';
  if (clean.startsWith('3')) return 'Amex';
  if (clean.startsWith('6')) return 'Discover';
  return 'Card';
}

String maskCard(String last4) => '•••• •••• •••• $last4';

String normalizePhone(String phone) {
  var p = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (p.startsWith('+964')) p = '0${p.substring(4)}';
  if (p.startsWith('964')) p = '0${p.substring(3)}';
  return p;
}

bool validIraqiPhone(String phone) {
  final p = normalizePhone(phone);
  return RegExp(r'^07\d{9}$').hasMatch(p);
}

const _easternDigits = '٠١٢٣٤٥٦٧٨٩';
const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

/// لوحات المفاتيح العربية قد تكتب أرقاماً شرقية، فتُحوَّل قبل الفحص والحفظ.
String westernDigits(String value) {
  final buffer = StringBuffer();
  for (final char in value.split('')) {
    final eastern = _easternDigits.indexOf(char);
    final persian = _persianDigits.indexOf(char);
    if (eastern >= 0) {
      buffer.write(eastern);
    } else if (persian >= 0) {
      buffer.write(persian);
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString().trim();
}

/// الرقم كما يُحفظ مهما كُتب: بأرقام غربية وبالصفر في أوله،
/// فقد يُكتب في الاستمارة بدون الصفر.
String phoneFromInput(String value) {
  final phone = normalizePhone(westernDigits(value));
  return phone.startsWith('7') ? '0$phone' : phone;
}

/// خانة أرقام: تحوّل الأرقام العربية وترفض الأحرف وكل ما سواها.
abstract class _NumberFormatter extends TextInputFormatter {
  const _NumberFormatter();

  String _limited(String digits);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits =
        _limited(westernDigits(newValue.text).replaceAll(RegExp(r'[^0-9]'), ''));
    if (digits == newValue.text) return newValue;
    // ما رُفض كله لا يغيّر الخانة ولا يحرّك المؤشر.
    if (digits == oldValue.text) return oldValue;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

/// عدد بحد أقصى من الأرقام، مثل العمر وسنوات الخبرة.
class MaxDigitsFormatter extends _NumberFormatter {
  const MaxDigitsFormatter(this.maxDigits);

  final int maxDigits;

  @override
  String _limited(String digits) =>
      digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;
}

/// رقم موبايل عراقي: تُحذف منه +964 عند اللصق، وطوله 11 رقماً بالصفر و10 بدونه.
class IraqiPhoneFormatter extends _NumberFormatter {
  const IraqiPhoneFormatter();

  @override
  String _limited(String digits) {
    final local = digits.startsWith('964') ? digits.substring(3) : digits;
    final limit = local.startsWith('0') ? 11 : 10;
    return local.length > limit ? local.substring(0, limit) : local;
  }
}

String phoneForCall(String phone) => normalizePhone(phone);

const iraqCities = [
  'بغداد',
  'البصرة',
  'الموصل',
  'أربيل',
  'النجف',
  'كربلاء',
  'السليمانية',
  'كركوك',
  'الديوانية',
  'الحلة',
  'الناصرية',
  'ديالى',
  'الرمادي',
  'العمارة',
  'السماوة',
  'دهوك',
];
