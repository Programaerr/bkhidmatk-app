import '../core/language.dart';

/// في المتصفح لا يمكن استخراج ملف الفيديو من يوتيوب.
Future<String> resolveYoutubeStream(String videoId) => Future.error(
      UnsupportedError(tr('تشغيل يوتيوب داخل التطبيق غير متاح في المتصفح', 'Playing YouTube inside the app is not available in the browser')),
    );
