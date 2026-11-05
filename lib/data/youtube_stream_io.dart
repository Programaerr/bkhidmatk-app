import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// رابط ملف فيديو (صورة وصوت معاً) لفيديو يوتيوب، بأعلى جودة يوفّرها يوتيوب في ملف واحد.
Future<String> resolveYoutubeStream(String videoId) async {
  final youtube = YoutubeExplode();
  try {
    final manifest = await youtube.videos.streams.getManifest(videoId);
    return manifest.muxed.withHighestBitrate().url.toString();
  } finally {
    youtube.close();
  }
}
