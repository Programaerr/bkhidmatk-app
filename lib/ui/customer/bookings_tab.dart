import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'booking_detail_screen.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key, required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  int _filter = 0;
  late Future<List<Booking>> _future;

  static const _filters = ['الكل', 'القادمة', 'المكتملة', 'الملغاة'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final user = context.read<AppState>().user;
    if (user?.id == null) return;
    setState(() {
      _future = context.read<AppState>().repo.bookingsForCustomer(user!.id!);
    });
  }

  List<Booking> _apply(List<Booking> all) {
    switch (_filter) {
      case 1:
        return all
            .where((b) =>
                b.status == BookingStatus.pending ||
                b.status == BookingStatus.confirmed ||
                b.status == BookingStatus.inProgress)
            .toList();
      case 2:
        return all.where((b) => b.status == BookingStatus.completed).toList();
      case 3:
        return all.where((b) => b.status == BookingStatus.cancelled).toList();
      default:
        return all;
    }
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
                      Text('حجوزاتي', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text('تابع كل حجوزاتك ووصولاتك من مكان واحد',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                AppIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: _load,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = i == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.gold : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: selected ? AppColors.gold : theme.colorScheme.outline),
                    ),
                    child: Text(
                      _filters[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<List<Booking>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
                }
                final bookings = _apply(snapshot.data ?? const []);
                if (bookings.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_note_rounded,
                    title: 'لا توجد حجوزات هنا',
                    subtitle: 'احجز خدمتك الأولى واستمتع بفنيين موثوقين.',
                    actionLabel: 'تصفح الخدمات',
                    onAction: widget.onBrowse,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                    itemCount: bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _BookingCard(
                      booking: bookings[i],
                      onChanged: _load,
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onChanged});

  final Booking booking;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      padding: const EdgeInsets.all(13),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: booking.id!)),
        );
        onChanged();
      },
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.home_repair_service_rounded, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceTitle ?? 'خدمة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${fmtDate(booking.scheduledAt)} · ${fmtSlot(booking.slot)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              StatusPill(status: booking.status, dense: true),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
          Row(
            children: [
              Icon(Icons.engineering_rounded,
                  size: 15, color: theme.colorScheme.onSurface.withValues(alpha: .5)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  booking.workerName ?? 'سيتم تعيين الفني',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                ),
              ),
              Text(fmtMoney(booking.total),
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 12.5)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_left_rounded, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}
