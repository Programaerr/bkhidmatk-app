import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/post_card.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'post_detail_screen.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key, required this.refreshTick, required this.onCreate});

  final int refreshTick;
  final VoidCallback onCreate;

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  late Future<List<Post>> _future;
  int? _categoryId;
  List<Category> _categories = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _load();
  }

  void _load() {
    setState(() {
      _future = context
          .read<AppState>()
          .repo
          .listPosts(categoryId: _categoryId, onlyApproved: true);
    });
    context.read<AppState>().repo.listCategories().then((value) {
      if (mounted) setState(() => _categories = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أعمال الزبائن', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text('أحدث الخدمات التي نشرها الزبائن اليوم',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                AppIconButton(
                  icon: Icons.add_rounded,
                  onTap: widget.onCreate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                _Chip(
                  label: 'الكل',
                  selected: _categoryId == null,
                  onTap: () {
                    _categoryId = null;
                    _load();
                  },
                ),
                for (final c in _categories) ...[
                  const SizedBox(width: 8),
                  _Chip(
                    label: c.name,
                    selected: _categoryId == c.id,
                    onTap: () {
                      _categoryId = c.id;
                      _load();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: FutureBuilder<List<Post>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
                }
                final posts = snapshot.data ?? const <Post>[];
                if (posts.isEmpty) {
                  return EmptyState(
                    icon: Icons.video_library_outlined,
                    title: 'لا توجد أعمال منشورة',
                    subtitle: 'كن أول من ينشر عمل اليوم ويوثّقه بالفيديو.',
                    actionLabel: 'انشر عملك',
                    onAction: widget.onCreate,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => PostCard(
                      post: posts[i],
                      onOpen: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(postId: posts[i].id!),
                          ),
                        );
                        _load();
                      },
                      onLike: () => context
                          .read<AppState>()
                          .repo
                          .toggleLike(posts[i].id!, true),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? AppColors.gold : theme.colorScheme.outline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
