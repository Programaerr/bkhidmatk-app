import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import 'media_view.dart';
import 'ui.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onOpen,
    this.onLike,
    this.onDelete,
    this.onApprove,
    this.isAdmin = false,
  });

  final Post post;
  final VoidCallback? onOpen;
  final VoidCallback? onLike;
  final VoidCallback? onDelete;
  final VoidCallback? onApprove;
  final bool isAdmin;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _liked = false;
  late int _likes = widget.post.likes;

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    widget.onLike?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final post = widget.post;
    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: widget.onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                AvatarCircle(name: post.customerName ?? 'زبون', size: 38),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.customerName ?? 'زبون',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 13, color: AppColors.info),
                        ],
                      ),
                      Text('${timeAgo(post.createdAt)} · ${post.location ?? 'العراق'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                    ],
                  ),
                ),
                if (widget.isAdmin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded, size: 20),
                    onSelected: (v) {
                      if (v == 'approve') widget.onApprove?.call();
                      if (v == 'delete') widget.onDelete?.call();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'approve',
                        child: Text(post.approved ? 'إخفاء المنشور' : 'اعتماد المنشور'),
                      ),
                      const PopupMenuItem(value: 'delete', child: Text('حذف المنشور')),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      post.categoryName ?? 'خدمة',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: MediaThumb(
              path: post.mediaPath,
              type: post.mediaType,
              height: 185,
              onTap: widget.onOpen,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 14.5),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    fmtMoney(post.price),
                    style: const TextStyle(
                        color: AppColors.gold, fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 4, 13, 0),
            child: Text(
              post.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
            child: Row(
              children: [
                _Action(
                  icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: fmtNumber(_likes),
                  color: _liked ? AppColors.danger : null,
                  onTap: _toggleLike,
                ),
                _Action(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: fmtNumber(post.commentCount),
                  onTap: widget.onOpen,
                ),
                const Spacer(),
                if (!post.approved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text('بانتظار الاعتماد',
                        style: TextStyle(
                            fontSize: 9.5, color: AppColors.danger, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? theme.colorScheme.onSurface.withValues(alpha: .7)),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color ?? theme.colorScheme.onSurface,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
