import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/ui.dart';

class ReelsTab extends StatefulWidget {
  const ReelsTab({super.key});

  @override
  State<ReelsTab> createState() => _ReelsTabState();
}

class _ReelsTabState extends State<ReelsTab> with RealtimeRefresh<ReelsTab> {
  late Future<List<OurWork>> _future;
  List<OurWork> _works = const [];
  int _currentPage = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
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
    final count = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReelCommentsSheet(work: work),
    );
    if (!mounted || count == null) return;
    setState(() {
      _works[index] = _works[index].copyWith(commentCount: count);
    });
  }

  Future<void> _share(OurWork work) async {
    await Clipboard.setData(ClipboardData(text: work.videoUrl));
    if (mounted) AppSnack.show(context, 'تم نسخ رابط الفيديو');
  }

  void _incrementViews(OurWork work) {
    final id = work.id;
    if (id == null) return;
    context.read<AppState>().repo.incrementWorkViews(id).catchError((error) {
      debugPrint('Failed to record reel view: $error');
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<OurWork>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ReelsMessage(
              icon: Icons.error_outline_rounded,
              title: 'تعذر تحميل الريلز',
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
              title: 'لا توجد ريلز حالياً',
              subtitle: 'ستظهر هنا الفيديوهات التي تنشرها الإدارة.',
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                key: const PageStorageKey('customer-reels'),
                scrollDirection: Axis.vertical,
                itemCount: _works.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _incrementViews(_works[index]);
                },
                itemBuilder: (context, index) => _ReelPage(
                  key: ValueKey(_works[index].id ?? index),
                  work: _works[index],
                  active: index == _currentPage,
                  onLike: () => _toggleLike(index),
                  onComments: () => _openComments(index),
                  onShare: () => _share(_works[index]),
                ),
              ),
              const PositionedDirectional(
                top: 10,
                end: 18,
                child: SafeArea(
                  bottom: false,
                  child: Text(
                    'ريلز',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
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
              Icon(icon, size: 48, color: AppColors.gold),
              const SizedBox(height: 12),
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
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
    required this.onLike,
    required this.onComments,
    required this.onShare,
  });

  final OurWork work;
  final bool active;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onShare;

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;
  bool _muted = true;
  int _initialization = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _initialize();
  }

  @override
  void didUpdateWidget(covariant _ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.work.videoUrl != widget.work.videoUrl) {
      _disposeController();
      _failed = false;
      if (widget.active) _initialize();
      return;
    }
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        if (_controller == null && !_failed) {
          _initialize();
        } else {
          _controller?.play();
        }
      } else {
        _controller?.pause();
      }
    }
  }

  bool get _isDirectVideo {
    final path =
        widget.work.videoUrl.toLowerCase().split('?').first.split('#').first;
    return ['.mp4', '.m3u8', '.webm', '.mov'].any(path.endsWith);
  }

  Future<void> _initialize() async {
    if (!_isDirectVideo || !widget.active || _loading) return;
    final token = ++_initialization;
    final uri = Uri.tryParse(widget.work.videoUrl);
    if (uri == null || !uri.hasScheme) {
      setState(() => _failed = true);
      return;
    }

    setState(() {
      _loading = true;
      _failed = false;
    });
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted || token != _initialization || !widget.active) {
        await controller.dispose();
        return;
      }
      await controller.play();
      setState(() => _loading = false);
    } catch (error) {
      debugPrint('Failed to initialize reel video: $error');
      await controller.dispose();
      if (!mounted || token != _initialization) return;
      _controller = null;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _disposeController() {
    _initialization++;
    final controller = _controller;
    _controller = null;
    if (controller != null) controller.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _toggleSound() async {
    final controller = _controller;
    if (controller == null) return;
    final muted = !_muted;
    await controller.setVolume(muted ? 0 : 1);
    if (mounted) setState(() => _muted = muted);
  }

  @override
  Widget build(BuildContext context) {
    final video = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: video != null && video.value.isInitialized
              ? GestureDetector(
                  onDoubleTap: widget.onLike,
                  onTap: () {
                    if (video.value.isPlaying) {
                      video.pause();
                    } else {
                      video.play();
                    }
                    setState(() {});
                  },
                  child: _CoverVideo(controller: video),
                )
              : Center(
                  child: _failed
                      ? const Padding(
                          padding: EdgeInsets.all(28),
                          child: Text(
                            'تعذر تشغيل الفيديو. تأكد أن الرابط مباشر ويدعم MP4 أو HLS.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: Colors.white70, height: 1.5),
                          ),
                        )
                      : const CircularProgressIndicator(color: AppColors.gold),
                ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
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
                  stops: [0, .45, 1],
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          end: 12,
          bottom: 86,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReelAction(
                icon: widget.work.likedByMe
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: fmtNumber(widget.work.likes),
                color: widget.work.likedByMe ? Colors.redAccent : Colors.white,
                onTap: widget.onLike,
              ),
              const SizedBox(height: 18),
              _ReelAction(
                icon: Icons.mode_comment_outlined,
                label: fmtNumber(widget.work.commentCount),
                onTap: widget.onComments,
              ),
              const SizedBox(height: 18),
              _ReelAction(
                icon: Icons.share_outlined,
                label: 'مشاركة',
                onTap: widget.onShare,
              ),
              if (_isDirectVideo) ...[
                const SizedBox(height: 18),
                IconButton(
                  onPressed: _toggleSound,
                  tooltip: _muted ? 'تشغيل الصوت' : 'كتم الصوت',
                  color: Colors.white,
                  icon: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  ),
                ),
              ],
            ],
          ),
        ),
        PositionedDirectional(
          start: 18,
          end: 76,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.gold,
                    child: Icon(Icons.play_arrow_rounded,
                        color: AppColors.ink, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'جايك',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.verified_rounded,
                      color: Colors.lightBlueAccent, size: 15),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.work.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                ),
              ),
              if (widget.work.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Text(
                  widget.work.description!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.4,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                  ),
                ),
              ],
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(Icons.music_note_rounded,
                      size: 15, color: Colors.white),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${fmtNumber(widget.work.views)} مشاهدة · جايك',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (video != null &&
            video.value.isInitialized &&
            !video.value.isPlaying)
          const IgnorePointer(
            child: Center(
              child: Icon(Icons.play_arrow_rounded,
                  color: Colors.white70, size: 74),
            ),
          ),
        if (video != null && video.value.isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              video,
              allowScrubbing: true,
              padding: EdgeInsets.zero,
              colors: const VideoProgressColors(
                playedColor: AppColors.gold,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
      ],
    );
  }
}

class _CoverVideo extends StatelessWidget {
  const _CoverVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = controller.value.size;
          final width = size.width > 0 ? size.width : 9.0;
          final height = size.height > 0 ? size.height : 16.0;
          return SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: width,
                height: height,
                child: VideoPlayer(controller),
              ),
            ),
          );
        },
      );
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
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: 54,
          child: Column(
            children: [
              Icon(icon, color: color, size: 31, shadows: const [
                Shadow(color: Colors.black54, blurRadius: 7),
              ]),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                ),
              ),
            ],
          ),
        ),
      );
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
  int _count = 0;
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
        _count++;
        _load();
      });
    } catch (error) {
      if (mounted)
        AppSnack.show(context, 'تعذر إرسال التعليق: $error', error: true);
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
                        child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  final comments = snapshot.data!;
                  if (_count == 0) _count = comments.length;
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
              onPressed: () => Navigator.pop(context, _count),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}
