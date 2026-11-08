import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../customer/notifications_screen.dart';
import '../widgets/quick_route.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'admin_more.dart';
import 'admin_shell.dart';
import 'admin_threads.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
    required this.onOpenBookings,
    required this.onOpenWorks,
  });

  final ValueChanged<String?> onOpenBookings;
  final VoidCallback onOpenWorks;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with RealtimeRefresh<AdminDashboard> {
  Future<(AppStats, List<Booking>, int)>? _future;
  int _unread = 0;

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
        final works = await repo.workCount();
        _unread = stats.unreadMessages;
        return (stats, bookings.take(4).toList(), works);
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
          title: tr('لوحة التحكم', 'Dashboard'),
          subtitle: tr('مرحباً ${user.name} · إدارة كاملة للتطبيق', 'Welcome ${user.name} · Full app management'),
          actions: [
            AppIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: tr('الإشعارات', 'Notifications'),
              onTap: () => Navigator.push(
                context,
                QuickRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            AppIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: tr('الرسائل', 'Messages'),
              badge: _unread,
              onTap: () => Navigator.push(
                context,
                QuickRoute(builder: (_) => const AdminThreadsScreen()),
              ).then((_) => _load()),
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<(AppStats, List<Booking>, int)>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.4));
              }
              final stats =
                  snapshot.data?.$1 ?? const AppStats(weekly: <RevenuePoint>[]);
              final bookings = snapshot.data?.$2 ?? const <Booking>[];
              final works = snapshot.data?.$3 ?? 0;
              return RefreshIndicator(
                onRefresh: () async => _load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 26),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        color: const Color(0xFF17171B),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(tr('إيرادات آخر 7 أيام', 'Revenue, last 7 days'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 10.5)),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: .16),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.trending_up_rounded,
                                        color: AppColors.gold, size: 12),
                                    SizedBox(width: 3),
                                    Text(tr('نشط', 'Active'),
                                        style: TextStyle(
                                            color: AppColors.gold,
                                            fontSize: 8.5)),
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
                          label: tr('حجوزات اليوم', "Today's bookings"),
                          value: '${stats.bookingsToday}',
                          icon: Icons.event_available_rounded,
                          onTap: () => widget.onOpenBookings(null),
                        ),
                        StatTile(
                          label: tr('طلبات بانتظار موافقتك', 'Requests awaiting your approval'),
                          value: '${stats.pending}',
                          icon: Icons.pending_actions_rounded,
                          color: const Color(0xFFF59E0B),
                          onTap: () => widget.onOpenBookings(BookingStatus.pending),
                        ),
                        StatTile(
                          label: tr('الزبائن', 'Customers'),
                          value: '${stats.customers}',
                          icon: Icons.people_alt_rounded,
                          color: AppColors.info,
                          onTap: () => Navigator.push(
                            context,
                            QuickRoute(
                                builder: (_) => const AdminCustomersScreen()),
                          ),
                        ),
                        StatTile(
                          label: tr('أعمالنا', 'Our work'),
                          value: '$works',
                          icon: Icons.video_library_rounded,
                          color: AppColors.violet,
                          onTap: widget.onOpenWorks,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SectionHeader(
                      title: tr('أحدث الحجوزات', 'Latest bookings'),
                      actionLabel: tr('إدارة الكل', 'Manage all'),
                      onAction: () => widget.onOpenBookings(null),
                    ),
                    if (bookings.isEmpty)
                      SoftCard(
                        child: Text(tr('لا توجد حجوزات بعد.', 'No bookings yet.'),
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center),
                      )
                    else
                      for (final b in bookings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SoftCard(
                            padding: const EdgeInsets.all(12),
                            onTap: () => widget.onOpenBookings(null),
                            child: Row(
                              children: [
                                AvatarCircle(
                                    name: b.customerName ?? tr('زبون', 'Customer'), size: 38),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(b.customerName ?? tr('زبون', 'Customer'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(fontSize: 12.5)),
                                      Text(
                                        tr('${b.serviceTitle ?? 'خدمة'} · ${fmtSlot(b.slot)}', "${b.serviceTitle ?? 'Service'} · ${fmtSlot(b.slot)}"),
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
                                    Text(bookingPriceLabel(b),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 10.5,
                                                color: theme
                                                    .colorScheme.onSurface)),
                                    const SizedBox(height: 3),
                                    StatusPill(status: b.status, dense: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
    final max =
        points.map((e) => e.value).fold<double>(1000, (a, b) => a > b ? a : b);
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
                      color: p.value > 0 ? AppColors.gold : Colors.white24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      tr('إث', 'Mon'),
                      tr('ثل', 'Tue'),
                      tr('أر', 'Wed'),
                      tr('خم', 'Thu'),
                      tr('جم', 'Fri'),
                      tr('سب', 'Sat'),
                      tr('أح', 'Sun')
                    ][p.day.weekday % 7],
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 8.5),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
