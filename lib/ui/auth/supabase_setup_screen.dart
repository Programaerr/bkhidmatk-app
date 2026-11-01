import 'package:flutter/material.dart';

class SupabaseSetupApp extends StatelessWidget {
  const SupabaseSetupApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        home: const _SupabaseSetupScreen(),
      );
}

class _SupabaseSetupScreen extends StatelessWidget {
  const _SupabaseSetupScreen();

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 52),
                    const SizedBox(height: 20),
                    Text(
                      'إعداد Supabase مطلوب لتشغيل التطبيق في المتصفح',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'لم يتم تمرير عنوان المشروع والمفتاح العام. المتصفح لا يستخدم قاعدة SQLite المحلية، لذلك أوقفنا التشغيل هنا بدلاً من ترك تسجيل الدخول يتعطل.',
                      style: TextStyle(height: 1.7),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'شغّل التطبيق من مجلد المشروع بعد استبدال القيم ببيانات Supabase:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    const SelectableText(
                      'flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY',
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'تجد Project URL وPublishable key في إعدادات مشروع Supabase. لا تستخدم service_role في التطبيق.',
                      style: TextStyle(height: 1.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
