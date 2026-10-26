import '../core/utils.dart';

/// إعدادات الاتصال بقاعدة البيانات المشتركة على Supabase.
///
/// تُمرَّر القيم وقت البناء (بدون كتابتها داخل الكود) عبر:
///
/// ```
/// flutter build apk --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///                   --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
///
/// وإذا كانت فارغة يعمل التطبيق بالوضع المحلي التجريبي (SQLite) على الجهاز فقط.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      url.startsWith('https://') && anonKey.length > 40;

  /// بريد صناعي مبني على رقم الهاتف حتى نستخدم مصادقة Supabase
  /// دون إرسال رسائل SMS (لا تكلفة ولا إعدادات إضافية).
  static String emailForPhone(String phone) =>
      '${normalizePhone(phone)}@bkhidmatk.app';
}
