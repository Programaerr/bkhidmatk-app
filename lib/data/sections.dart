import 'models.dart';

/// أقسام الخدمات بترتيب عرضها: الاسم، والأيقونة، واللون.
const appSections = <(String, String, int)>[
  ('سبالت', 'ac_unit', 0xFF3F51B5),
  ('كهرباء', 'electrical_services', 0xFFFFC107),
  ('سباكة', 'plumbing', 0xFF00BCD4),
  ('صباغ', 'format_paint', 0xFF8BC34A),
  ('التنظيف', 'cleaning_services', 0xFF9C27B0),
  ('اجهزة المنزل', 'kitchen', 0xFF03A9F4),
  ('مجاري', 'water_damage', 0xFF607D8B),
  ('نجار', 'carpenter', 0xFF795548),
  ('حداد', 'hardware', 0xFF546E7A),
  ('ديكورات', 'chair_alt', 0xFFE91E63),
  ('تركيب كامرات', 'videocam', 0xFF673AB7),
  ('حدائق', 'yard', 0xFF4CAF50),
  ('طاقة شمسية', 'solar_power', 0xFFFF9800),
  ('عامل', 'engineering', 0xFF9E9D24),
  ('ابواب و شبابيك', 'window', 0xFF009688),
  ('نقل الاثاث', 'local_shipping', 0xFFFF5722),
  ('شد و تركيب الاثاث', 'handyman', 0xFFA1887F),
  ('غسيل سيارات', 'local_car_wash', 0xFF2196F3),
];

/// الأقسام القديمة تأخذ اسمها الجديد، فتبقى خدماتها وحرفيوها معها.
const renamedSections = {
  'تكييف': 'سبالت',
  'صباغة': 'صباغ',
  'تنظيف': 'التنظيف',
  'تصليح غسالات': 'اجهزة المنزل',
  'نجارة': 'نجار',
};

/// اسم القسم كما يراه الزبون، ولو بقي اسمه القديم في السيرفر.
String? currentSectionName(String? name) => renamedSections[name] ?? name;

/// الأقسام كما يراها الزبون: كلها بأسمائها وترتيبها، وبعدها ما أضافه المدير.
///
/// القسم المحفوظ يبقى برقمه فتظهر خدماته، ولو بقي باسمه القديم. وما لم يُحفظ بعد
/// يأخذ رقماً سالباً، فتفتح صفحته فارغة من الخدمات.
List<Category> customerSections(List<Category> stored) {
  final byName = {for (final section in stored) section.name: section};
  final oldNames = {for (final MapEntry(:key, :value) in renamedSections.entries) value: key};
  final matched = <Category>{};
  final sections = <Category>[];
  for (final (index, (name, icon, color)) in appSections.indexed) {
    final row = byName[name] ?? byName[oldNames[name]];
    if (row != null) matched.add(row);
    sections.add(Category(
      id: row?.id ?? -(index + 1),
      name: name,
      icon: icon,
      color: row?.color ?? color,
      sortOrder: index,
    ));
  }
  return [
    ...sections,
    for (final section in stored)
      if (!matched.contains(section)) section,
  ];
}
