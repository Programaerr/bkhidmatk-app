import 'package:flutter_test/flutter_test.dart';

import 'package:jaik/data/models.dart';
import 'package:jaik/data/sections.dart';

const _requested = [
  'سبالت', 'كهرباء', 'سباكة', 'صباغ', 'التنظيف', 'اجهزة المنزل', 'مجاري', 'نجار', 'حداد',
  'ديكورات', 'تركيب كامرات', 'حدائق', 'طاقة شمسية', 'عامل', 'ابواب و شبابيك', 'نقل الاثاث',
  'شد و تركيب الاثاث', 'غسيل سيارات',
];

Category _row(int id, String name) =>
    Category(id: id, name: name, icon: 'build', color: 0xFF000000, sortOrder: 50 - id);

// ما في السيرفر اليوم: الأقسام الثمانية القديمة بترتيبها المعكوس.
final _server = [
  _row(8, 'نجارة'),
  _row(7, 'تنظيف'),
  _row(6, 'تكييف'),
  _row(5, 'سباكة'),
  _row(4, 'ديكورات'),
  _row(3, 'صباغة'),
  _row(2, 'تصليح غسالات'),
  _row(1, 'كهرباء'),
];

int? _idOf(List<Category> sections, String name) =>
    sections.firstWhere((section) => section.name == name).id;

void main() {
  test('الأقسام الثمانية القديمة تظهر ثمانية عشر قسماً بالترتيب المطلوب', () {
    final sections = customerSections(_server);
    expect(sections.map((section) => section.name), _requested);
  });

  test('بلا أي قسم محفوظ تظهر كلها أيضاً', () {
    expect(customerSections(const []).map((section) => section.name), _requested);
  });

  test('القسم القديم يبقى برقمه تحت اسمه الجديد، فتظهر خدماته', () {
    final sections = customerSections(_server);
    expect(_idOf(sections, 'سبالت'), 6);
    expect(_idOf(sections, 'صباغ'), 3);
    expect(_idOf(sections, 'التنظيف'), 7);
    expect(_idOf(sections, 'اجهزة المنزل'), 2);
    expect(_idOf(sections, 'نجار'), 8);
    expect(_idOf(sections, 'كهرباء'), 1);
  });

  test('القسم غير المحفوظ له رقم سالب خاص به، فلا يفتح كل الخدمات', () {
    final missing = customerSections(_server).where((section) => section.id! < 0).toList();
    expect(missing, hasLength(10));
    expect(missing.map((section) => section.id).toSet(), hasLength(10));
    expect(missing.map((section) => section.name), contains('حداد'));
  });

  test('بعد تشغيل ملف السيرفر تُستخدم أرقام الأقسام الجديدة نفسها', () {
    final stored = [for (final (i, name) in _requested.indexed) _row(i + 100, name)];
    final sections = customerSections(stored);
    expect(sections.map((section) => section.id), [for (var i = 0; i < 18; i++) i + 100]);
    expect(sections, hasLength(18));
  });

  test('ما أضافه المدير يبقى بعد الأقسام كلها', () {
    final sections = customerSections([..._server, _row(30, 'قسم المدير')]);
    expect(sections, hasLength(19));
    expect(sections.last.name, 'قسم المدير');
    expect(sections.last.id, 30);
  });

  test('إذا وُجد الاسمان القديم والجديد يأخذ القسم الجديد مكانه، ولا يضيع القديم', () {
    final sections = customerSections([_row(6, 'تكييف'), _row(40, 'سبالت')]);
    expect(_idOf(sections, 'سبالت'), 40);
    expect(sections.last.name, 'تكييف');
    expect(sections.last.id, 6);
  });

  test('اسم القسم القديم على الخدمة يظهر بالاسم الجديد', () {
    expect(currentSectionName('تكييف'), 'سبالت');
    expect(currentSectionName('كهرباء'), 'كهرباء');
    expect(currentSectionName(null), isNull);
  });
}
