import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../common/receipt_document.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'admin_shell.dart';

class AdminBookings extends StatefulWidget {
  const AdminBookings({super.key, this.initialFilter, required this.refreshTick});

  final String? initialFilter;
  final int refreshTick;

  @override
  State<AdminBookings> createState() => _AdminBookingsState();
}

class _AdminBookingsState extends State<AdminBookings>
    with RealtimeRefresh<AdminBookings> {
  String? _status;
  String _query = '';
  final _search = TextEditingController();
  late Future<List<Booking>> _future;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _status = widget.initialFilter;
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminBookings oldWidget) {
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
      _future = context
          .read<AppState>()
          .repo
          .allBookings(status: _status, query: _query);
    });
  }

  Future<void> _openBooking(Booking booking) async {
    await showAppSheet<bool>(
      context,
      builder: (_) => _BookingSheet(bookingId: booking.id!),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = <(String?, String)>[
      (null, 'الكل'),
      (BookingStatus.pending, 'جديد'),
      (BookingStatus.confirmed, 'مؤكد'),
      (BookingStatus.inProgress, 'قيد التنفيذ'),
      (BookingStatus.completed, 'مكتمل'),
      (BookingStatus.cancelled, 'ملغي'),
    ];
    return Column(
      children: [
        AdminHeader(
          title: 'إدارة الحجوزات',
          subtitle: 'متابعة وتحديث حالة كل حجز',
          actions: [
            AppIconButton(icon: Icons.refresh_rounded, onTap: _load),
          ],
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
              hintText: 'ابحث باسم الزبون، الرقم، أو الخدمة...',
              prefixIcon: Icon(Icons.search_rounded, size: 21),
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, i) {
              final selected = _status == filters[i].$1;
              return GestureDetector(
                onTap: () {
                  _status = filters[i].$1;
                  _load();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.gold : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: selected ? AppColors.gold : theme.colorScheme.outline),
                  ),
                  child: Text(filters[i].$2,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<Booking>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
              }
              final bookings = snapshot.data ?? const <Booking>[];
              if (bookings.isEmpty) {
                return const EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'لا توجد حجوزات',
                  subtitle: 'ستظهر الحجوزات الجديدة هنا مباشرة.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _load(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
                  itemCount: bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, i) {
                    final b = bookings[i];
                    return SoftCard(
                      padding: const EdgeInsets.all(12),
                      onTap: () => _openBooking(b),
                      child: Column(
                        children: [
                          Row(
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
                                    Text(b.customerPhone ?? '',
                                        textDirection: TextDirection.ltr,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(fontSize: 9.5)),
                                  ],
                                ),
                              ),
                              StatusPill(status: b.status, dense: true),
                            ],
                          ),
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 9), child: Divider()),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.serviceTitle ?? 'خدمة',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${fmtDateShort(b.scheduledAt)} · ${fmtSlot(b.slot)} · #${b.id}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(fontSize: 9.5),
                                    ),
                                  ],
                                ),
                              ),
                              Text(fmtMoney(b.total),
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontSize: 11.5)),
                            ],
                          ),
                        ],
                      ),
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

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({required this.bookingId});

  final int bookingId;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  Booking? _booking;
  Receipt? _receipt;
  List<Worker> _workers = const [];
  bool _loading = true;
  bool _working = false;

  Repository get _repo => context.read<AppState>().repo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final booking = await _repo.bookingById(widget.bookingId);
    final receipt = await _repo.receiptForBooking(widget.bookingId);
    final workers = booking == null
        ? <Worker>[]
        : await _repo.listWorkers();
    if (!mounted) return;
    setState(() {
      _booking = booking;
      _receipt = receipt;
      _workers = workers;
      _loading = false;
    });
  }

  Future<void> _setStatus(String status) async {
    setState(() => _working = true);
    await _repo.updateBookingStatus(widget.bookingId, status);
    await _load();
    if (mounted) setState(() => _working = false);
  }

  Future<void> _assign() async {
    final picked = await showAppSheet<int>(
      context,
      builder: (ctx) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 430),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: SheetHeader(title: 'تعيين فني'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final w in _workers)
                    ListTile(
                      leading: AvatarCircle(name: w.name, size: 38),
                      title: Text(w.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(w.specialty,
                          style: const TextStyle(fontSize: 10)),
                      trailing: w.available
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 18)
                          : const Icon(Icons.block_rounded,
                              color: AppColors.danger, size: 18),
                      onTap: () => Navigator.pop(ctx, w.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await _repo.assignWorker(widget.bookingId, picked);
      await _load();
    }
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
    final b = _booking;
    return SafeArea(
      top: false,
      child: _loading || b == null
          ? const SizedBox(
              height: 240, child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarCircle(name: b.customerName ?? 'زبون', size: 48),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.customerName ?? 'زبون',
                                style: theme.textTheme.titleMedium?.copyWith(fontSize: 15)),
                            Text(b.customerPhone ?? '',
                                textDirection: TextDirection.ltr,
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                          ],
                        ),
                      ),
                      AppIconButton(
                        icon: Icons.call_outlined,
                        onTap: () => _call(b.customerPhone),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      StatusPill(status: b.status),
                      const Spacer(),
                      Text('حجز #${b.id}',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SoftCard(
                    child: Column(
                      children: [
                        InfoRow(
                            icon: Icons.home_repair_service_rounded,
                            label: 'الخدمة',
                            value: b.serviceTitle),
                        InfoRow(
                          icon: Icons.calendar_month_rounded,
                          label: 'الموعد',
                          value: '${fmtDate(b.scheduledAt)} · ${fmtSlot(b.slot)}',
                        ),
                        InfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'العنوان',
                            value: b.address),
                        if (b.notes != null && b.notes!.isNotEmpty)
                          InfoRow(
                              icon: Icons.notes_rounded, label: 'ملاحظات', value: b.notes),
                        InfoRow(
                          icon: Icons.payments_outlined,
                          label: 'الدفع',
                          value: b.paymentMethod == 'card'
                              ? 'ماستركارد · ${_receipt?.last4 ?? ''}'
                              : 'عند الوصول',
                          trailing: Text(fmtMoney(b.total),
                              style: theme.textTheme.titleSmall?.copyWith(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        AvatarCircle(name: b.workerName ?? 'غير معين', size: 38),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.workerName ?? 'لم يتم تعيين فني',
                                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 12)),
                              Text('الفني المسؤول',
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _assign,
                          child: const Text('تغيير', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  if (_receipt != null) ...[
                    const SizedBox(height: 10),
                    SoftCard(
                      padding: const EdgeInsets.all(12),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ReceiptPreviewScreen(receipt: _receipt!)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_receipt!.invoiceNo} · ${_receipt!.paid ? 'مدفوع' : 'غير مدفوع'}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          IconButton(
                            onPressed: () => ReceiptActions.print(context, _receipt!),
                            icon: const Icon(Icons.print_rounded, size: 19),
                          ),
                          const Icon(Icons.chevron_left_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('تحديث الحالة',
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (b.status == BookingStatus.pending)
                        _StatusAction(
                          label: 'تأكيد الحجز',
                          icon: Icons.verified_rounded,
                          color: AppColors.info,
                          onTap: () => _setStatus(BookingStatus.confirmed),
                        ),
                      if (b.status == BookingStatus.confirmed)
                        _StatusAction(
                          label: 'بدء التنفيذ',
                          icon: Icons.play_arrow_rounded,
                          color: AppColors.violet,
                          onTap: () => _setStatus(BookingStatus.inProgress),
                        ),
                      if (b.status == BookingStatus.inProgress)
                        _StatusAction(
                          label: 'إكمال الحجز',
                          icon: Icons.done_all_rounded,
                          color: AppColors.success,
                          onTap: () => _setStatus(BookingStatus.completed),
                        ),
                      if (b.status != BookingStatus.completed &&
                          b.status != BookingStatus.cancelled)
                        _StatusAction(
                          label: 'إلغاء',
                          icon: Icons.close_rounded,
                          color: AppColors.danger,
                          onTap: () => _setStatus(BookingStatus.cancelled),
                        ),
                    ],
                  ),
                  if (_working)
                    const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatusAction extends StatelessWidget {
  const _StatusAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}
