import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../data/youtube_stream.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/media_view.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';

/// يستخرج رابط فيديو يوتيوب مسبقاً، فيبدأ تشغيله فوراً حين يصل إليه الزبون.
void prepareWorkVideo(OurWork work) {
  if (kIsWeb) return;
  final id = youtubeIdOf(work.videoUrl.trim());
  if (id != null) resolveYoutubeStream(id).ignore();
}

class WorkReel extends StatefulWidget {
  const WorkReel({
    super.key,
    required this.work,
    required this.isActive,
    required this.onChanged,
  });

  final OurWork work;
  final bool isActive;
  final VoidCallback onChanged;

  @override
  State<WorkReel> createState() => _WorkReelState();
}

class _WorkReelState extends State<WorkReel> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  late OurWork _work;
  bool _failed = false;
  bool _userPaused = false;
  bool _showPlayIcon = false;
  bool _isPlaying = false;
  bool _showDate = false;
  int _initializationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _work = widget.work;
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant WorkReel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // بعد الإعجاب تعيد الصفحة جلب الأعمال، وتمرّر النسخة القديمة نفسها حتى يصل الجديد.
    // أخذها كان يرجع القلب فارغاً لحظةً، ثم يمتلئ ويحتفل مرة ثانية.
    if (!identical(oldWidget.work, widget.work)) _work = widget.work;
    if (oldWidget.work.videoUrl != widget.work.videoUrl) {
      _failed = false;
      _isPlaying = false;
      unawaited(_replaceVideo());
    } else if (oldWidget.isActive != widget.isActive) {
      _userPaused = false;
      if (widget.isActive) {
        _initializeVideo();
      } else {
        _isPlaying = false;
        unawaited(_disposeVideo());
      }
    }
  }

  Future<void> _replaceVideo() async {
    await _disposeVideo();
    if (mounted && widget.isActive) _initializeVideo();
  }

  /// رابط الفيديو الذي يُشغَّل داخل التطبيق: رابط يوتيوب يُستخرج منه ملف الفيديو نفسه ليُشغَّل
  /// بمشغّل التطبيق، وغيره يُشغَّل كما هو.
  Future<String> _playableUrl(String path) async {
    final id = youtubeIdOf(path);
    if (id == null) return path;
    return resolveYoutubeStream(id);
  }

  Future<void> _initializeVideo() async {
    if (!widget.isActive || _controller != null) return;
    final generation = ++_initializationGeneration;
    final path = widget.work.videoUrl.trim();
    VideoPlayerController? controller;
    try {
      if (isAssetMedia(path)) {
        controller =
            VideoPlayerController.asset(path.replaceFirst('asset:', ''));
      } else if (isNetworkMedia(path)) {
        final url = await _playableUrl(path);
        if (!mounted || generation != _initializationGeneration || !widget.isActive) return;
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        controller = VideoPlayerController.file(File(path));
      }
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted ||
          generation != _initializationGeneration ||
          !widget.isActive) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      controller.addListener(_videoChanged);
      await _syncPlayback();
    } catch (error, stackTrace) {
      await controller?.dispose();
      debugPrint('Failed to initialize work video: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted && generation == _initializationGeneration) {
        setState(() => _failed = true);
      }
    }
  }

  void _videoChanged() {
    final isPlaying = _controller?.value.isPlaying ?? false;
    if (mounted && isPlaying != _isPlaying) {
      setState(() => _isPlaying = isPlaying);
    }
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final shouldPlay = widget.isActive &&
        !_userPaused &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (shouldPlay && !controller.value.isPlaying) {
      await controller.play();
    } else if (!shouldPlay && controller.value.isPlaying) {
      await controller.pause();
    }
    if (mounted && _isPlaying != controller.value.isPlaying) {
      setState(() => _isPlaying = controller.value.isPlaying);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncPlayback();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _userPaused = _isPlaying;
    await _syncPlayback();
    if (mounted) {
      setState(() => _showPlayIcon = _userPaused);
      if (!_userPaused) {
        Future<void>.delayed(const Duration(milliseconds: 650), () {
          if (mounted) setState(() => _showPlayIcon = false);
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    final id = _work.id;
    final userId = context.read<AppState>().user?.id;
    if (id == null || userId == null) return;
    final previous = _work;
    final liked = !_work.likedByMe;
    setState(() => _work = _work.copyWith(
          likedByMe: liked,
          likes: (_work.likes + (liked ? 1 : -1)).clamp(0, 1 << 30).toInt(),
        ));
    try {
      await context.read<AppState>().repo.setWorkLike(
            id,
            userId: userId,
            liked: liked,
          );
      widget.onChanged();
    } catch (error, stackTrace) {
      debugPrint('Failed to update work like: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _work = previous);
        AppSnack.show(context, 'تعذر تسجيل الإعجاب', error: true);
      }
    }
  }

  Future<void> _openComments() async {
    final id = _work.id;
    if (id == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => WorkCommentsSheet(
        work: _work,
        onCommentAdded: () {
          setState(() => _work = _work.copyWith(
                commentCount: _work.commentCount + 1,
              ));
          widget.onChanged();
        },
      ),
    );
  }

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: _work.videoUrl));
    if (mounted) AppSnack.show(context, 'تم نسخ رابط الفيديو');
  }

  /// يعيد محاولة تشغيل الفيديو بعد فشله.
  void _retry() {
    setState(() => _failed = false);
    _initializeVideo();
  }

  Future<void> _disposeVideo() async {
    _initializationGeneration++;
    final controller = _controller;
    _controller = null;
    _isPlaying = false;
    controller?.removeListener(_videoChanged);
    if (controller == null) return;
    try {
      await controller.pause();
    } catch (error, stackTrace) {
      debugPrint('Failed to pause inactive work video: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    try {
      await controller.dispose();
    } catch (error, stackTrace) {
      debugPrint('Failed to release work video: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeVideo());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    // الشعار يساراً والأزرار يميناً، على مستوى واحد فوق شريط التنقل مباشرة.
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final bottomClearance =
        wide ? 20.0 : MediaQuery.paddingOf(context).bottom + 6;
    // شريط التقدم واقف على زجاج شريط التنقل مباشرة، والخط الرفيع في وسط مكان لمسه.
    final progressBottom = wide ? 0.0 : glassBarTop(context);
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            _video(controller)
          else if (_failed)
            _videoUnavailable()
          else
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.gold,
              ),
            ),
          if (controller != null && controller.value.isInitialized)
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _togglePlayback,
              onDoubleTap: () {
                if (!_work.likedByMe) _toggleLike();
              },
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showPlayIcon || !_isPlaying ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white70,
                    size: 74,
                  ),
                ),
              ),
            ),
          _gradientOverlay(),
          Positioned(
            right: 12,
            bottom: bottomClearance,
            child: _actions(),
          ),
          Positioned(
            left: 16,
            right: 82,
            bottom: bottomClearance,
            child: _caption(),
          ),
          if (controller != null && controller.value.isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: progressBottom,
              child: ReelProgressBar(controller: controller),
            ),
        ],
      ),
    );
  }

  Widget _video(VideoPlayerController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.width <= 0 || size.height <= 0) {
          return const SizedBox.shrink();
        }
        final videoRatio = controller.value.aspectRatio;
        final boxRatio = size.width / size.height;
        final videoWidth =
            videoRatio > boxRatio ? size.height * videoRatio : size.width;
        final videoHeight =
            videoRatio > boxRatio ? size.height : size.width / videoRatio;
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: videoWidth,
              height: videoHeight,
              child: VideoPlayer(controller),
            ),
          ),
        );
      },
    );
  }

  Widget _videoUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_disabled_rounded,
                color: Colors.white70, size: 44),
            const SizedBox(height: 8),
            Text(
              kIsWeb && youtubeIdOf(_work.videoUrl) != null
                  ? 'روابط يوتيوب تُشغَّل داخل التطبيق على الهاتف، والمتصفح يمنع ذلك. استعمل رابط فيديو مباشر (mp4) للتجربة هنا.'
                  : 'تعذر تشغيل الفيديو داخل التطبيق',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'إعادة المحاولة',
              icon: Icons.refresh_rounded,
              compact: true,
              expand: false,
              onPressed: _retry,
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientOverlay() {
    return const IgnorePointer(
      child: DecoratedBox(
        // طبقة واحدة ثابتة اللون فوق الفيديو لتقرأ النصوص، بلا تدرج.
        decoration: BoxDecoration(color: Color(0x66000000)),
      ),
    );
  }

  Widget _actions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ReelAction(
          icon: LikeHeart(liked: _work.likedByMe),
          label: fmtNumber(_work.likes),
          onTap: _toggleLike,
        ),
        const SizedBox(height: 18),
        _ReelAction(
          icon: const ReelGlyph(ReelGlyphShape.comment),
          label: fmtNumber(_work.commentCount),
          onTap: _openComments,
        ),
        const SizedBox(height: 18),
        _ReelAction(
          icon: const ReelGlyph(ReelGlyphShape.share),
          label: 'مشاركة',
          onTap: _share,
        ),
      ],
    );
  }

  // الشعار على اليسار وجايك بجانبه، وكلام الفيديو على اليمين يُظهر تاريخ النشر عند لمسه.
  Widget _caption() {
    final description = _work.description?.trim();
    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          textDirection: TextDirection.ltr,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.jpg',
                  fit: BoxFit.cover,
                  cacheWidth: 76,
                  cacheHeight: 76,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: AppColors.gold,
                    child: Icon(Icons.handyman_rounded, color: AppColors.onGold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            const Text(
              'جايك',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Align(
            alignment: Alignment.bottomRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showDate = !_showDate),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _work.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1.45,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (_showDate) ...[
                    const SizedBox(height: 4),
                    Text(
                      fmtDateShort(_work.createdAt),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// شريط تقدم الفيديو فوق شريط التنقل. في العربية يمتلئ من اليمين، والسحب نحو اليسار يقدّم الفيديو.
class ReelProgressBar extends StatelessWidget {
  const ReelProgressBar({super.key, required this.controller});

  final VideoPlayerController controller;

  /// سُمك الخط المرسوم.
  static const thickness = 2.5;

  /// ارتفاع مكان اللمس حول الخط، ليسهل سحبه وهو رفيع.
  static const touchHeight = 16.0;

  @override
  Widget build(BuildContext context) {
    // سحّاب video_player يقيس الإصبع من الحافة اليسرى دائماً، والشريط في العربية يمتلئ من
    // اليمين، فكان السحب لليسار يرجّع الفيديو. يُرسم الشريط من اليسار ثم يُقلب، فيتبع اللمس امتلاءه.
    return Transform.flip(
      flipX: Directionality.of(context) == TextDirection.rtl,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: touchHeight,
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(
                vertical: (touchHeight - thickness) / 2),
            colors: const VideoProgressColors(
              playedColor: AppColors.gold,
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ),
    );
  }
}

/// حجم أيقونات الفيديو (القلب والتعليقات والمشاركة)، 24 مثل إنستغرام.
const reelIconSize = 24.0;

/// قلب الإعجاب بتصميم con-like: قلب محدد أبيض (طلب المستخدم، والتصميم أحمر)، وعند الإعجاب
/// يحمرّ ويظهر فوقه القلب الممتلئ الأحمر من لا شيء ويكبر إلى 1.2 ثم يستقر، وتنطلق حوله ستة خطوط تكبر وتختفي، كله في نصف ثانية.
class LikeHeart extends StatefulWidget {
  const LikeHeart({super.key, required this.liked, this.size = reelIconSize});

  final bool liked;
  final double size;

  /// --red في التصميم.
  static const red = Color.fromRGBO(255, 50, 50, 1);

  @override
  State<LikeHeart> createState() => _LikeHeartState();
}

class _LikeHeartState extends State<LikeHeart>
    with SingleTickerProviderStateMixin {
  // يبدأ منتهياً، فالقلب المعجب به من قبل يظهر ثابتاً بلا احتفال.
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 1,
  );

  // kfr-filled: من 0 إلى 1.2 مع الظهور، ثم يعود إلى حجمه.
  late final _fillScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.ease)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.ease)),
      weight: 1,
    ),
  ]).animate(_controller);
  late final _fillOpacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.ease)),
      weight: 1,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 1),
  ]).animate(_controller);

  // kfr-celebrate: الخطوط تكبر من 0 إلى 1.2، وتخفت إلى 0.8 ثم تختفي.
  late final _burstScale = Tween(begin: 0.0, end: 1.2)
      .chain(CurveTween(curve: Curves.ease))
      .animate(_controller);
  late final _burstOpacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: .8).chain(CurveTween(curve: Curves.ease)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: .8, end: 0.0).chain(CurveTween(curve: Curves.ease)),
      weight: 1,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(LikeHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.liked && !oldWidget.liked) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // أبيض قبل الإعجاب مثل باقي الأيقونات، وأحمر معه.
          Icon(Icons.favorite_outline_rounded,
              size: size, color: widget.liked ? LikeHeart.red : Colors.white),
          if (widget.liked) ...[
            FadeTransition(
              opacity: _fillOpacity,
              child: ScaleTransition(
                scale: _fillScale,
                child: Icon(Icons.favorite_rounded,
                    size: size, color: LikeHeart.red),
              ),
            ),
            // مربع الخطوط ضعف القلب، كما في التصميم (100 حول قلب 50).
            OverflowBox(
              maxWidth: size * 2,
              maxHeight: size * 2,
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: _burstOpacity,
                  child: ScaleTransition(
                    scale: _burstScale,
                    child: CustomPaint(
                      size: Size.square(size * 2),
                      painter: const _BurstPainter(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// خطوط الاحتفال حول القلب، بنقاطها في التصميم داخل مربع 100 وبخط سُمكه 1.
class _BurstPainter extends CustomPainter {
  const _BurstPainter();

  static const _lines = [
    (Offset(10, 10), Offset(20, 20)),
    (Offset(10, 50), Offset(20, 50)),
    (Offset(20, 80), Offset(30, 70)),
    (Offset(90, 10), Offset(80, 20)),
    (Offset(90, 50), Offset(80, 50)),
    (Offset(80, 80), Offset(70, 70)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    final paint = Paint()
      ..color = LikeHeart.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (from, to) in _lines) {
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => false;
}

enum ReelGlyphShape { comment, share }

/// أيقونات الفيديو مرسومة بخط مثل إنستغرام: فقاعة كلام للتعليقات وطائرة ورقية للمشاركة.
class ReelGlyph extends StatelessWidget {
  const ReelGlyph(this.shape, {super.key, this.size = reelIconSize});

  final ReelGlyphShape shape;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ReelGlyphPainter(shape),
    );
  }
}

class _ReelGlyphPainter extends CustomPainter {
  const _ReelGlyphPainter(this.shape);

  final ReelGlyphShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    // الرسم في مربع 24 وخطه 2، مثل باقي الأيقونات.
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    switch (shape) {
      case ReelGlyphShape.comment:
        // دائرة يخرج منها ذيل صغير نحو الأسفل.
        const centre = Offset(12, 11.6);
        const radius = 9.4;
        const start = 22 * math.pi / 180;
        final bubble = Path()
          ..moveTo(centre.dx + radius * math.cos(start),
              centre.dy + radius * math.sin(start))
          ..arcTo(Rect.fromCircle(center: centre, radius: radius), start,
              -314 * math.pi / 180, false)
          ..lineTo(21.5, 21.3)
          ..close();
        canvas.drawPath(bubble, paint);
      case ReelGlyphShape.share:
        // طائرة ورقية رأسها إلى الأعلى، وطيّتها خط من الرأس إلى وسطها.
        final plane = Path()
          ..moveTo(2.5, 3.5)
          ..lineTo(21.5, 3.5)
          ..lineTo(12.2, 20.2)
          ..lineTo(9.6, 10.4)
          ..close();
        canvas.drawPath(plane, paint);
        canvas.drawLine(const Offset(21.5, 3.5), const Offset(9.6, 10.4), paint);
    }
  }

  @override
  bool shouldRepaint(_ReelGlyphPainter oldDelegate) =>
      oldDelegate.shape != shape;
}

class _ReelAction extends StatelessWidget {
  const _ReelAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: 52,
        child: Column(
          children: [
            icon,
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkCommentsSheet extends StatefulWidget {
  const WorkCommentsSheet({
    super.key,
    required this.work,
    required this.onCommentAdded,
  });

  final OurWork work;
  final VoidCallback onCommentAdded;

  @override
  State<WorkCommentsSheet> createState() => _WorkCommentsSheetState();
}

class _WorkCommentsSheetState extends State<WorkCommentsSheet> {
  final _comment = TextEditingController();
  List<WorkComment> _cachedComments = [];
  final List<WorkComment> _postedComments = [];
  WorkComment? _replyTo;
  Object? _loadError;
  bool _loadingComments = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshComments());
  }

  Future<void> _refreshComments() async {
    final state = context.read<AppState>();
    try {
      final comments = await state.repo.workComments(
        widget.work.id!,
        viewerId: state.user?.id,
        isAdmin: state.isAdmin,
      );
      if (!mounted) return;
      setState(() {
        _cachedComments = comments;
        _loadError = null;
        _loadingComments = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load work comments: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loadingComments = false;
      });
    }
  }

  void _reloadComments() {
    setState(() {
      _loadError = null;
      _loadingComments = true;
    });
    unawaited(_refreshComments());
  }

  Future<void> _setReaction(WorkComment comment, int reaction) async {
    final state = context.read<AppState>();
    final userId = state.user?.id;
    if (comment.id == null || userId == null) return;
    try {
      await state.repo.setWorkCommentReaction(
        comment.id!,
        userId: userId,
        reaction: comment.reactionByMe == reaction ? 0 : reaction,
      );
      if (mounted) _reloadComments();
    } catch (error, stackTrace) {
      debugPrint('Failed to react to work comment: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) AppSnack.show(context, 'تعذر تسجيل التفاعل', error: true);
    }
  }

  Future<void> _setHeart(WorkComment comment) async {
    if (comment.id == null || !context.read<AppState>().isAdmin) return;
    try {
      await context.read<AppState>().repo.setWorkCommentHeart(
            comment.id!,
            hearted: !comment.adminHearted,
          );
      if (mounted) _reloadComments();
    } catch (error, stackTrace) {
      debugPrint('Failed to heart work comment: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) AppSnack.show(context, 'تعذر وضع القلب', error: true);
    }
  }

  Future<void> _editComment(WorkComment comment) async {
    if (comment.id == null) return;
    final repository = context.read<AppState>().repo;
    final controller = TextEditingController(text: comment.body);
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل التعليق'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          maxLength: 2000,
          decoration: const InputDecoration(hintText: 'اكتب تعليقك'),
        ),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          SecondaryButton(
            label: 'إلغاء',
            compact: true,
            expand: false,
            onPressed: () => Navigator.pop(context),
          ),
          PrimaryButton(
            label: 'حفظ',
            compact: true,
            expand: false,
            onPressed: () => Navigator.pop(context, controller.text.trim()),
          ),
        ],
      ),
    );
    controller.dispose();
    final updatedBody = body?.trim();
    if (updatedBody == null ||
        updatedBody.isEmpty ||
        updatedBody == comment.body) {
      return;
    }
    try {
      await repository.updateWorkComment(comment.id!, body: updatedBody);
      if (mounted) _reloadComments();
    } catch (error, stackTrace) {
      debugPrint('Failed to edit work comment: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) AppSnack.show(context, 'تعذر تعديل التعليق', error: true);
    }
  }

  void _replyToComment(WorkComment comment) {
    setState(() => _replyTo = comment);
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    final state = context.read<AppState>();
    final user = state.user;
    final workId = widget.work.id;
    if (text.isEmpty || user?.id == null || workId == null || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = WorkComment(
        workId: workId,
        userId: user!.id!,
        parentCommentId: _replyTo?.id,
        userName: user.name,
        body: text,
        createdAt: DateTime.now(),
      );
      final commentId = await state.repo.addWorkComment(comment);
      if (!mounted) return;
      setState(() {
        _postedComments.add(
          WorkComment(
            id: commentId,
            workId: comment.workId,
            userId: comment.userId,
            parentCommentId: comment.parentCommentId,
            userName: comment.userName,
            body: comment.body,
            createdAt: comment.createdAt,
          ),
        );
        _comment.clear();
        _replyTo = null;
        _loadingComments = true;
        _loadError = null;
      });
      unawaited(_refreshComments());
      widget.onCommentAdded();
    } catch (error, stackTrace) {
      debugPrint('Failed to add work comment: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) AppSnack.show(context, 'تعذر إرسال التعليق', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<WorkComment> _mergePostedComments(List<WorkComment> comments) {
    final byId = <int, WorkComment>{
      for (final comment in comments)
        if (comment.id != null) comment.id!: comment,
    };
    for (final comment in _postedComments) {
      if (comment.id != null) byId.putIfAbsent(comment.id!, () => comment);
    }
    return byId.values.toList()
      ..sort((first, second) => first.createdAt.compareTo(second.createdAt));
  }

  Widget _commentList(List<WorkComment> comments, AppState state) {
    final commentsById = {
      for (final comment in comments)
        if (comment.id != null) comment.id!: comment,
    };
    final replies = <int, List<WorkComment>>{};
    for (final comment in comments) {
      final parentId = comment.parentCommentId;
      if (parentId != null && commentsById.containsKey(parentId)) {
        replies.putIfAbsent(parentId, () => []).add(comment);
      }
    }
    final roots = comments
        .where((comment) =>
            comment.parentCommentId == null ||
            !commentsById.containsKey(comment.parentCommentId))
        .toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: roots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) => _commentThread(
        roots[index],
        replies,
        state: state,
        depth: 0,
      ),
    );
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'التعليقات',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                AppIconButton(
                  small: true,
                  onTap: () => Navigator.pop(context),
                  icon: Icons.close_rounded,
                  tooltip: 'إغلاق',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _commentContent(state)),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.colorScheme.outline)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyTo != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'الرد على ${_replyTo!.userName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                AppIconButton(
                                  small: true,
                                  onTap: () => setState(() => _replyTo = null),
                                  icon: Icons.close_rounded,
                                  tooltip: 'إلغاء الرد',
                                ),
                              ],
                            ),
                          ),
                        TextField(
                          controller: _comment,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: _replyTo == null
                                ? 'اكتب تعليقاً...'
                                : 'اكتب ردك...',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    onTap: _sending ? null : _send,
                    icon: Icons.send_rounded,
                    tooltip: 'إرسال',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentContent(AppState state) {
    final comments = _mergePostedComments(_cachedComments);
    if (_loadingComments && comments.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_loadError != null && comments.isEmpty) {
      return const Center(child: Text('تعذر تحميل التعليقات'));
    }
    if (_loadError != null) {
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('تعذر تحديث بعض التعليقات'),
          ),
          Expanded(child: _commentList(comments, state)),
        ],
      );
    }
    if (_loadingComments) return _commentList(comments, state);
    if (comments.isEmpty) {
      return const Center(
        child: Text('لا توجد تعليقات بعد. كن أول من يعلّق!'),
      );
    }
    return _commentList(comments, state);
  }

  Widget _commentThread(
    WorkComment comment,
    Map<int, List<WorkComment>> replies, {
    required AppState state,
    required int depth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(start: depth == 0 ? 0 : 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarCircle(
                name: comment.userName,
                size: depth == 0 ? 36 : 30,
                imagePath: comment.avatarPath,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo(comment.createdAt),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 10),
                        ),
                        if (comment.adminHearted && state.isAdmin) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.favorite_rounded,
                              color: AppColors.danger, size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      comment.body,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 2,
                      runSpacing: 0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _commentAction(
                          icon: Icons.thumb_up_alt_outlined,
                          count: comment.likes,
                          selected: comment.reactionByMe == 1,
                          onPressed: () => _setReaction(comment, 1),
                        ),
                        _commentAction(
                          icon: Icons.thumb_down_alt_outlined,
                          count: comment.dislikes,
                          selected: comment.reactionByMe == -1,
                          onPressed: () => _setReaction(comment, -1),
                        ),
                        _commentAction(
                          icon: Icons.reply_rounded,
                          label: 'رد',
                          onPressed: () => _replyToComment(comment),
                        ),
                        if (state.isAdmin)
                          _commentAction(
                            icon: comment.adminHearted
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: AppColors.danger,
                            label: 'قلب المدير',
                            selected: comment.adminHearted,
                            onPressed: () => _setHeart(comment),
                          ),
                        if (state.isAdmin || state.user?.id == comment.userId)
                          _commentAction(
                            icon: Icons.edit_outlined,
                            label: 'تعديل',
                            onPressed: () => _editComment(comment),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (comment.id != null)
          for (final reply in replies[comment.id!] ?? const <WorkComment>[])
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _commentThread(
                reply,
                replies,
                state: state,
                depth: depth + 1,
              ),
            ),
      ],
    );
  }

  Widget _commentAction({
    required IconData icon,
    required VoidCallback onPressed,
    int? count,
    String? label,
    Color? color,
    bool selected = false,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(32, 30),
        foregroundColor: selected ? AppColors.gold : color,
      ),
      icon: Icon(icon, size: 15),
      label: Text(
        count == null ? (label ?? '') : fmtNumber(count),
        style: const TextStyle(fontSize: 10),
      ),
    );
  }
}
