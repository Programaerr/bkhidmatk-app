import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/media_view.dart';
import '../widgets/ui.dart';

/// تفاصيل عمل من قسم «أعمالنا»: الفيديو + المشاهدات + الإعجاب + التعليق + المشاركة.
class OurWorkDetailScreen extends StatefulWidget {
  const OurWorkDetailScreen({super.key, required this.workId});

  final int workId;

  @override
  State<OurWorkDetailScreen> createState() => _OurWorkDetailScreenState();
}

class _OurWorkDetailScreenState extends State<OurWorkDetailScreen> {
  final _comment = TextEditingController();
  OurWork? _work;
  List<WorkComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    // زيادة عدّاد المشاهدات عند فتح التفاصيل.
    await context.read<AppState>().repo.incrementWorkViews(widget.workId);
    await _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final results = await Future.wait([
      state.repo.workById(widget.workId, viewerId: state.user?.id),
      state.repo.workComments(widget.workId),
    ]);
    if (!mounted) return;
    setState(() {
      _work = results[0] as OurWork?;
      _comments = results[1] as List<WorkComment>;
      _loading = false;
    });
  }

  Future<void> _toggleLike() async {
    final state = context.read<AppState>();
    final work = _work;
    final userId = state.user?.id;
    if (work == null || work.id == null || userId == null) return;
    await state.repo.setWorkLike(
      work.id!,
      userId: userId,
      liked: !work.likedByMe,
    );
    await _load();
  }

  Future<void> _share() async {
    final url = _work?.videoUrl;
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) AppSnack.show(context, 'تم نسخ رابط الفيديو للمشاركة');
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    final state = context.read<AppState>();
    final user = state.user;
    final work = _work;
    if (text.isEmpty || work == null || work.id == null || user?.id == null) return;
    setState(() => _sending = true);
    await state.repo.addWorkComment(WorkComment(
      workId: work.id!,
      userId: user!.id!,
      userName: user.name,
      body: text,
      createdAt: DateTime.now(),
    ));
    _comment.clear();
    await _load();
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _openExternal() async {
    final url = _work?.videoUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) AppSnack.show(context, 'تعذر فتح الرابط', error: true);
    }
  }

  static bool _isDirectVideo(String url) {
    final u = url.toLowerCase().split('?').first.split('#').first;
    return u.endsWith('.mp4') ||
        u.endsWith('.m3u8') ||
        u.endsWith('.webm') ||
        u.endsWith('.mov') ||
        u.endsWith('.mkv') ||
        u.endsWith('.avi');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final work = _work;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    } else if (work == null) {
      body = const EmptyState(
        icon: Icons.video_library_outlined,
        title: 'العمل غير متاح',
        subtitle: 'تم حذف هذا العمل من قبل إدارة جايك.',
      );
    } else {
      body = Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                children: [
                  // ------------------------------------------------ الفيديو
                  if (_isDirectVideo(work.videoUrl))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: InlineVideoPlayer(path: work.videoUrl, height: 210),
                    )
                  else
                    Container(
                      height: 172,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        gradient: const LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [Color(0xFF141416), Color(0xFF3A3308)],
                        ),
                      ),
                      child: Stack(
                        children: [
                          const Center(
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              size: 56,
                              color: AppColors.gold,
                            ),
                          ),
                          PositionedDirectional(
                            bottom: 8,
                            start: 0,
                            end: 0,
                            child: Center(
                              child: TextButton.icon(
                                onPressed: _openExternal,
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 15, color: Colors.white),
                                label: const Text(
                                  'فتح الفيديو',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),

                  // ------------------------------------------------ العنوان
                  Text(
                    work.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w900,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 14,
                    runSpacing: 5,
                    children: [
                      _MetaText(
                        icon: Icons.visibility_outlined,
                        label: '${fmtNumber(work.views)} مشاهدة',
                      ),
                      _MetaText(
                        icon: Icons.favorite_outline_rounded,
                        label: '${fmtNumber(work.likes)} إعجاب',
                      ),
                      _MetaText(
                        icon: Icons.mode_comment_outlined,
                        label: '${fmtNumber(work.commentCount)} تعليق',
                      ),
                      _MetaText(
                        icon: Icons.calendar_today_outlined,
                        label: fmtDate(work.createdAt),
                      ),
                    ],
                  ),
                  if (work.description != null &&
                      work.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      work.description!.trim(),
                      style: const TextStyle(fontSize: 12.5, height: 1.8),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // --------------------------------------------- التفاعل
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _toggleLike,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                work.likedByMe
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_outline_rounded,
                                size: 17,
                                color: work.likedByMe
                                    ? AppColors.danger
                                    : theme.colorScheme.onSurface,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${work.likedByMe ? 'أعجبتني' : 'إعجاب'} · ${fmtNumber(work.likes)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _share,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.share_rounded, size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'مشاركة',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // --------------------------------------------- التعليقات
                  SectionHeader(title: 'التعليقات (${_comments.length})'),
                  const SizedBox(height: 6),
                  if (_comments.isEmpty)
                    const SoftCard(
                      child: Text(
                        'لا توجد تعليقات بعد — كن أول من يعلّق.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                  else
                    for (final c in _comments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AvatarCircle(name: c.userName, size: 34),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          c.userName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        timeAgo(c.createdAt),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(fontSize: 9.5),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.body,
                                    style: const TextStyle(
                                        fontSize: 12.5, height: 1.6),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),

          // --------------------------------------------- شريط كتابة تعليق
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outline),
              ),
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
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'اكتب تعليقاً...',
                        hintStyle: const TextStyle(fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              BorderSide(color: theme.colorScheme.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: AppColors.gold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      onPressed: _sending ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.ink,
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: AppColors.ink),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('أعمالنا'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 13, color: theme.colorScheme.onSurface.withValues(alpha: .55)),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10.5,
            color: theme.colorScheme.onSurface.withValues(alpha: .7),
          ),
        ),
      ],
    );
  }
}
