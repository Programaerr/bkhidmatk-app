import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import '../widgets/work_card.dart';
import 'booking_detail_screen.dart';
import 'messages_screen.dart';
import 'our_work_detail_screen.dart';
import 'service_detail_screen.dart';
import 'services_tab.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.onBrowseServices,
    required this.onOpenWorks,
    required this.onOpenBookings,
  });

  final VoidCallback onBrowseServices;
  final VoidCallback onOpenWorks;
  final VoidCallback onOpenBookings;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with RealtimeRefresh<HomeTab> {
  Future<_HomeData>? _future;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final state = context.read<AppState>();
    final user = state.user!;
    setState(() {
      _future = _fetch(state.repo, user.id!);
    });
  }

  Future<_HomeData> _fetch(Repository repo, int userId) async {
    final results = await Future.wait([
      repo.listCategories(),
      repo.listServices(limit: 6),
      repo.listWorks(onlyActive: true, limit: 3, viewerId: userId),
      repo.bookingsForCustomer(userId),
      repo.unreadForCustomer(userId),
      // البانر الرئيسي أصبح خياراً يتحكم به المدير من لوحة التحكم.
      repo.getSetting('show_hero_banner', fallback: '0'),
    ]);
    final bookings = results[3] as List<Booking>;
    final upcoming = bookings
        .where((b) =>
            b.status == BookingStatus.pending ||
            b.status == BookingStatus.confirmed ||
            b.status == BookingStatus.inProgress)
        .toList();
    upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return _HomeData(
      categories: results[0] as List<Category>,
      services: results[1] as List<Service>,
      works: results[2] as List<OurWork>,
      upcoming: upcoming.isEmpty ? null : upcoming.first,
      unread: results[4] as int,
      showHero: results[5] == '1',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AppState>().user!;
    return SafeArea(
      bottom: false,
      child: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
              children: [
                Row(
                  children: [
                    const BrandLogo(size: 44, radius: 13),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('أهلاً، ${user.name.split(' ').first} 👋',
                              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16)),
                          Text('كيف نقدر نخدمك اليوم؟',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      badge: data?.unread ?? 0,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MessagesScreen()),
                        );
                        _load();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ServicesPage()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            size: 22, color: theme.colorScheme.onSurface.withValues(alpha: .5)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('ابحث عن كهربائي، صباغ، تصليح غسالات...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ),
                ),
                if (data?.showHero ?? false) ...[
                  const SizedBox(height: 16),
                  _HeroBanner(onTap: widget.onBrowseServices),
                ],
                const SizedBox(height: 20),
                SectionHeader(
                  title: 'الأقسام',
                  actionLabel: 'عرض الكل',
                  onAction: widget.onBrowseServices,
                ),
                if (data == null)
                  const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                  )
                else
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 6,
                    childAspectRatio: .78,
                    children: [
                      for (final c in data.categories.take(8))
                        IconTile(
                          icon: appIcon(c.icon),
                          label: c.name,
                          color: Color(c.color),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServicesPage(initialCategoryId: c.id),
                            ),
                          ),
                        ),
                    ],
                  ),
                if (data?.upcoming != null) ...[
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: 'حجزك القادم',
                    actionLabel: 'كل الحجوزات',
                    onAction: widget.onOpenBookings,
                  ),
                  SoftCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            BookingDetailScreen(bookingId: data.upcoming!.id!),
                      ),
                    ).then((_) => _load()),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.event_available_rounded, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data!.upcoming!.serviceTitle ?? 'خدمة',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5)),
                              Text(
                                '${fmtDate(data.upcoming!.scheduledAt)} · ${fmtSlot(data.upcoming!.slot)}',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        StatusPill(status: data.upcoming!.status, dense: true),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'الأكثر طلباً',
                  subtitle: 'خدمات مختارة بعناية',
                  actionLabel: 'عرض الكل',
                  onAction: widget.onBrowseServices,
                ),
                if (data == null)
                  const SizedBox(height: 180)
                else
                  SizedBox(
                    height: 196,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: data.services.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) =>
                          _ServiceMiniCard(service: data.services[i]),
                    ),
                  ),
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'أحدث أعمالنا',
                  subtitle: 'فيديوهات موثّقة من فريق جايك',
                  actionLabel: 'عرض الكل',
                  onAction: widget.onOpenWorks,
                ),
                if (data == null)
                  const SizedBox(height: 100)
                else if (data.works.isEmpty)
                  SoftCard(
                    child: Column(
                      children: [
                        const Icon(Icons.video_library_outlined, size: 26),
                        const SizedBox(height: 6),
                        Text('لا توجد أعمال منشورة بعد',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                      ],
                    ),
                  )
                else
                  for (final work in data.works)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: WorkCard(
                        work: work,
                        onOpen: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OurWorkDetailScreen(workId: work.id!),
                          ),
                        ).then((_) => _load()),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.categories,
    required this.services,
    required this.works,
    required this.upcoming,
    required this.unread,
    required this.showHero,
  });

  final List<Category> categories;
  final List<Service> services;
  final List<OurWork> works;
  final Booking? upcoming;
  final int unread;

  /// هل البانر الرئيسي مفعّل من لوحة التحكم؟
  final bool showHero;
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 158,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF0C0C0E), Color(0xFF3B3408)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -30,
              top: -50,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: .12),
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 18,
              child: SizedBox(
                width: 140,
                height: 140,
                child: Opacity(
                  opacity: .9,
                  child: Image.asset('assets/images/logo.jpg',
                      fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
            ),
            Positioned(
              top: 18,
              right: 18,
              left: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text('عرض هذا الأسبوع',
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.ink)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'خصم 15% على\nتصليح الغسالات',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('احجز الآن',
                                  style: TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.ink)),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_left_rounded, size: 14, color: AppColors.ink),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('لفترة محدودة',
                            style: TextStyle(color: Colors.white54, fontSize: 8.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceMiniCard extends StatelessWidget {
  const _ServiceMiniCard({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(service.categoryColor ?? 0xFFFFD400);
    return SizedBox(
      width: 168,
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: service)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 62,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: .28), color.withValues(alpha: .08)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.handyman_rounded, color: color, size: 26),
            ),
            const SizedBox(height: 9),
            Text(service.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontSize: 12.5, height: 1.4)),
            const Spacer(),
            Row(
              children: [
                Text(fmtMoney(service.price),
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 11.5)),
                const Spacer(),
                const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF5A623)),
                Text(service.rating.toStringAsFixed(1),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
