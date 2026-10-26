import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'admin_posts.dart';
import 'admin_shell.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
    required this.onOpenBookings,
    required this.onOpenMessages,
    required this.onOpenPosts,
  });

  final VoidCallback onOpenBookings;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenPosts;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with RealtimeRefresh<AdminDashboard> {
  Future<(AppStats, List<Booking>, int)>? _future;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<AppState>().repo;
    setState(() {
      _future = () async {
        final stats = await repo.stats();
        final bookings = await repo.allBookings();
        final pendingPosts = await repo.pendingPostsCount();
        return (stats, bookings.take(4).toList(), pendingPosts);
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AppState>().user!;
    return Column(
      children: [
        AdminHeader(
          title: 'لوحة التحكم',
          subtitle: 'مرحباً ${user.name} · إدارة كاملة للتطبيق',
          actions: [
            AppIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              badge: 0,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminThreadsScreen()),
              ).then((_) => _load()),
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<(AppStats, List<Booking>, int)>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
              }
              final stats = snapshot.data?.$1 ??
                  const AppStats(weekly: <RevenuePoint>[]);
              final bookings = snapshot.data?.$2 ?? const <Booking>[];
              final pendingPosts = snapshot.data?.$3 ?? 0;
              return RefreshIndicator(
                onRefresh: () async => _load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 26),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        gradient: const LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [Color(0xFF111113), Color(0xFF38310A)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('إيرادات آخر 7 أيام',
                                  style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                              const Spacer(),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: .16),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.trending_up_rounded,
                                        color: AppColors.gold, size: 12),
                                    SizedBox(width: 3),
                                    Text('نشط',
                                        style: TextStyle(
                                            color: AppColors.gold, fontSize: 8.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(fmtMoney(stats.revenue),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              )),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 92,
                            child: _WeeklyChart(points: stats.weekly),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.65,
                      children: [
                        StatTile(
                          label: 'حجوزات اليوم',
                          value: '${stats.bookingsToday}',
                          icon: Icons.event_available_rounded,
                          onTap: widget.onOpenBookings,
                        ),
                        StatTile(
                          label: 'بانتظار التأكيد',
                          value: '${stats.pending}',
                          icon: Icons.pending_actions_rounded,
                          color: const Color(0xFFF59E0B),
                          onTap: widget.onOpenBookings,
                        ),
                        StatTile(
                          label: 'الزبائن',
                          value: '${stats.customers}',
                          icon: Icons.people_alt_rounded,
                          color: AppColors.info,
                        ),
                        StatTile(
                          label: 'أعمال بانتظار الاعتماد',
                          value: '$pendingPosts',
                          icon: Icons.video_settings_rounded,
                          color: AppColors.violet,
                          onTap: widget.onOpenPosts,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SectionHeader(
                      title: 'أحدث الحجوزات',
                      actionLabel: 'إدارة الكل',
                      onAction: widget.onOpenBookings,
                    ),
                    if (bookings.isEmpty)
                      const SoftCard(
                        child: Text('لا توجد حجوزات بعد.',
                            style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
                      )
                    else
                      for (final b in bookings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SoftCard(
                            padding: const EdgeInsets.all(12),
                            onTap: widget.onOpenBookings,
                            child: Row(
                              children: [
                                AvatarCircle(name: b.customerName ?? 'زبون', size: 38),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(b.customerName ?? 'زبون',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(fontSize: 12.5)),
                                      Text(
                                        '${b.serviceTitle ?? 'خدمة'} · ${fmtSlot(b.slot)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(fmtMoney(b.total),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10.5,
                                            color: theme.colorScheme.onSurface)),
                                    const SizedBox(height: 3),
                                    StatusPill(status: b.status, dense: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    const SizedBox(height: 18),
                    const SectionHeader(title: 'إجراءات سريعة'),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.event_note_rounded,
                            label: 'الحجوزات',
                            onTap: widget.onOpenBookings,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.video_library_rounded,
                            label: 'الأعمال',
                            onTap: widget.onOpenPosts,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.support_agent_rounded,
                            label: 'الرسائل',
                            onTap: widget.onOpenMessages,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.points});

  final List<RevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox();
    final max = points.map((e) => e.value).fold<double>(1000, (a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final p in points)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 8 + (70 * (p.value / max)).clamp(0, 70).toDouble(),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: p.value > 0
                            ? [AppColors.gold, AppColors.gold.withValues(alpha: .35)]
                            : [Colors.white24, Colors.white10],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'][p.day.weekday % 7],
                    style: const TextStyle(color: Colors.white38, fontSize: 8.5),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19),
          ),
          const SizedBox(height: 7),
          Text(label,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
