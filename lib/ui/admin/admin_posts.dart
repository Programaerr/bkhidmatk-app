import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../customer/messages_screen.dart';
import '../customer/post_detail_screen.dart';
import '../widgets/post_card.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'admin_shell.dart';

class AdminPosts extends StatefulWidget {
  const AdminPosts({super.key, required this.refreshTick});

  final int refreshTick;

  @override
  State<AdminPosts> createState() => _AdminPostsState();
}

class _AdminPostsState extends State<AdminPosts> {
  int _filter = 0; // 0 all, 1 pending, 2 approved
  final _search = TextEditingController();
  String _query = '';
  late Future<List<Post>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminPosts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().repo.listPosts(
            onlyApproved: false,
            query: _query,
          );
    });
  }

  List<Post> _apply(List<Post> all) {
    switch (_filter) {
      case 1:
        return all.where((p) => !p.approved).toList();
      case 2:
        return all.where((p) => p.approved).toList();
      default:
        return all;
    }
  }

  Future<void> _toggle(Post post) async {
    await context.read<AppState>().repo.approvePost(post.id!, !post.approved);
    _load();
  }

  Future<void> _delete(Post post) async {
    final ok = await confirmAction(
      context,
      title: 'حذف المنشور؟',
      message: 'سيتم حذف «${post.title}» وتعليقاته نهائياً.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok) return;
    await context.read<AppState>().repo.deletePost(post.id!);
    if (mounted) AppSnack.show(context, 'تم حذف المنشور');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labels = ['الكل', 'بانتظار الاعتماد', 'معتمدة'];
    return Column(
      children: [
        AdminHeader(
          title: 'أعمال الزبائن',
          subtitle: 'اعتمد أو احذف المنشورات المرسلة من الزبائن',
          actions: [AppIconButton(icon: Icons.refresh_rounded, onTap: _load)],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: TextField(
            controller: _search,
            onChanged: (v) {
              _query = v;
              _load();
            },
            decoration: const InputDecoration(
              hintText: 'ابحث في المنشورات...',
              prefixIcon: Icon(Icons.search_rounded, size: 21),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SegmentedTabs(
            values: labels,
            index: _filter,
            onChanged: (i) => setState(() => _filter = i),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<Post>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
              }
              final posts = _apply(snapshot.data ?? const <Post>[]);
              if (posts.isEmpty) {
                return const EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'لا توجد منشورات',
                  subtitle: 'ستظهر هنا أعمال الزبائن المنشورة من التطبيق.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _load(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = posts[i];
                    return Column(
                      children: [
                        PostCard(
                          post: p,
                          isAdmin: true,
                          onOpen: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PostDetailScreen(postId: p.id!)),
                          ).then((_) => _load()),
                          onApprove: () => _toggle(p),
                          onDelete: () => _delete(p),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _toggle(p),
                                  icon: Icon(
                                    p.approved
                                        ? Icons.visibility_off_outlined
                                        : Icons.verified_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    p.approved ? 'إخفاء المنشور' : 'اعتماد المنشور',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 40),
                                    foregroundColor: p.approved
                                        ? theme.colorScheme.onSurface
                                        : AppColors.success,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _delete(p),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                  label: const Text('حذف',
                                      style: TextStyle(fontSize: 11.5)),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 40),
                                    foregroundColor: AppColors.danger,
                                    side: BorderSide(
                                        color: AppColors.danger.withValues(alpha: .35)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Admin inbox: one row per customer conversation.
class AdminThreadsScreen extends StatefulWidget {
  const AdminThreadsScreen({super.key});

  @override
  State<AdminThreadsScreen> createState() => _AdminThreadsScreenState();
}

class _AdminThreadsScreenState extends State<AdminThreadsScreen> {
  late Future<List<ChatThread>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().repo.messageThreads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرسائل'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: SafeArea(
        child: FutureBuilder<List<ChatThread>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
            }
            final threads = snapshot.data ?? const <ChatThread>[];
            if (threads.isEmpty) {
              return const EmptyState(
                icon: Icons.forum_outlined,
                title: 'لا توجد محادثات',
                subtitle: 'ستظهر هنا رسائل الزبائن فور إرسالها.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final t = threads[i];
                return SoftCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessagesScreen(
                          threadId: t.customerId,
                          threadName: t.customerName,
                          threadPhone: t.customerPhone,
                        ),
                      ),
                    );
                    _load();
                  },
                  child: Row(
                    children: [
                      AvatarCircle(name: t.customerName, size: 44),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.customerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  timeAgo(t.lastAt),
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontSize: 9.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(fontSize: 10.5),
                                  ),
                                ),
                                if (t.unread > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      '${t.unread}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
