/// مسار وسائط من أصول التطبيق (يبدأ بـ asset:).
bool isAssetMedia(String? path) => path != null && path.startsWith('asset:');

/// مسار وسائط على الإنترنت.
bool isNetworkMedia(String? path) =>
    path != null && (path.startsWith('http://') || path.startsWith('https://'));

final _youtubeId = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// رقم فيديو يوتيوب من رابطه (عادي، قصير youtu.be، Shorts، بث مباشر، مضمَّن)، أو null إن لم يكن رابط يوتيوب.
String? youtubeIdOf(String? url) {
  final uri = Uri.tryParse((url ?? '').trim());
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www|m|music)\.'), '');
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  String? id;
  if (host == 'youtu.be') {
    id = segments.isEmpty ? null : segments.first;
  } else if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
    if (segments.isNotEmpty && segments.first == 'watch') {
      id = uri.queryParameters['v'];
    } else if (segments.length >= 2 &&
        const {'embed', 'shorts', 'live', 'v'}.contains(segments.first)) {
      id = segments[1];
    }
  }
  return id != null && _youtubeId.hasMatch(id) ? id : null;
}
