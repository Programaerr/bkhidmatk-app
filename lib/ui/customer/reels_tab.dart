import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_all/webview_all.dart';

import '../../core/reel_video_link.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/ui.dart';

/// تثبيت سريع للصفحة بعد سحبة قصيرة، مثل تيك توك.
class _ReelScrollPhysics extends PageScrollPhysics {
  const _ReelScrollPhysics({super.parent});

  @override
  _ReelScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _ReelScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.4,
        stiffness: 260,
        damping: 22,
      );
}

class ReelsTab extends StatefulWidget {
  const ReelsTab({super.key, this.active = true});

  final bool active;

  @override
  State<ReelsTab> createState() => _ReelsTabState();
}

class _ReelsTabState extends State<ReelsTab> with RealtimeRefresh<ReelsTab> {
  late Future<List<OurWork>> _future;
  List<OurWork> _works = const [];
  int _currentPage = 0;
  bool _loaded = false;
  bool _muted = true;
  final Set<int> _viewed = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.active) _enterReelsMode();
  }

  @override
  void didUpdateWidget(covariant ReelsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _enterReelsMode();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recordView(_currentPage);
      });
    } else if (oldWidget.active && !widget.active) {
      _leaveReelsMode();
    }
  }

  @override
  void dispose() {
    _leaveReelsMode();
    super.dispose();
  }

  @override
  void onRealtimeChange() => _load();

  void _load() {
    final state = context.read<AppState>();
    setState(() {
      _loaded = false;
      _future = state.repo.listWorks(
        onlyActive: true,
        viewerId: state.user?.id,
      );
    });
  }

  /// شاشة الريلز عمودية مثل تيك توك، ومشاهدة الفيديو العريض تتم من زر مستقل.
  void _enterReelsMode() {
    _applySystemBars(reels: true);
    if (kIsWeb) return;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]).catchError((error) {
      debugPrint('Failed to lock reels orientation: $error');
    });
  }

  void _leaveReelsMode() {
    _applySystemBars(reels: false);
    if (kIsWeb) return;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]).catchError((error) {
      debugPrint('Failed to restore app orientation: $error');
    });
  }

  void _applySystemBars({required bool reels}) {
    if (kIsWeb) return;
    SystemChrome.setSystemUIOverlayStyle(
      reels
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: Colors.black,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
    );
  }

  Future<void> _toggleLike(int index) async {
    final state = context.read<AppState>();
    final work = _works[index];
    final userId = state.user?.id;
    if (work.id == null || userId == null) {
      AppSnack.show(context, 'سجّل الدخول للإعجاب بهذا الفيديو', error: true);
      return;
    }

    final updated = work.copyWith(
      likedByMe: !work.likedByMe,
      likes: work.likes + (work.likedByMe ? -1 : 1),
    );
    setState(() => _works[index] = updated);
    try {
      await state.repo.setWorkLike(
        work.id!,
        userId: userId,
        liked: updated.likedByMe,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _works[index] = work);
      AppSnack.show(context, 'تعذر تسجيل الإعجاب: $error', error: true);
    }
  }

  Future<void> _openComments(int index) async {
    final work = _works[index];
    if (work.id == null) return;
    final repository = context.read<AppState>().repo;
    final sheetTheme = AppTheme.dark();
    final count = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetTheme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Theme(
        data: sheetTheme,
        child: _ReelCommentsSheet(work: work),
      ),
    );
    if (!mounted) return;
    var actualCount = count;
    if (actualCount == null) {
      try {
        actualCount = (await repository.workComments(work.id!)).length;
      } catch (error) {
        if (!mounted) return;
        AppSnack.show(context, 'تعذر تحديث عدد التعليقات: $error', error: true);
        return;
      }
    }
    setState(() {
      _works[index] = _works[index].copyWith(commentCount: actualCount);
    });
  }

  Future<void> _share(OurWork work) async {
    await Clipboard.setData(ClipboardData(text: work.videoUrl));
    if (mounted) AppSnack.show(context, 'تم نسخ رابط الفيديو');
  }

  void _recordView(int index) {
    if (!widget.active || index < 0 || index >= _works.length) return;
    final work = _works[index];
    final id = work.id;
    if (id == null || !_viewed.add(id)) return;
    setState(() => _works[index] = work.copyWith(views: work.views + 1));
    context.read<AppState>().repo.incrementWorkViews(id).catchError((error) {
      debugPrint('Failed to record reel view: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    final english = context.watch<AppState>().english;
    return ColoredBox(
      color: Colors.black,
      child: FutureBuilder<List<OurWork>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ReelsMessage(
              icon: Icons.error_outline_rounded,
              title: 'تعذر تحميل الأعمال',
              subtitle: 'تحقق من اتصال الإنترنت ثم أعد المحاولة.',
              action: FilledButton(
                onPressed: _load,
                child: const Text('إعادة المحاولة'),
              ),
            );
          }
          if (!_loaded && snapshot.hasData) {
            _works = snapshot.data!;
            _loaded = true;
            if (_currentPage >= _works.length) {
              _currentPage = _works.isEmpty ? 0 : _works.length - 1;
            }
          }
          if (snapshot.connectionState == ConnectionState.waiting && !_loaded) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }
          if (_works.isEmpty) {
            return const _ReelsMessage(
              icon: Icons.video_library_outlined,
              title: 'لا توجد أعمال منشورة حالياً',
              subtitle: 'ستظهر هنا أعمال جايك وفيديوهاتها قريباً.',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  constraints.maxWidth >= 620 ? 560.0 : constraints.maxWidth;
              return Center(
                child: SizedBox(
                  width: width,
                  height: constraints.maxHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        key: const PageStorageKey('customer-reels'),
                        scrollDirection: Axis.vertical,
                        physics: const _ReelScrollPhysics(),
                        allowImplicitScrolling: true,
                        itemCount: _works.length,
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                          _recordView(index);
                        },
                        itemBuilder: (context, index) => _ReelPage(
                          key: ValueKey(_works[index].id ?? index),
                          work: _works[index],
                          active: widget.active && index == _currentPage,
                          nearby: (index - _currentPage).abs() == 1,
                          muted: _muted,
                          english: english,
                          onLike: () => _toggleLike(index),
                          onComments: () => _openComments(index),
                          onShare: () => _share(_works[index]),
                          onMutedChanged: (value) {
                            if (_muted != value) setState(() => _muted = value);
                          },
                        ),
                      ),
                      _ReelsTopBar(
                        muted: _muted,
                        onMutedChanged: (value) {
                          if (_muted != value) setState(() => _muted = value);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReelsTopBar extends StatelessWidget {
  const _ReelsTopBar({required this.muted, required this.onMutedChanged});

  final bool muted;
  final ValueChanged<bool> onMutedChanged;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: 0,
      start: 0,
      end: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.ink,
                  size: 21,
                ),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'جايك',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                    ),
                  ),
                  Text(
                    'معرض الأعمال',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => onMutedChanged(!muted),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: .32),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(
                    muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelsMessage extends StatelessWidget {
  const _ReelsMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 46, color: AppColors.gold),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 14),
                action!,
              ],
            ],
          ),
        ),
      );
}

class _ReelPage extends StatefulWidget {
  const _ReelPage({
    super.key,
    required this.work,
    required this.active,
    required this.nearby,
    required this.muted,
    required this.english,
    required this.onLike,
    required this.onComments,
    required this.onShare,
    required this.onMutedChanged,
  });

  final OurWork work;
  final bool active;
  final bool nearby;
  final bool muted;
  final bool english;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final ValueChanged<bool> onMutedChanged;

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  WebViewController? _web;
  late final AnimationController _heart;
  bool _loading = false;
  bool _failed = false;
  bool _paused = false;
  bool _wasPlayingBeforeLongPress = false;
  int _token = 0;

  bool get _isDirectVideo {
    final uri = Uri.tryParse(widget.work.videoUrl);
    return uri != null && ReelVideoLink.isDirectVideo(uri);
  }

  bool get _shouldPrepare => widget.active || (widget.nearby && _isDirectVideo);

  @override
  void initState() {
    super.initState();
    _heart = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (_shouldPrepare) _prepare();
  }

  @override
  void didUpdateWidget(covariant _ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.work.videoUrl != widget.work.videoUrl) {
      _resetPlayback();
      if (_shouldPrepare) _prepare();
      return;
    }
    if (oldWidget.muted != widget.muted) _applyMute();
    final becameActive = !oldWidget.active && widget.active;
    final becameNearby = !oldWidget.nearby && widget.nearby;
    if (becameActive) {
      _resumePlayback();
    } else if (oldWidget.active && !widget.active) {
      _pausePlayback();
    }
    if (becameNearby && !widget.active) _prepare();
  }

  @override
  void dispose() {
    _token++;
    _heart.dispose();
    final video = _controller;
    _controller = null;
    if (video != null) video.dispose();
    super.dispose();
  }

  void _prepare() {
    if (_failed || _loading) return;
    if (_isDirectVideo) {
      if (_controller == null) unawaited(_initVideo());
    } else if (widget.active && _web == null) {
      unawaited(_initWeb());
    }
  }

  Future<void> _resumePlayback() async {
    if (_isDirectVideo) {
      final video = _controller;
      if (video == null || !video.value.isInitialized) {
        await _initVideo();
        return;
      }
      await video.setVolume(widget.muted ? 0 : 1);
      await video.play();
      if (mounted) setState(() => _paused = false);
    } else {
      if (_web == null) {
        await _initWeb();
        return;
      }
      _webAction('play');
      if (mounted) setState(() => _paused = false);
    }
  }

  Future<void> _pausePlayback() async {
    final video = _controller;
    if (video != null && video.value.isInitialized && video.value.isPlaying) {
      await video.pause();
    }
    _webAction('pause');
    if (mounted && !_paused) setState(() => _paused = true);
  }

  Future<void> _initVideo() async {
    if (_loading) return;
    final uri = Uri.tryParse(widget.work.videoUrl);
    if (uri == null || !uri.hasScheme) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final token = ++_token;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final video = VideoPlayerController.networkUrl(uri);
    _controller = video;
    try {
      await video.initialize().timeout(const Duration(seconds: 30));
      await video.setLooping(true);
      await video.setVolume(widget.muted ? 0 : 1);
      if (!mounted || token != _token) {
        if (identical(_controller, video)) {
          _controller = null;
          await video.dispose();
        }
        return;
      }
      if (widget.active) {
        await video.play();
      } else {
        await video.pause();
      }
      if (!mounted || token != _token) return;
      setState(() {
        _loading = false;
        _paused = !widget.active;
      });
    } catch (error) {
      debugPrint('Failed to initialize reel video: $error');
      if (identical(_controller, video)) {
        _controller = null;
        try {
          await video.dispose();
        } catch (disposeError) {
          debugPrint('Failed to dispose broken reel video: $disposeError');
        }
      }
      if (!mounted || token != _token) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _initWeb() async {
    if (_loading || _web != null) return;
    final target = ReelVideoLink.playbackUri(widget.work.videoUrl);
    if (target == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final token = ++_token;
    setState(() {
      _loading = true;
      _failed = false;
    });

    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.black);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted || token != _token) return;
            setState(() {
              _loading = false;
              _paused = false;
            });
            _webAction('play');
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted && token == _token) {
              setState(() {
                _failed = true;
                _loading = false;
                _web = null;
              });
            }
          },
          onNavigationRequest: _allowNavigation,
        ),
      );
      if (!mounted || token != _token) return;
      _web = controller;
      final source = Uri.tryParse(widget.work.videoUrl);
      if (source != null && target.toString() != source.toString()) {
        await controller.loadHtmlString(_reelEmbedPage(target));
      } else {
        await controller.loadRequest(target);
      }
    } catch (error) {
      debugPrint('Failed to load embedded reel: $error');
      if (!mounted || token != _token) return;
      setState(() {
        _failed = true;
        _loading = false;
        _web = null;
      });
    }
  }

  static NavigationDecision _allowNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    const allowed = {'http', 'https', 'about', 'data', 'blob'};
    return allowed.contains(uri.scheme)
        ? NavigationDecision.navigate
        : NavigationDecision.prevent;
  }

  void _webAction(String action) {
    final controller = _web;
    if (controller == null) return;
    final muted = widget.muted ? 'true' : 'false';
    final String js;
    switch (action) {
      case 'play':
        js = "document.querySelectorAll('video').forEach((v) => {"
            "v.muted = $muted; v.play().catch(() => {});"
            '});'
            "document.querySelectorAll('iframe').forEach((f) => {"
            "f.contentWindow?.postMessage(JSON.stringify("
            "{event:'command',func:'playVideo',args:[]}),'*');"
            '});';
      case 'pause':
        js = "document.querySelectorAll('video').forEach((v) => v.pause());"
            "document.querySelectorAll('iframe').forEach((f) => {"
            "f.contentWindow?.postMessage(JSON.stringify("
            "{event:'command',func:'pauseVideo',args:[]}),'*');"
            '});';
      default:
        final func = widget.muted ? 'mute' : 'unMute';
        js = "document.querySelectorAll('video').forEach((v) => {"
            "v.muted = $muted;"
            '});'
            "document.querySelectorAll('iframe').forEach((f) => {"
            "f.contentWindow?.postMessage(JSON.stringify("
            "{event:'command',func:'$func',args:[]}),'*');"
            '});';
    }
    controller.runJavaScript(js).catchError((error) {
      debugPrint('Embedded reel action $action failed: $error');
    });
  }

  void _applyMute() {
    final video = _controller;
    if (video != null && video.value.isInitialized) {
      video.setVolume(widget.muted ? 0 : 1);
    }
    _webAction('mute');
  }

  void _resetPlayback() {
    _token++;
    final video = _controller;
    _controller = null;
    if (video != null) video.dispose();
    _web = null;
    _loading = false;
    _failed = false;
    _paused = false;
  }

  void _retry() {
    if (_loading) return;
    setState(() {
      _failed = false;
      _loading = false;
      _web = null;
    });
    _prepare();
  }

  Future<void> _togglePlayback() async {
    if (_failed) return;
    if (_isDirectVideo) {
      final video = _controller;
      if (video == null || !video.value.isInitialized) return;
      if (video.value.isPlaying) {
        await video.pause();
        if (mounted) setState(() => _paused = true);
      } else {
        await video.play();
        if (mounted) setState(() => _paused = false);
      }
    } else {
      final next = !_paused;
      _webAction(next ? 'pause' : 'play');
      if (mounted) setState(() => _paused = next);
    }
  }

  void _doubleTapLike() {
    if (!widget.work.likedByMe) widget.onLike();
    _heart.forward(from: 0);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _wasPlayingBeforeLongPress =
        _isDirectVideo ? (_controller?.value.isPlaying ?? false) : !_paused;
    if (_wasPlayingBeforeLongPress) unawaited(_pausePlayback());
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_wasPlayingBeforeLongPress) unawaited(_resumePlayback());
    _wasPlayingBeforeLongPress = false;
  }

  Future<void> _openLandscape() async {
    final video = _controller;
    if (_isDirectVideo && (video == null || !video.value.isInitialized)) {
      AppSnack.show(
        context,
        widget.english
            ? 'The video is still loading, one moment'
            : 'الفيديو قيد التحميل، انتظر لحظة',
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ReelFullscreenPage(
          work: widget.work,
          controller: _isDirectVideo ? video : null,
          muted: widget.muted,
          english: widget.english,
          onMutedChanged: widget.onMutedChanged,
        ),
      ),
    );
    if (!mounted) return;
    final current = _controller;
    if (_isDirectVideo && current != null && current.value.isInitialized) {
      setState(() => _paused = !current.value.isPlaying);
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = _controller;
    final ready = video?.value.isInitialized ?? false;
    final ratio = ready && video!.value.size.height > 0
        ? video.value.size.width / video.value.size.height
        : 9 / 16;
    final landscape = ready && ratio >= .9;
    final showWeb = !_isDirectVideo && _web != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 470;
        final short = constraints.maxHeight < 340;

        return ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showWeb)
                Positioned.fill(
                  child: WebViewWidget(
                    controller: _web!,
                    layoutDirection: TextDirection.ltr,
                  ),
                )
              else if (ready)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _togglePlayback,
                    onDoubleTap: _doubleTapLike,
                    onLongPressStart: _onLongPressStart,
                    onLongPressEnd: _onLongPressEnd,
                    child: _ReelVideoSurface(
                      controller: video!,
                      fit: landscape ? BoxFit.contain : BoxFit.cover,
                    ),
                  ),
                )
              else
                Positioned.fill(child: _buildPlaceholder()),
              const Positioned.fill(child: _ReelGradients()),
              if (!short)
                PositionedDirectional(
                  end: 8,
                  bottom: compact ? 76 : 88,
                  child: _ReelRail(
                    work: widget.work,
                    muted: widget.muted,
                    compact: compact,
                    onLike: widget.onLike,
                    onComments: widget.onComments,
                    onShare: widget.onShare,
                    onMutedChanged: widget.onMutedChanged,
                  ),
                ),
              PositionedDirectional(
                start: 16,
                end: 74,
                bottom: 16,
                child: _ReelCaption(
                  work: widget.work,
                  english: widget.english,
                  compact: compact,
                  onLandscape: _openLandscape,
                ),
              ),
              if (ready && video != null)
                AnimatedBuilder(
                  animation: video,
                  builder: (context, _) {
                    if (video.value.isPlaying) return const SizedBox.shrink();
                    return const IgnorePointer(
                      child: Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 76,
                          color: Colors.white70,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              _HeartBurst(controller: _heart),
              if (_loading && !_isDirectVideo)
                const IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
              if (ready && video != null)
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: _ReelProgress(controller: video),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                size: 42,
                color: Colors.white38,
              ),
              const SizedBox(height: 10),
              Text(
                widget.english
                    ? 'Could not play this video. Try a direct video link or a public share link.'
                    : 'تعذر عرض الفيديو من هذا الرابط. جرّب رابط مشاركة عام أو رابط فيديو مباشر.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.6),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _retry,
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                child: Text(widget.english ? 'Retry' : 'إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (!widget.active) {
      return const Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          size: 64,
          color: Colors.white38,
        ),
      );
    }
    return const Center(
      child: CircularProgressIndicator(color: AppColors.gold),
    );
  }
}

class _ReelGradients extends StatelessWidget {
  const _ReelGradients();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x99000000),
              Colors.transparent,
              Colors.transparent,
              Color(0xD9000000),
            ],
            stops: [0, .22, .5, 1],
          ),
        ),
      ),
    );
  }
}

class _ReelVideoSurface extends StatelessWidget {
  const _ReelVideoSurface({required this.controller, required this.fit});

  final VideoPlayerController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    final width = size.width > 0 ? size.width : 9.0;
    final height = size.height > 0 ? size.height : 16.0;
    return SizedBox.expand(
      child: FittedBox(
        fit: fit,
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: width,
          height: height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _ReelRail extends StatelessWidget {
  const _ReelRail({
    required this.work,
    required this.muted,
    required this.compact,
    required this.onLike,
    required this.onComments,
    required this.onShare,
    required this.onMutedChanged,
  });

  final OurWork work;
  final bool muted;
  final bool compact;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final ValueChanged<bool> onMutedChanged;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 9.0 : 14.0;
    final size = compact ? 38.0 : 46.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.ink,
                  size: size * .55,
                ),
              ),
              PositionedDirectional(
                end: -2,
                bottom: -2,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4FC3F7),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 9,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        _RailAction(
          icon: work.likedByMe
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: fmtNumber(work.likes),
          color: work.likedByMe ? const Color(0xFFFF4D6A) : Colors.white,
          onTap: onLike,
          compact: compact,
          semanticLabel: 'إعجاب',
        ),
        SizedBox(height: gap),
        _RailAction(
          icon: Icons.mode_comment_outlined,
          label: fmtNumber(work.commentCount),
          onTap: onComments,
          compact: compact,
          semanticLabel: 'التعليقات',
        ),
        SizedBox(height: gap),
        _RailAction(
          icon: Icons.share_outlined,
          label: 'مشاركة',
          onTap: onShare,
          compact: compact,
          semanticLabel: 'مشاركة',
        ),
        SizedBox(height: gap + 2),
        GestureDetector(
          onTap: () => onMutedChanged(!muted),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: compact ? 36 : 42,
            height: compact ? 36 : 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .14),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(
              muted ? Icons.volume_off_rounded : Icons.music_note_rounded,
              color: Colors.white,
              size: compact ? 18 : 21,
            ),
          ),
        ),
      ],
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.compact,
    required this.semanticLabel,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;
  final String semanticLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: compact ? 46 : 54,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: compact ? 27 : 31,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w800,
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelCaption extends StatelessWidget {
  const _ReelCaption({
    required this.work,
    required this.english,
    required this.compact,
    required this.onLandscape,
  });

  final OurWork work;
  final bool english;
  final bool compact;
  final VoidCallback onLandscape;

  @override
  Widget build(BuildContext context) {
    final description = work.description?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.ink,
                size: 16,
              ),
            ),
            const SizedBox(width: 7),
            const Flexible(
              child: Text(
                '@jaik',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 7)],
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.verified_rounded,
              color: Color(0xFF4FC3F7),
              size: 14,
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          work.title,
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            height: 1.35,
            shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
        if (!compact && description != null && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.45,
              shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.music_note_rounded,
              size: 14,
              color: Colors.white70,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${fmtNumber(work.views)} مشاهدة · جايك',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _LandscapeButton(english: english, onTap: onLandscape),
      ],
    );
  }
}

class _LandscapeButton extends StatelessWidget {
  const _LandscapeButton({required this.english, required this.onTap});

  final bool english;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Material(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(100),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.open_in_full_rounded,
                  size: 15,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 6),
                Text(
                  english ? 'Landscape' : 'مشاهدة بالعرض',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReelProgress extends StatelessWidget {
  const _ReelProgress({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = controller.value;
        final total = value.duration.inMicroseconds;
        final progress = total <= 0
            ? 0.0
            : (value.position.inMicroseconds / total).clamp(0.0, 1.0);
        return SizedBox(
          height: 3,
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Colors.white24),
              ),
              Positioned.fill(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: const ColoredBox(color: AppColors.gold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeartBurst extends StatelessWidget {
  const _HeartBurst({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        if (t <= 0 || t >= 1) return const SizedBox.shrink();
        return IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: .5 + Curves.elasticOut.transform(t) * .8,
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 96,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 20)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReelFullscreenPage extends StatefulWidget {
  const _ReelFullscreenPage({
    required this.work,
    required this.controller,
    required this.muted,
    required this.english,
    required this.onMutedChanged,
  });

  final OurWork work;
  final VideoPlayerController? controller;
  final bool muted;
  final bool english;
  final ValueChanged<bool> onMutedChanged;

  @override
  State<_ReelFullscreenPage> createState() => _ReelFullscreenPageState();
}

class _ReelFullscreenPageState extends State<_ReelFullscreenPage> {
  WebViewController? _web;
  bool _webLoading = false;
  bool _webFailed = false;
  late bool _muted;
  double? _scrub;

  bool get _isDirect => widget.controller != null;

  @override
  void initState() {
    super.initState();
    _muted = widget.muted;
    if (_isDirect) {
      widget.controller!.setVolume(_muted ? 0 : 1);
    } else {
      unawaited(_initWeb());
    }
    if (!kIsWeb) {
      unawaited(_enterLandscape());
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      unawaited(SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]));
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
    }
    super.dispose();
  }

  Future<void> _enterLandscape() async {
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (error) {
      debugPrint('Failed to open landscape player: $error');
    }
  }

  Future<void> _initWeb() async {
    final target = ReelVideoLink.playbackUri(widget.work.videoUrl);
    if (target == null) {
      if (mounted) setState(() => _webFailed = true);
      return;
    }
    setState(() {
      _webLoading = true;
      _webFailed = false;
    });
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.black);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _webLoading = false);
            _webAction('play');
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _webFailed = true;
                _webLoading = false;
              });
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            const allowed = {'http', 'https', 'about', 'data', 'blob'};
            return allowed.contains(uri.scheme)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      );
      if (!mounted) return;
      _web = controller;
      final source = Uri.tryParse(widget.work.videoUrl);
      if (source != null && target.toString() != source.toString()) {
        await controller.loadHtmlString(_reelEmbedPage(target));
      } else {
        await controller.loadRequest(target);
      }
    } catch (error) {
      debugPrint('Failed to open embedded reel fullscreen: $error');
      if (!mounted) return;
      setState(() {
        _webFailed = true;
        _webLoading = false;
      });
    }
  }

  void _webAction(String action) {
    final controller = _web;
    if (controller == null) return;
    final muted = _muted ? 'true' : 'false';
    final String js;
    switch (action) {
      case 'play':
        js = "document.querySelectorAll('video').forEach((v) => {"
            "v.muted = $muted; v.play().catch(() => {});"
            '});'
            "document.querySelectorAll('iframe').forEach((f) => {"
            "f.contentWindow?.postMessage(JSON.stringify("
            "{event:'command',func:'playVideo',args:[]}),'*');"
            '});';
      case 'pause':
        js = "document.querySelectorAll('video').forEach((v) => v.pause());"
            "document.querySelectorAll('iframe').forEach((f) => {"
            "f.contentWindow?.postMessage(JSON.stringify("
            "{event:'command',func:'pauseVideo',args:[]}),'*');"
            '});';
      default:
        final func = _muted ? 'mute' : 'unMute';
        js = "document.querySelectorAll('video').forEach((v) => {"
            "v.muted = $muted;"
            '});'
            "document.querySelectorAll('iframe').forEach((f) => {"
            "f.contentWindow?.postMessage(JSON.stringify("
            "{event:'command',func:'$func',args:[]}),'*');"
            '});';
    }
    controller.runJavaScript(js).catchError((error) {
      debugPrint('Embedded fullscreen action $action failed: $error');
    });
  }

  Future<void> _togglePlay() async {
    final video = widget.controller;
    if (video == null) return;
    try {
      if (video.value.isPlaying) {
        await video.pause();
      } else {
        await video.play();
      }
    } catch (error) {
      debugPrint('Failed to toggle fullscreen playback: $error');
    }
  }

  void _toggleMute() {
    final next = !_muted;
    setState(() => _muted = next);
    widget.onMutedChanged(next);
    final video = widget.controller;
    if (video != null) {
      video.setVolume(next ? 0 : 1);
    } else {
      _webAction('mute');
    }
  }

  Future<void> _finishScrub(double value) async {
    final video = widget.controller;
    if (video != null) {
      final duration = video.value.duration;
      await video.seekTo(Duration(
        microseconds: (duration.inMicroseconds * value).round(),
      ));
    }
    if (mounted) setState(() => _scrub = null);
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video != null)
              _FullscreenVideo(controller: video, onTap: _togglePlay)
            else
              _buildEmbed(),
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 12, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: widget.english ? 'Close' : 'إغلاق',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        widget.work.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _muted
                          ? (widget.english ? 'Unmute' : 'تشغيل الصوت')
                          : (widget.english ? 'Mute' : 'كتم الصوت'),
                      onPressed: _toggleMute,
                      icon: Icon(
                        _muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (video != null)
              AnimatedBuilder(
                animation: video,
                builder: (context, _) {
                  if (video.value.isPlaying) return const SizedBox.shrink();
                  return IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: .45),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (video != null)
              PositionedDirectional(
                start: 10,
                end: 10,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                  child: _FullscreenControls(
                    controller: video,
                    scrub: _scrub,
                    onScrub: (value) => setState(() => _scrub = value),
                    onScrubEnd: _finishScrub,
                  ),
                ),
              ),
            if (video == null && _webLoading)
              const IgnorePointer(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              ),
            if (video == null && _webFailed)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    widget.english
                        ? 'Could not open this video.'
                        : 'تعذر فتح هذا الفيديو.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbed() {
    final web = _web;
    if (web != null) {
      return WebViewWidget(
        controller: web,
        layoutDirection: TextDirection.ltr,
      );
    }
    return const ColoredBox(color: Colors.black);
  }
}

class _FullscreenVideo extends StatelessWidget {
  const _FullscreenVideo({required this.controller, required this.onTap});

  final VideoPlayerController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    final width = size.width > 0 ? size.width : 16.0;
    final height = size.height > 0 ? size.height : 9.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: width,
            height: height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}

class _FullscreenControls extends StatelessWidget {
  const _FullscreenControls({
    required this.controller,
    required this.scrub,
    required this.onScrub,
    required this.onScrubEnd,
  });

  final VideoPlayerController controller;
  final double? scrub;
  final ValueChanged<double> onScrub;
  final ValueChanged<double> onScrubEnd;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = controller.value;
        final duration = value.duration;
        final total = duration.inMicroseconds;
        final progress = total <= 0
            ? 0.0
            : (value.position.inMicroseconds / total).clamp(0.0, 1.0);
        final shownProgress = (scrub ?? progress).clamp(0.0, 1.0);
        final position = scrub != null && total > 0
            ? Duration(microseconds: (total * scrub!).round())
            : value.position;
        return Row(
          children: [
            IconButton(
              tooltip: value.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
              onPressed: () async {
                try {
                  if (value.isPlaying) {
                    await controller.pause();
                  } else {
                    await controller.play();
                  }
                } catch (error) {
                  debugPrint('Fullscreen play toggle failed: $error');
                }
              },
              icon: Icon(
                value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
            ),
            Text(
              _clock(position),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2.5,
                  activeTrackColor: AppColors.gold,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: AppColors.gold,
                  overlayColor: AppColors.gold.withValues(alpha: .2),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5.5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 13,
                  ),
                ),
                child: Slider(
                  value: shownProgress,
                  onChanged: total <= 0 ? null : onScrub,
                  onChangeEnd: total <= 0 ? null : onScrubEnd,
                ),
              ),
            ),
            Text(
              _clock(duration),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
          ],
        );
      },
    );
  }
}

String _clock(Duration value) {
  final total = value.inSeconds;
  final minutes = total ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _reelEmbedPage(Uri target) {
  final escapedUrl = target
      .toString()
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  return '<!doctype html><html><head><meta name="viewport" '
      'content="width=device-width, initial-scale=1, maximum-scale=1">'
      '<style>html,body{margin:0;width:100%;height:100%;overflow:hidden;'
      'background:#000}iframe{border:0;width:100%;height:100%;'
      'position:absolute;inset:0}</style></head><body>'
      '<iframe id="reel-player" src="$escapedUrl" '
      'allow="autoplay; encrypted-media; picture-in-picture; fullscreen" '
      'allowfullscreen playsinline></iframe></body></html>';
}

class _ReelCommentsSheet extends StatefulWidget {
  const _ReelCommentsSheet({required this.work});

  final OurWork work;

  @override
  State<_ReelCommentsSheet> createState() => _ReelCommentsSheetState();
}

class _ReelCommentsSheetState extends State<_ReelCommentsSheet> {
  final _controller = TextEditingController();
  late Future<List<WorkComment>> _comments;
  int? _count;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _load() {
    _comments = context.read<AppState>().repo.workComments(widget.work.id!);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final state = context.read<AppState>();
    final user = state.user;
    if (text.isEmpty || user?.id == null || _sending) return;
    setState(() => _sending = true);
    try {
      await state.repo.addWorkComment(WorkComment(
        workId: widget.work.id!,
        userId: user!.id!,
        userName: user.name,
        body: text,
        createdAt: DateTime.now(),
      ));
      _controller.clear();
      setState(() {
        _count = (_count ?? widget.work.commentCount) + 1;
        _load();
      });
    } catch (error) {
      if (mounted) {
        AppSnack.show(context, 'تعذر إرسال التعليق: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: SheetHeader(
                title: 'التعليقات',
                subtitle: widget.work.title,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<WorkComment>>(
                future: _comments,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('تعذر تحميل التعليقات: ${snapshot.error}'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  final comments = snapshot.data!;
                  _count ??= comments.length;
                  if (comments.isEmpty) {
                    return const Center(
                      child: Text('لا توجد تعليقات بعد، كن أول من يعلّق.'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AvatarCircle(name: comment.userName, size: 34),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        comment.userName,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ),
                                    Text(
                                      timeAgo(comment.createdAt),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(comment.body),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                10,
                14,
                10 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'أضف تعليقاً...',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _count ?? widget.work.commentCount),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}
