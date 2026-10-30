import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import 'ui.dart';

/// بطاقة عمل في قسم «أعمالنا»: معاينة الفيديو + العنوان + الإحصائيات.
class WorkCard extends StatelessWidget {
  const WorkCard({super.key, required this.work, required this.onOpen});

  final OurWork work;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // معاينة الفيديو
          Container(
            height: 136,
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg - 1),
              ),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF141416), Color(0xFF3A3308)],
              ),
            ),
            child: Stack(
              children: [
                const Center(
                  child: _PlayBadge(),
                ),
                PositionedDirectional(
                  bottom: 10,
                  start: 10,
                  child: _MetaPill(
                    icon: Icons.visibility_outlined,
                    label: fmtNumber(work.views),
                  ),
                ),
                PositionedDirectional(
                  bottom: 10,
                  end: 10,
                  child: _MetaPill(
                    icon: Icons.schedule_rounded,
                    label: fmtDateShort(work.createdAt),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  work.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _StatChip(
                      icon: Icons.favorite_outline_rounded,
                      label: '${fmtNumber(work.likes)} إعجاب',
                    ),
                    _StatChip(
                      icon: Icons.mode_comment_outlined,
                      label: '${fmtNumber(work.commentCount)} تعليق',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gold.withValues(alpha: .92),
      ),
      child: const Icon(Icons.play_arrow_rounded, size: 30, color: AppColors.ink),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurface.withValues(alpha: .55)),
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
