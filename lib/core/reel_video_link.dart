class ReelVideoLink {
  const ReelVideoLink._();

  static bool isDirectVideo(Uri uri) {
    final path = uri.path.toLowerCase();
    return const ['.mp4', '.m3u8', '.webm', '.mov'].any(path.endsWith);
  }

  static Uri? playbackUri(String value) {
    final source = Uri.tryParse(value.trim());
    if (source == null ||
        (source.scheme != 'https' && source.scheme != 'http') ||
        source.host.isEmpty) {
      return null;
    }

    final host = source.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final segments = source.pathSegments;

    if (host == 'youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com')) {
      final id = host == 'youtu.be'
          ? (segments.isEmpty ? null : segments.first)
          : source.queryParameters['v'] ??
              _segmentAfter(segments, const ['shorts', 'embed', 'live']);
      if (id != null && _validId(id)) {
        return Uri.https('www.youtube-nocookie.com', '/embed/$id', {
          'autoplay': '1',
          'mute': '1',
          'playsinline': '1',
          'controls': '1',
          'loop': '1',
          'playlist': id,
          'enablejsapi': '1',
        });
      }
    }

    if (host == 'tiktok.com' || host.endsWith('.tiktok.com')) {
      final id = _segmentAfter(segments, const ['video', 'embed', 'v1']);
      if (id != null && RegExp(r'^\d+$').hasMatch(id)) {
        return Uri.https('www.tiktok.com', '/player/v1/$id', {
          'autoplay': '1',
          'loop': '1',
          'controls': '1',
          'description': '0',
          'music_info': '0',
        });
      }
    }

    if (host == 'vimeo.com' || host.endsWith('.vimeo.com')) {
      final id = _segmentAfter(segments, const ['video']) ??
          (segments.isNotEmpty ? segments.first : null);
      if (id != null && RegExp(r'^\d+$').hasMatch(id)) {
        return Uri.https('player.vimeo.com', '/video/$id', {
          'autoplay': '1',
          'muted': '1',
          'loop': '1',
          'playsinline': '1',
        });
      }
    }

    if (host == 'instagram.com' || host.endsWith('.instagram.com')) {
      final type = const ['reel', 'reels', 'p'].firstWhere(
        segments.contains,
        orElse: () => '',
      );
      final id = _segmentAfter(segments, [type]);
      if (type.isNotEmpty && id != null) {
        return Uri.https('www.instagram.com', '/$type/$id/embed');
      }
    }

    if (host == 'facebook.com' || host.endsWith('.facebook.com')) {
      final isVideo = source.queryParameters.containsKey('v') ||
          segments.contains('videos') ||
          segments.contains('reel');
      if (isVideo) {
        return Uri.https('www.facebook.com', '/plugins/video.php', {
          'href': source.toString(),
          'show_text': 'false',
          'autoplay': 'true',
        });
      }
    }

    if (host == 'dai.ly' || host == 'dailymotion.com') {
      final rawId = host == 'dai.ly'
          ? (segments.isEmpty ? null : segments.first)
          : _segmentAfter(segments, const ['video']);
      final id = rawId?.replaceFirst(RegExp(r'\.html$'), '');
      if (id != null && _validId(id)) {
        return Uri.https('www.dailymotion.com', '/embed/video/$id', {
          'autoplay': '1',
          'mute': '1',
          'queue-enable': 'false',
        });
      }
    }

    if (host == 'streamable.com') {
      final id = segments.isEmpty ? null : segments.first;
      if (id != null && _validId(id)) {
        return Uri.https('streamable.com', '/e/$id');
      }
    }

    return source;
  }

  static String? _segmentAfter(List<String> segments, List<String> markers) {
    for (final marker in markers) {
      final index = segments.indexOf(marker);
      if (index >= 0 && index + 1 < segments.length) {
        return segments[index + 1];
      }
    }
    return null;
  }

  static bool _validId(String value) =>
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
}
