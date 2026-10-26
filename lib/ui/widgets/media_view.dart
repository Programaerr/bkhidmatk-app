import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';

bool isAssetMedia(String? path) => path != null && path.startsWith('asset:');

String _stripAsset(String path) => path.replaceFirst('asset:', '');

class MediaThumb extends StatelessWidget {
  const MediaThumb({
    super.key,
    required this.path,
    required this.type,
    this.height = 190,
    this.radius = AppRadius.md,
    this.onTap,
    this.showBadge = true,
  });

  final String? path;
  final String type; // image | video | none
  final double height;
  final double radius;
  final VoidCallback? onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content;

    if (type == 'image' && path != null && path!.isNotEmpty) {
      content = isAssetMedia(path)
          ? Image.asset(_stripAsset(path!), fit: BoxFit.cover, width: double.infinity, height: height,
              errorBuilder: (_, __, ___) => _fallback(theme))
          : Image.file(File(path!), fit: BoxFit.cover, width: double.infinity, height: height,
              errorBuilder: (_, __, ___) => _fallback(theme));
    } else if (type == 'video' && path != null && path!.isNotEmpty) {
      content = Container(
        height: height,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1B1B20), Color(0xFF3A3208)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: -20,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: .08),
                ),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 18, offset: const Offset(0, 6)),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded, color: AppColors.ink, size: 34),
            ),
            if (showBadge)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.white.withValues(alpha: .15)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('فيديو',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      content = _fallback(theme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: GestureDetector(onTap: onTap, child: SizedBox(height: height, width: double.infinity, child: content)),
    );
  }

  Widget _fallback(ThemeData theme) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF0A8), Color(0xFFFFD400)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.handyman_rounded, size: 34, color: AppColors.ink.withValues(alpha: .55)),
          const SizedBox(height: 6),
          Text('بخدمتك',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.ink.withValues(alpha: .55),
              )),
        ],
      ),
    );
  }
}

/// Full video player used on the post details screen.
class InlineVideoPlayer extends StatefulWidget {
  const InlineVideoPlayer({super.key, required this.path, this.height = 230});

  final String path;
  final double height;

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = isAssetMedia(widget.path)
          ? VideoPlayerController.asset(_stripAsset(widget.path))
          : VideoPlayerController.file(File(widget.path));
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || (_controller == null && _ready)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: widget.height,
          color: AppColors.ink,
          alignment: Alignment.center,
          child: const Text('تعذر تشغيل الفيديو على هذا الجهاز',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      );
    }
    if (_controller == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: widget.height,
          color: AppColors.ink,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.gold),
          ),
        ),
      );
    }
    final c = _controller!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: widget.height,
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
            GestureDetector(
              onTap: _toggle,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: c.value.isPlaying ? 0 : 1,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                  child: Icon(
                    c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.ink,
                    size: 32,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 6,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: AppColors.gold,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
