import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../auth/push_key.dart';
import '../common/receipt_document.dart';
import '../widgets/quick_route.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'admin_shell.dart';

/// طلب من خارج التبويب أن يُفتح على حالة معينة. كل طلب نسخة جديدة، فيصل ولو تكررت الحالة.
class BookingsFilterRequest {
  const BookingsFilterRequest(this.status);

  final String? status;
}

class AdminBookings extends StatefulWidget {
  const AdminBookings({super.key, this.initialFilter, this.filterRequest});

  final ValueListenable<BookingsFilterRequest?>? filterRequest;

  final String? initialFilter;

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
    widget.filterRequest?.addListener(_onFilterRequest);
    _load();
  }

  void _onFilterRequest() {
    final request = widget.filterRequest?.value;
    if (request == null) return;
    _status = request.status;
    _load();
  }

  @override
  void dispose() {
    widget.filterRequest?.removeListener(_onFilterRequest);
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
      (BookingStatus.pending, 'طلبات جديدة'),
      (BookingStatus.confirmed, 'موافَق عليها'),
      (BookingStatus.dispatched, 'تم الإرسال'),
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
            AppIconButton(
                icon: Icons.refresh_rounded, tooltip: 'تحديث', onTap: _load),
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
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (context, i) => PushKeyButton(
              label: filters[i].$2,
              compact: true,
              expand: false,
              tone: _status == filters[i].$1 ? KeyTone.lemon : KeyTone.white,
              onPressed: () {
                _status = filters[i].$1;
                _load();
              },
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Booking>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
                              Text(bookingPriceLabel(b),
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
  AppUser? _customer;
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
    final customer = booking == null ? null : await _repo.userById(booking.customerId);
    final workers = booking == null ? <Worker>[] : await _repo.listWorkers();
    if (!mounted) return;
    setState(() {
      _booking = booking;
      _receipt = receipt;
      _customer = customer;
      _workers = workers;
      _loading = false;
    });
  }

  Worker? get _worker {
    final id = _booking?.workerId;
    if (id == null) return null;
    for (final w in _workers) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<void> _setStatus(String status) async {
    setState(() => _working = true);
    try {
      await _repo.updateBookingStatus(widget.bookingId, status);
    } catch (_) {
      if (mounted) {
        AppSnack.show(context, 'تعذر تغيير الحالة. إن كان التعديل بانتظار موافقة الزبون فانتظر ردّه.',
            error: true);
      }
    }
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
                      subtitle: Text(w.specialty, style: const TextStyle(fontSize: 10)),
                      trailing: w.available
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 18)
                          : const Icon(Icons.block_rounded, color: AppColors.danger, size: 18),
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

  Future<void> _edit(Booking booking) async {
    final saved = await showAppSheet<bool>(
      context,
      builder: (ctx) => _EditBookingForm(booking: booking, repo: _repo),
    );
    if (saved == true) {
      if (mounted) AppSnack.show(context, 'تم التعديل وأُرسل إلى الزبون ليوافق عليه');
      await _load();
    }
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    if (!await launchUrl(Uri.parse('tel:${phoneForCall(phone)}'))) {
      if (mounted) AppSnack.show(context, 'تعذر فتح تطبيق الاتصال', error: true);
    }
  }

  Widget _section(String title, Widget child) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Future<void> _setPrice(Booking b) async {
    final controller = TextEditingController(text: b.hasPrice ? b.total.round().toString() : '');
    final amount = await showAppSheet<double>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader(
              title: 'السعر المتفق عليه',
              subtitle: 'يُضاف إلى وصل الزبون ليدفعه لاحقاً.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'مثال: 50000',
                suffixText: 'د.ع',
                prefixIcon: Icon(Icons.payments_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'حفظ وإضافته إلى الوصل',
              onPressed: () {
                final value = double.tryParse(controller.text) ?? 0;
                if (value > 0) Navigator.pop(ctx, value);
              },
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (amount == null) return;
    try {
      await _repo.setBookingPrice(b.id!, amount);
      if (mounted) AppSnack.show(context, 'تم تحديد السعر وإضافته إلى وصل الزبون');
    } catch (_) {
      if (mounted) AppSnack.show(context, 'تعذر حفظ السعر، حاول مرة أخرى', error: true);
    }
    await _load();
  }

  Future<void> _markPaid(Receipt receipt) async {
    await _repo.markReceiptPaid(receipt.id!, true);
    if (mounted) AppSnack.show(context, 'تم تعليم الوصل مدفوعاً');
    await _load();
  }

  Widget _priceCard(Booking b) {
    final theme = Theme.of(context);
    final receipt = _receipt;
    final open = b.status != BookingStatus.cancelled;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.hasPrice ? fmtMoney(b.total) : 'لم يُحدد السعر بعد',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: b.hasPrice ? 17 : 13),
                ),
              ),
              if (open && !(receipt?.paid ?? false))
                PrimaryButton(
                  label: b.hasPrice ? 'تغيير السعر' : 'تحديد السعر',
                  icon: Icons.handshake_outlined,
                  compact: true,
                  expand: false,
                  onPressed: () => _setPrice(b),
                ),
            ],
          ),
          if (receipt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${receipt.invoiceNo} · ${receipt.paid ? 'مدفوع' : 'لم يُدفع بعد'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (!receipt.paid)
                  SecondaryButton(
                    label: 'تم الدفع',
                    icon: Icons.check_rounded,
                    compact: true,
                    expand: false,
                    onPressed: () => _markPaid(receipt),
                  ),
              ],
            ),
          ] else if (!b.hasPrice) ...[
            const SizedBox(height: 6),
            Text('بعد الاتفاق مع الزبون حدّد السعر فيُنشأ وصله تلقائياً.',
                style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _editBanner(Booking b) {
    final theme = Theme.of(context);
    final color = switch (b.customerAck) {
      CustomerAck.approved => AppColors.success,
      CustomerAck.declined => AppColors.danger,
      _ => const Color(0xFFF59E0B),
    };
    return SoftCard(
      color: color.withValues(alpha: .08),
      borderColor: color.withValues(alpha: .4),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_calendar_rounded, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text('آخر تعديل: ${fmtDateTime(b.adminEditedAt!)}',
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 12)),
              ),
            ],
          ),
          if (b.editSummary != null) ...[
            const SizedBox(height: 4),
            Text(b.editSummary!, style: theme.textTheme.bodySmall),
          ],
          if (b.adminNote != null) ...[
            const SizedBox(height: 2),
            Text('رسالتك للزبون: ${b.adminNote}', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 6),
          Text(CustomerAck.label(b.customerAck),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _customerCard(Booking b) {
    final theme = Theme.of(context);
    final c = _customer;
    final phone = c?.phone ?? b.customerPhone;
    return SoftCard(
      child: Column(
        children: [
          Row(
            children: [
              AvatarCircle(name: b.customerName ?? 'زبون', size: 46, imagePath: c?.avatarPath),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c?.name ?? b.customerName ?? 'زبون',
                        style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                    Text('زبون منذ ${c == null ? '—' : fmtDate(c.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              if (phone != null)
                AppIconButton(
                    small: true,
                    icon: Icons.call_outlined,
                    tooltip: 'اتصال',
                    onTap: () => _call(phone)),
            ],
          ),
          const SizedBox(height: 4),
          InfoRow(icon: Icons.phone_iphone_rounded, label: 'رقم الهاتف', value: phone),
          InfoRow(
              icon: Icons.location_city_rounded,
              label: 'المحافظة',
              value: c?.city ?? b.customerCity),
          InfoRow(icon: Icons.home_outlined, label: 'عنوان حسابه', value: c?.address),
        ],
      ),
    );
  }

  Widget _workerCard(Booking b) {
    final theme = Theme.of(context);
    final w = _worker;
    final phone = w?.phone.isNotEmpty == true ? w!.phone : b.workerPhone;
    if (b.workerId == null) {
      return SoftCard(
        child: Row(
          children: [
            const Expanded(child: Text('لم يُعيَّن حرفي بعد', style: TextStyle(fontSize: 12.5))),
            PrimaryButton(label: 'تعيين حرفي', compact: true, expand: false, onPressed: _assign),
          ],
        ),
      );
    }
    final responseColor = b.workerResponse == WorkerResponse.declined
        ? AppColors.danger
        : b.workerResponse == WorkerResponse.accepted
            ? AppColors.success
            : theme.colorScheme.onSurface;
    return SoftCard(
      child: Column(
        children: [
          Row(
            children: [
              AvatarCircle(
                  name: w?.name ?? b.workerName ?? 'حرفي', size: 46, imagePath: w?.avatarPath),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w?.name ?? b.workerName ?? 'حرفي',
                        style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                    Text(WorkerResponse.label(b.workerResponse),
                        style: TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w800, color: responseColor)),
                  ],
                ),
              ),
              if (phone != null && phone.isNotEmpty)
                AppIconButton(
                    small: true,
                    icon: Icons.call_outlined,
                    tooltip: 'اتصال',
                    onTap: () => _call(phone)),
              const SizedBox(width: 4),
              SecondaryButton(label: 'تغيير', compact: true, expand: false, onPressed: _assign),
            ],
          ),
          const SizedBox(height: 4),
          InfoRow(icon: Icons.phone_iphone_rounded, label: 'رقم الهاتف', value: phone),
          InfoRow(icon: Icons.handyman_outlined, label: 'الاختصاص', value: w?.specialty),
          InfoRow(
            icon: Icons.star_rounded,
            label: 'التقييم والأعمال',
            value: w == null ? null : '${w.rating.toStringAsFixed(1)} · ${w.jobsDone} عمل منجز',
          ),
          InfoRow(
            icon: Icons.event_available_rounded,
            label: 'الحالة',
            value: w == null ? null : (w.available ? 'متاح' : 'مشغول'),
          ),
          if (w?.bio != null && w!.bio!.trim().isNotEmpty)
            InfoRow(icon: Icons.notes_rounded, label: 'نبذة', value: w.bio),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = _booking;
    if (_loading || b == null) {
      return const SafeArea(
        top: false,
        child: SizedBox(
            height: 240, child: Center(child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    final open = b.status != BookingStatus.completed && b.status != BookingStatus.cancelled;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(status: b.status),
                const SizedBox(width: 8),
                Text('حجز #${b.id}', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                const Spacer(),
                if (open)
                  PrimaryButton(
                    label: 'تعديل الحجز',
                    icon: Icons.edit_calendar_rounded,
                    compact: true,
                    expand: false,
                    onPressed: () => _edit(b),
                  ),
              ],
            ),
            if (b.adminEditedAt != null) ...[
              const SizedBox(height: 10),
              _editBanner(b),
            ],
            _section('الزبون', _customerCard(b)),
            _section(
              'تفاصيل الحجز',
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
                      value: '${fmtDate(b.scheduledAt)} · ${fmtWeekday(b.scheduledAt)}',
                    ),
                    InfoRow(icon: Icons.schedule_rounded, label: 'الوقت', value: fmtSlot(b.slot)),
                    InfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'عنوان الخدمة',
                        value: b.address),
                    if (b.notes != null && b.notes!.isNotEmpty)
                      InfoRow(icon: Icons.notes_rounded, label: 'ملاحظات الزبون', value: b.notes),
                    InfoRow(
                        icon: Icons.history_rounded,
                        label: 'وقت الطلب',
                        value: fmtDateTime(b.createdAt)),
                    if (b.dispatchedAt != null)
                      InfoRow(
                          icon: Icons.local_shipping_rounded,
                          label: 'وقت إرسال الحرفي',
                          value: fmtDateTime(b.dispatchedAt!)),
                  ],
                ),
              ),
            ),
            _section('السعر والوصل', _priceCard(b)),
            _section('الحرفي', _workerCard(b)),
            if (_receipt != null)
              _section(
                'الوصل',
                SoftCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => Navigator.push(
                    context,
                    QuickRoute(builder: (_) => ReceiptPreviewScreen(receipt: _receipt!)),
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
                      AppIconButton(
                        small: true,
                        tooltip: 'طباعة',
                        onTap: () => ReceiptActions.print(context, _receipt!),
                        icon: Icons.print_rounded,
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('تحديث الحالة', style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (b.status == BookingStatus.pending)
                  _StatusAction(
                    label: 'موافقة على الحجز',
                    icon: Icons.verified_rounded,
                    color: AppColors.info,
                    onTap: () => _setStatus(BookingStatus.confirmed),
                  ),
                if (b.status == BookingStatus.confirmed)
                  _StatusAction(
                    label: 'إرسال الحرفي',
                    icon: Icons.local_shipping_rounded,
                    color: AppColors.info,
                    onTap: () {
                      if (b.workerId == null) {
                        AppSnack.show(context, 'عيّن حرفياً أولاً ثم أرسله', error: true);
                        return;
                      }
                      if (b.customerAck == CustomerAck.pending) {
                        AppSnack.show(context, 'بانتظار موافقة الزبون على تعديلك أولاً',
                            error: true);
                        return;
                      }
                      _setStatus(BookingStatus.dispatched);
                    },
                  ),
                if (b.status == BookingStatus.dispatched)
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
                if (open)
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

/// نموذج تعديل المدير للحجز: الموعد والوقت والعنوان والملاحظات، ورسالة للزبون.
class _EditBookingForm extends StatefulWidget {
  const _EditBookingForm({required this.booking, required this.repo});

  final Booking booking;
  final Repository repo;

  @override
  State<_EditBookingForm> createState() => _EditBookingFormState();
}

class _EditBookingFormState extends State<_EditBookingForm> {
  static const _slots = [
    '09:00', '10:00', '11:00', '12:00', '13:00', '14:00',
    '15:00', '16:00', '17:00', '18:00', '19:00', '20:00',
  ];

  late DateTime _day = DateTime(
    widget.booking.scheduledAt.year,
    widget.booking.scheduledAt.month,
    widget.booking.scheduledAt.day,
  );
  late String _slot = widget.booking.slot;
  late final _address = TextEditingController(text: widget.booking.address);
  late final _notes = TextEditingController(text: widget.booking.notes ?? '');
  late final _message = TextEditingController(text: widget.booking.adminNote ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(first) ? first : _day,
      firstDate: first,
      lastDate: first.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _save() async {
    if (_address.text.trim().length < 8) {
      setState(() => _error = 'أدخل عنواناً تفصيلياً لا يقل عن 8 أحرف');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.adminUpdateBooking(
        widget.booking.id!,
        scheduledAt: _day,
        slot: _slot,
        address: _address.text.trim(),
        notes: _notes.text.trim(),
        adminNote: _message.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر حفظ التعديل. تحقق من الاتصال وحاول مرة أخرى.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeader(
            title: 'تعديل الحجز',
            subtitle: 'يُرسَل التعديل إلى الزبون ليوافق عليه قبل إرسال الحرفي.',
          ),
          const SizedBox(height: 14),
          const FieldLabel('اليوم'),
          SecondaryButton(
            label: '${fmtWeekday(_day)} · ${fmtDate(_day)}',
            icon: Icons.calendar_month_rounded,
            onPressed: _pickDay,
          ),
          const SizedBox(height: 8),
          const FieldLabel('الوقت'),
          Wrap(
            spacing: 2,
            children: [
              for (final slot in _slots)
                PushKeyButton(
                  label: fmtSlot(slot),
                  compact: true,
                  expand: false,
                  tone: slot == _slot ? KeyTone.lemon : KeyTone.white,
                  onPressed: () => setState(() => _slot = slot),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const FieldLabel('عنوان الخدمة', required_: true),
          TextField(
            controller: _address,
            maxLines: 2,
            decoration:
                const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined, size: 20)),
          ),
          const SizedBox(height: 12),
          const FieldLabel('ملاحظات'),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.notes_rounded, size: 20)),
          ),
          const SizedBox(height: 12),
          const FieldLabel('رسالة للزبون (اختياري)'),
          TextField(
            controller: _message,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'مثال: اتفقنا معك هاتفياً على الموعد الجديد',
              prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 20),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'حفظ وإرسال للزبون',
            icon: Icons.send_rounded,
            loading: _saving,
            onPressed: _save,
          ),
        ],
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

  /// الأحمر وحده يغيّر لون الزر، لأنه إجراء لا رجعة فيه.
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PushKeyButton(
      label: label,
      icon: icon,
      compact: true,
      expand: false,
      tone: color == AppColors.danger ? KeyTone.red : KeyTone.yellow,
      onPressed: onTap,
    );
  }
}
