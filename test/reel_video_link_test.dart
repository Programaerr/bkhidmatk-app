import 'package:flutter_test/flutter_test.dart';
import 'package:jaik/core/reel_video_link.dart';

void main() {
  group('ReelVideoLink', () {
    test('recognizes direct video and HLS URLs with query parameters', () {
      expect(
        ReelVideoLink.isDirectVideo(
          Uri.parse('https://cdn.example/video.MP4?token=sample'),
        ),
        isTrue,
      );
      expect(
        ReelVideoLink.isDirectVideo(
          Uri.parse('https://cdn.example/live.m3u8?token=sample'),
        ),
        isTrue,
      );
      expect(
        ReelVideoLink.isDirectVideo(
          Uri.parse('https://youtube.com/watch?v=video123'),
        ),
        isFalse,
      );
    });

    test('converts YouTube and short links to supported player URLs', () {
      expect(
        ReelVideoLink.playbackUri(
          'https://www.youtube.com/shorts/video_123',
        )?.toString(),
        contains('youtube-nocookie.com/embed/video_123'),
      );
      expect(
        ReelVideoLink.playbackUri('https://youtu.be/video_123')?.host,
        'www.youtube-nocookie.com',
      );
    });

    test('converts social video permalinks to their embed players', () {
      expect(
        ReelVideoLink.playbackUri(
          'https://www.tiktok.com/@creator/video/123456789',
        )?.path,
        '/player/v1/123456789',
      );
      expect(
        ReelVideoLink.playbackUri(
          'https://www.instagram.com/reel/Abc_123/',
        )?.path,
        '/reel/Abc_123/embed',
      );
      expect(
        ReelVideoLink.playbackUri(
          'https://vimeo.com/123456789',
        )?.host,
        'player.vimeo.com',
      );
      expect(
        ReelVideoLink.playbackUri(
          'https://www.facebook.com/watch/?v=123456789',
        )?.path,
        '/plugins/video.php',
      );
    });

    test('keeps other public HTTPS links for in-app fallback', () {
      final source = 'https://example.com/videos/something';
      expect(ReelVideoLink.playbackUri(source).toString(), source);
      expect(ReelVideoLink.playbackUri('javascript:alert(1)'), isNull);
    });
  });
}
