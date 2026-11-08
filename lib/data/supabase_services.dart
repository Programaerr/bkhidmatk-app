import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/language.dart';
import '../core/utils.dart';
import 'models.dart';

/// خطأ مصادقة برسالة عربية جاهزة للعرض للمستخدم.
class CloudAuthException implements Exception {
  const CloudAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.sentAt,
    this.readAt,
    this.recipientPhone,
  });

  final int id;
  final String title;
  final String body;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? recipientPhone;

  bool get isRead => readAt != null;

  factory AppNotification.fromMap(Map<String, dynamic> row) => AppNotification(
        id: row['id'] as int,
        title: row['title'] as String,
        body: row['body'] as String,
        sentAt: DateTime.parse(row['sent_at'] as String).toLocal(),
        readAt: row['read_at'] == null
            ? null
            : DateTime.parse(row['read_at'] as String).toLocal(),
        recipientPhone: row['recipient_phone'] as String?,
      );
}

class SupabaseServices {
  SupabaseServices._(this.client);

  final SupabaseClient client;

  static const _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://scapsbhbpsxxjrafdcni.supabase.co',
  );
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_4naOj0PFIQNyAEqz10b-dA_mXvwP9_j',
    ),
  );

  static bool get isConfigured => _url.isNotEmpty && _publishableKey.isNotEmpty;

  static Future<SupabaseServices?> initializeIfConfigured() async {
    if (!isConfigured) {
      if (_url.isEmpty && _publishableKey.isEmpty) return null;
      throw StateError(
        'Supabase configuration is incomplete. Run with --dart-define=SUPABASE_URL=... '
        'and --dart-define=SUPABASE_PUBLISHABLE_KEY=... .',
      );
    }
    // التطبيق لا يستقبل روابط دخول (لا روابط له في AndroidManifest)، فلا ينتظر فحصها عند الفتح.
    await Supabase.initialize(
      url: _url,
      publishableKey: _publishableKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    return SupabaseServices._(Supabase.instance.client);
  }

  bool get isSignedIn => client.auth.currentUser != null;

  static String phoneE164(String phone) {
    final normalized = normalizePhone(phone);
    if (!validIraqiPhone(normalized)) {
      throw FormatException(tr('أدخل رقم هاتف عراقي صحيح يبدأ بـ 07', 'Enter a valid Iraqi phone number starting with 07'));
    }
    return '+964${normalized.substring(1)}';
  }

  /// بريد داخلي مشتق من رقم الهاتف حتى يعمل الدخول بكلمة المرور
  /// دون أي مزوّد SMS أو رمز OTP. المستخدم لا يرى هذا البريد أبداً.
  static String emailForPhone(String phone) {
    final normalized = normalizePhone(phone);
    if (!validIraqiPhone(normalized)) {
      throw FormatException(tr('أدخل رقم هاتف عراقي صحيح يبدأ بـ 07', 'Enter a valid Iraqi phone number starting with 07'));
    }
    return '$normalized@jaik.app';
  }

  /// دخول مباشر برقم الهاتف وكلمة المرور — بدون رمز SMS/OTP.
  Future<AppUser> signInWithPassword(String phone, String password) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: emailForPhone(phone),
        password: password,
      );
      if (response.session == null) {
        throw CloudAuthException(
          tr('تعذر إنشاء جلسة الدخول. تحقق من إعدادات Supabase.', "Couldn't start the sign-in session. Check the Supabase settings."),
        );
      }
      return await currentProfile();
    } catch (error) {
      throw _friendly(error);
    }
  }

  /// إنشاء حساب مباشر برقم الهاتف وكلمة المرور — بدون رمز SMS/OTP.
  Future<AppUser> signUpWithPassword({
    required String phone,
    required String password,
    String? name,
    String? city,
    String? address,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: emailForPhone(phone),
        password: password,
        data: {
          'app_phone': normalizePhone(phone),
          if (name != null) 'name': name.trim(),
          if (city != null) 'city': city,
          if (address != null) 'address': address.trim(),
        },
      );
      if (response.session == null) {
        throw CloudAuthException(
          tr('الحساب أُنشئ لكنه ينتظر تأكيد البريد الداخلي. في Supabase افتح '
          'Authentication ← Sign In / Providers ← Email وأوقف '
          '«Confirm email»، ثم سجّل الدخول.', 'The account was created but is waiting for internal email confirmation. In Supabase open Authentication → Sign In / Providers → Email and turn off "Confirm email", then sign in.'),
        );
      }
      return await currentProfile();
    } catch (error) {
      throw _friendly(error);
    }
  }

  Object _friendly(Object error) {
    if (error is CloudAuthException) return error;
    final raw = error is AuthException ? error.message : error.toString();
    final text = raw.toLowerCase();
    String? arabic;
    if (text.contains('invalid login credentials') ||
        text.contains('invalid credentials')) {
      arabic = tr('رقم الهاتف أو كلمة المرور غير صحيحة', 'Incorrect phone number or password');
    } else if (text.contains('already registered') ||
        text.contains('already exists') ||
        text.contains('user already')) {
      arabic = tr('هذا الرقم مسجل مسبقاً — استخدم «تسجيل الدخول»', 'This number is already registered. Use "Log in".');
    } else if (text.contains('password') &&
        (text.contains('6') || text.contains('short'))) {
      arabic = tr('كلمة المرور 6 أحرف على الأقل', 'The password must be at least 6 characters');
    } else if (text.contains('email not confirmed') ||
        text.contains('confirmation') ||
        text.contains('confirm')) {
      arabic = tr('الحساب ينتظر تأكيد البريد الداخلي. في Supabase افتح '
          'Authentication ← Sign In / Providers ← Email وأوقف '
          '«Confirm email»، ثم أعد المحاولة.', 'The account is waiting for internal email confirmation. In Supabase open Authentication → Sign In / Providers → Email and turn off "Confirm email", then try again.');
    } else if (text.contains('email provider') ||
        text.contains('email signups are disabled')) {
      arabic = tr('فعّل مزوّد Email في Supabase ← Authentication ← '
          'Sign In / Providers.', 'Enable the Email provider in Supabase → Authentication → Sign In / Providers.');
    } else if (text.contains('database error') ||
        text.contains('saving new user')) {
      arabic = tr('تعذر إنشاء ملف الحساب. تأكد من تنفيذ supabase/setup.sql كاملاً '
          'ومن وجود trigger «on_auth_user_created_jaik».', 'Could not create the account profile. Make sure supabase/setup.sql ran completely and the trigger "on_auth_user_created_jaik" exists.');
    } else if (text.contains('rate limit') || text.contains('too many')) {
      arabic = tr('محاولات كثيرة. انتظر دقيقة ثم أعد المحاولة.', 'Too many attempts. Wait a minute and try again.');
    }
    return arabic == null
        ? CloudAuthException(raw)
        : CloudAuthException(arabic);
  }

  Future<AppUser> currentProfile() async {
    final authUser = client.auth.currentUser;
    if (authUser == null) throw StateError(tr('لا توجد جلسة دخول فعالة', 'No active sign-in session'));
    final row = await client
        .from('app_profiles')
        .select()
        .eq('auth_user_id', authUser.id)
        .maybeSingle();
    if (row == null) {
      throw StateError(
        tr('تعذر العثور على ملف الحساب. تحقق من تشغيل ملف setup.sql في Supabase.', 'Could not find the account profile. Check that setup.sql ran in Supabase.'),
      );
    }
    return AppUser(
      id: row['id'] as int,
      name: row['name'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      passwordHash: '',
      role: row['role'] as String? ?? 'customer',
      city: row['city'] as String?,
      address: row['address'] as String?,
      avatarPath: row['avatar'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  Future<void> updateProfile(AppUser user) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) throw StateError(tr('لا توجد جلسة دخول فعالة', 'No active sign-in session'));
    await client.from('app_profiles').update({
      'name': user.name,
      'city': user.city,
      'address': user.address,
      'avatar': user.avatarPath,
    }).eq('auth_user_id', authUser.id);
  }

  Future<void> signOut() => client.auth.signOut();

  Future<List<AppNotification>> notifications() async {
    // ما أرسله هو (إشعارات الحجز التي تنشئها قاعدة البيانات باسمه) ليس له، بل لمن أُرسل إليه.
    final rows = await client
        .from('app_notifications')
        .select('id,title,body,sent_at,read_at,app_profiles!inner(auth_user_id)')
        .eq('app_profiles.auth_user_id', client.auth.currentUser!.id)
        .order('sent_at', ascending: false)
        .limit(100);
    return rows.map((row) => AppNotification.fromMap(row)).toList();
  }

  RealtimeChannel subscribeToNotifications(void Function() onChange) => client
      .channel('app-notifications-${client.auth.currentUser!.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'app_notifications',
        callback: (_) => onChange(),
      )
      .subscribe();

  Future<List<AppNotification>> recentSentNotifications() async {
    final rows = await client
        .from('app_notifications')
        .select('id,title,body,sent_at,read_at,app_profiles!inner(phone)')
        .eq('sender_auth_id', client.auth.currentUser!.id)
        .order('sent_at', ascending: false)
        .limit(100);
    return rows.map((row) {
      final profile = row['app_profiles'] as Map<String, dynamic>;
      return AppNotification.fromMap({
        ...row,
        'recipient_phone': profile['phone'],
      });
    }).toList();
  }

  Future<int> sendNotification({
    required String audience,
    String? phone,
    required String title,
    required String body,
  }) async {
    final result = await client.rpc('send_app_notification', params: {
      'p_audience': audience,
      'p_phone':
          phone == null || phone.trim().isEmpty ? null : normalizePhone(phone),
      'p_title': title.trim(),
      'p_body': body.trim(),
    });
    return (result as num).toInt();
  }

  Future<void> markNotificationRead(int id) async {
    await client.from('app_notifications').update(
        {'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> addHirePhone(String phone, {String? note}) async {
    await client.from('hire_phones').upsert(
      {
        'phone': normalizePhone(phone),
        'note': note,
      },
      onConflict: 'phone',
    );
  }

  Future<void> deleteHirePhone(String phone) async {
    await client
        .from('hire_phones')
        .delete()
        .eq('phone', normalizePhone(phone));
  }

  Future<List<Hire>> listHirePhones() async {
    final hires = await client
        .from('hire_phones')
        .select('id,phone,note,created_at')
        .order('created_at', ascending: false);
    final profiles = await client.from('app_profiles').select('phone,name');
    final registeredByPhone = {
      for (final profile in profiles)
        profile['phone'] as String: profile['name'] as String? ?? '',
    };
    return hires.map((row) {
      final phone = row['phone'] as String;
      return Hire(
        id: row['id'] as int,
        phone: phone,
        note: row['note'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        userName: registeredByPhone[phone],
        registered: registeredByPhone.containsKey(phone),
      );
    }).toList();
  }
}
