import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/media_view.dart';
import '../widgets/ui.dart';

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

  @override
  void initState() {
    super.initState();
    _work = widget.work;
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant WorkReel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _work = widget.work;
    if (oldWidget.work.videoUrl != widget.work.videoUrl) {
      _disposeVideo();
      _failed = false;
      _initializeVideo();
    } else if (oldWidget.isActive != widget.isActive) {
      _syncPlayback();
    }
  }

  Future<void> _initializeVideo() async {
    final path = widget.work.videoUrl.trim();
    VideoPlayerController? controller;
    try {
      if (isAssetMedia(path)) {
        controller = VideoPlayerController.asset(path.replaceFirst('asset:', ''));
      } else if (isNetworkMedia(path)) {
        controller = VideoPlayerController.networkUrl(Uri.parse(path));
      } else {
        controller = VideoPlayerController.file(File(path));
      }
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      controller.addListener(_videoChanged);
      _syncPlayback();
    } catch (error, stackTrace) {
      await controller?.dispose();
      debugPrint('Failed to initialize work video: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _failed = true);
    }
  }

  void _videoChanged() {
    if (mounted) setState(() {});
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncPlayback();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _userPaused = controller.value.isPlaying;
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

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(_work.videoUrl);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      AppSnack.show(context, 'تعذر فتح رابط الفيديو', error: true);
    }
  }

  void _disposeVideo() {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_videoChanged);
    controller?.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
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
                  opacity: _showPlayIcon || !controller.value.isPlaying ? 1 : 0,
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
            bottom: 20,
            child: _actions(),
          ),
          PositionedDirectional(
            start: 16,
            end: 82,
            bottom: 20,
            child: _caption(),
          ),
          if (controller != null && controller.value.isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: AppColors.gold,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
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
            const Text(
              'تعذر تشغيل الفيديو داخل التطبيق',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('فتح الرابط'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientOverlay() {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x55000000),
              Colors.transparent,
              Color(0xCC000000),
            ],
            stops: [0, .35, 1],
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ReelAction(
          icon: _work.likedByMe
              ? Icons.favorite_rounded
              : Icons.favorite_outline_rounded,
          label: fmtNumber(_work.likes),
          color: _work.likedByMe ? AppColors.danger : Colors.white,
          onTap: _toggleLike,
        ),
        const SizedBox(height: 18),
        _ReelAction(
          icon: Icons.mode_comment_rounded,
          label: fmtNumber(_work.commentCount),
          onTap: _openComments,
        ),
        const SizedBox(height: 18),
        _ReelAction(
          icon: Icons.share_rounded,
          label: 'مشاركة',
          onTap: _share,
        ),
      ],
    );
  }

  Widget _caption() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
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
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: AppColors.gold,
                    child: Icon(Icons.handyman_rounded, color: AppColors.ink),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'جايك',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      '· ${fmtDateShort(_work.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
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
        if (_work.description?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 3),
          Text(
            _work.description!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.visibility_outlined,
                color: Colors.white70, size: 13),
            const SizedBox(width: 4),
            Text(
              '${fmtNumber(_work.views)} مشاهدة',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReelAction extends StatelessWidget {
  const _ReelAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color color;
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
            Icon(icon, color: color, size: 30),
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
  late Future<List<WorkComment>> _comments;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _comments = _loadComments();
  }

  Future<List<WorkComment>> _loadComments() {
    return context.read<AppState>().repo.workComments(widget.work.id!);
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    final state = context.read<AppState>();
    final user = state.user;
    final workId = widget.work.id;
    if (text.isEmpty || user?.id == null || workId == null || _sending) return;
    setState(() => _sending = true);
    try {
      await state.repo.addWorkComment(
        WorkComment(
          workId: workId,
          userId: user!.id!,
          userName: user.name,
          body: text,
          createdAt: DateTime.now(),
        ),
      );
      _comment.clear();
      setState(() => _comments = _loadComments());
      widget.onCommentAdded();
    } catch (error, stackTrace) {
      debugPrint('Failed to add work comment: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) AppSnack.show(context, 'تعذر إرسال التعليق', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<WorkComment>>(
              future: _comments,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('تعذر تحميل التعليقات'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final comments = snapshot.data ?? const <WorkComment>[];
                if (comments.isEmpty) {
                  return const Center(
                    child: Text('لا توجد تعليقات بعد. كن أول من يعلّق!'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AvatarCircle(
                          name: comment.userName,
                          size: 36,
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
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(fontSize: 10),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                comment.body,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
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
                    child: TextField(
                      controller: _comment,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'اكتب تعليقاً...',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
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
                    color: AppColors.ink,
                    style: IconButton.styleFrom(backgroundColor: AppColors.gold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
