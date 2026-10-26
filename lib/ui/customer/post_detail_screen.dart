import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/media_view.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with RealtimeRefresh<PostDetailScreen> {
  Post? _post;
  List<PostComment> _comments = const [];
  final _comment = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  bool _liked = false;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<AppState>().repo;
    final post = await repo.postById(widget.postId);
    final comments = await repo.commentsForPost(widget.postId);
    if (!mounted) return;
    setState(() {
      _post = post;
      _comments = comments;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty || _post == null) return;
    final user = context.read<AppState>().user!;
    setState(() => _sending = true);
    await context.read<AppState>().repo.addComment(PostComment(
          postId: _post!.id!,
          userId: user.id!,
          userName: user.name,
          body: text,
          createdAt: DateTime.now(),
        ));
    _comment.clear();
    await _load();
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _call(String? phone) async {
    if (phone == null) return;
    if (!await launchUrl(Uri.parse('tel:${phoneForCall(phone)}'))) {
      if (mounted) AppSnack.show(context, 'تعذر فتح تطبيق الاتصال', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AppState>().user;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final post = _post;
    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل العمل')),
        body: const EmptyState(icon: Icons.search_off_rounded, title: 'المنشور غير موجود'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العمل'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (user?.isAdmin ?? false)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: () async {
                final ok = await confirmAction(context,
                    title: 'حذف المنشور؟',
                    message: 'سيتم حذف المنشور وتعليقاته نهائياً.',
                    confirmLabel: 'حذف',
                    danger: true);
                if (!ok) return;
                await context.read<AppState>().repo.deletePost(post.id!);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                children: [
                  if (post.mediaType == 'video' && post.mediaPath != null)
                    InlineVideoPlayer(path: post.mediaPath!, height: 230)
                  else
                    MediaThumb(
                      path: post.mediaPath,
                      type: post.mediaType,
                      height: 210,
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      AvatarCircle(name: post.customerName ?? 'زبون', size: 44),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(post.customerName ?? 'زبون',
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5)),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded, size: 14, color: AppColors.info),
                              ],
                            ),
                            Text('${timeAgo(post.createdAt)} · ${post.location ?? ''}',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                          ],
                        ),
                      ),
                      if (post.customerPhone != null)
                        AppIconButton(
                          icon: Icons.call_outlined,
                          onTap: () => _call(post.customerPhone),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(post.title,
                            style: theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(fmtMoney(post.price),
                            style: const TextStyle(
                                color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(post.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.9)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(post.categoryName ?? 'خدمة',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _liked = !_liked);
                          context.read<AppState>().repo.toggleLike(post.id!, _liked);
                        },
                        icon: Icon(
                          _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 17,
                          color: _liked ? AppColors.danger : null,
                        ),
                        label: Text('${post.likes + (_liked ? 1 : 0)}'),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      Text('التعليقات', style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text('${_comments.length}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: Text('لا توجد تعليقات بعد، كن أول من يعلّق.',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5)),
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
                            const SizedBox(width: 9),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: theme.colorScheme.outline),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(c.userName,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                  color: theme.colorScheme.onSurface)),
                                        ),
                                        Text(timeAgo(c.createdAt),
                                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 9)),
                                        if (user != null &&
                                            (user.isAdmin || user.id == c.userId))
                                          GestureDetector(
                                            onTap: () async {
                                              await context
                                                  .read<AppState>()
                                                  .repo
                                                  .deleteComment(c.id!);
                                              _load();
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.only(right: 6),
                                              child: Icon(Icons.close_rounded, size: 14),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(c.body,
                                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
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
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'اكتب تعليقك...',
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sending ? null : _send,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.ink),
                              )
                            : const Icon(Icons.send_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
