/// في المتصفح لا يمكن استخراج ملف الفيديو من يوتيوب.
Future<String> resolveYoutubeStream(String videoId) => Future.error(
      UnsupportedError('تشغيل يوتيوب داخل التطبيق غير متاح في المتصفح'),
    );
