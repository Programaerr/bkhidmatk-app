import 'dart:isolate';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// روابط الفيديوهات المستخرجة في هذه الجلسة: الرجوع إلى فيديو لا يستخرجه من جديد.
// رابط يوتيوب ينتهي بعد ساعات، فيُستخرج مرة ثانية بعد ساعتين.
const _keep = Duration(hours: 2);
final _resolved = <String, (DateTime, Future<String>)>{};

/// رابط ملف فيديو (صورة وصوت معاً) لفيديو يوتيوب، بأعلى جودة يوفّرها يوتيوب في ملف واحد.
///
/// الاستخراج يقرأ صفحة يوتيوب ويحللها، وهذا ثقيل، فيعمل في خيط منفصل حتى لا تتوقف الشاشة.
Future<String> resolveYoutubeStream(String videoId) {
  final cached = _resolved[videoId];
  if (cached != null && DateTime.now().difference(cached.$1) < _keep) {
    return cached.$2;
  }
  final stream = _resolveInBackground(videoId);
  _resolved[videoId] = (DateTime.now(), stream);
  // الفشل لا يُحفظ، فالمحاولة التالية تستخرج من جديد.
  stream.then<void>((_) {}, onError: (Object _) {
    if (identical(_resolved[videoId]?.$2, stream)) _resolved.remove(videoId);
  });
  return stream;
}

// في دالة وحدها، حتى لا يحمل الخيط الجديد معه شيئاً غير رقم الفيديو.
Future<String> _resolveInBackground(String videoId) =>
    Isolate.run(() => _resolve(videoId));

Future<String> _resolve(String videoId) async {
  final youtube = YoutubeExplode();
  try {
    final manifest = await youtube.videos.streams.getManifest(videoId);
    return manifest.muxed.withHighestBitrate().url.toString();
  } finally {
    youtube.close();
  }
}
