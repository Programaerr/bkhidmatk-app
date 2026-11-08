import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/language.dart';
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
      (null, tr('الكل', 'All')),
      (BookingStatus.pending, tr('طلبات جديدة', 'New requests')),
      (BookingStatus.confirmed, tr('موافَق عليها', 'Approved')),
      (BookingStatus.dispatched, tr('تم الإرسال', 'Dispatched')),
      (BookingStatus.inProgress, tr('قيد التنفيذ', 'In progress')),
      (BookingStatus.completed, tr('مكتمل', 'Completed')),
      (BookingStatus.cancelled, tr('ملغي', 'Cancelled')),
    ];
    return Column(
      children: [
        AdminHeader(
          title: tr('إدارة الحجوزات', 'Manage bookings'),
          subtitle: tr('متابعة وتحديث حالة كل حجز', 'Follow and update the status of every booking'),
          actions: [
            AppIconButton(
                icon: Icons.refresh_rounded, tooltip: tr('تحديث', 'Refresh'), onTap: _load),
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
            decoration: InputDecoration(
              hintText: tr('ابحث باسم الزبون، الرقم، أو الخدمة...', 'Search by customer name, number, or service...'),
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
                return EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: tr('لا توجد حجوزات', 'No bookings'),
                  subtitle: tr('ستظهر الحجوزات الجديدة هنا مباشرة.', 'New bookings will appear here right away.'),
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
                              AvatarCircle(name: b.customerName ?? tr('زبون', 'Customer'), size: 38),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.customerName ?? tr('زبون', 'Customer'),
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
                                    Text(b.serviceTitle ?? tr('خدمة', 'Service'),
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
        AppSnack.show(context, tr('تعذر تغيير الحالة. إن كان التعديل بانتظار موافقة الزبون فانتظر ردّه.', "Couldn't change the status. If the change is waiting for the customer's approval, wait for their reply."),
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
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: SheetHeader(title: tr('تعيين فني', 'Assign a technician')),
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
      if (mounted) AppSnack.show(context, tr('تم التعديل وأُرسل إلى الزبون ليوافق عليه', 'The change was saved and sent to the customer to approve'));
      await _load();
    }
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    if (!await launchUrl(Uri.parse('tel:${phoneForCall(phone)}'))) {
      if (mounted) AppSnack.show(context, tr('تعذر فتح تطبيق الاتصال', "Couldn't open the phone app"), error: true);
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
            SheetHeader(
              title: tr('السعر المتفق عليه', 'Agreed price'),
              subtitle: tr('يُضاف إلى وصل الزبون ليدفعه لاحقاً.', "Added to the customer's receipt to pay later."),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: tr('مثال: 50000', 'Example: 50000'),
                suffixText: tr('د.ع', 'IQD'),
                prefixIcon: Icon(Icons.payments_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: tr('حفظ وإضافته إلى الوصل', 'Save and add to the receipt'),
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
      if (mounted) AppSnack.show(context, tr('تم تحديد السعر وإضافته إلى وصل الزبون', "The price was set and added to the customer's receipt"));
    } catch (_) {
      if (mounted) AppSnack.show(context, tr('تعذر حفظ السعر، حاول مرة أخرى', "Couldn't save the price, please try again"), error: true);
    }
    await _load();
  }

  Future<void> _markPaid(Receipt receipt) async {
    await _repo.markReceiptPaid(receipt.id!, true);
    if (mounted) AppSnack.show(context, tr('تم تعليم الوصل مدفوعاً', 'The receipt was marked as paid'));
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
                  b.hasPrice ? fmtMoney(b.total) : tr('لم يُحدد السعر بعد', 'Price not set yet'),
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: b.hasPrice ? 17 : 13),
                ),
              ),
              if (open && !(receipt?.paid ?? false))
                PrimaryButton(
                  label: b.hasPrice ? tr('تغيير السعر', 'Change price') : tr('تحديد السعر', 'Set price'),
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
                    tr('${receipt.invoiceNo} · ${receipt.paid ? 'مدفوع' : 'لم يُدفع بعد'}', "${receipt.invoiceNo} · ${receipt.paid ? 'Paid' : 'Not paid yet'}"),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (!receipt.paid)
                  SecondaryButton(
                    label: tr('تم الدفع', 'Mark paid'),
                    icon: Icons.check_rounded,
                    compact: true,
                    expand: false,
                    onPressed: () => _markPaid(receipt),
                  ),
              ],
            ),
          ] else if (!b.hasPrice) ...[
            const SizedBox(height: 6),
            Text(tr('بعد الاتفاق مع الزبون حدّد السعر فيُنشأ وصله تلقائياً.', 'After agreeing with the customer, set the price and their receipt is created automatically.'),
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
                child: Text(tr('آخر تعديل: ${fmtDateTime(b.adminEditedAt!)}', 'Last change: ${fmtDateTime(b.adminEditedAt!)}'),
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
            Text(tr('رسالتك للزبون: ${b.adminNote}', 'Your message to the customer: ${b.adminNote}'), style: theme.textTheme.bodySmall),
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
              AvatarCircle(name: b.customerName ?? tr('زبون', 'Customer'), size: 46, imagePath: c?.avatarPath),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c?.name ?? b.customerName ?? tr('زبون', 'Customer'),
                        style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                    Text(tr('زبون منذ ${c == null ? '—' : fmtDate(c.createdAt)}', "Customer since ${c == null ? '—' : fmtDate(c.createdAt)}"),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              if (phone != null)
                AppIconButton(
                    small: true,
                    icon: Icons.call_outlined,
                    tooltip: tr('اتصال', 'Call'),
                    onTap: () => _call(phone)),
            ],
          ),
          const SizedBox(height: 4),
          InfoRow(icon: Icons.phone_iphone_rounded, label: tr('رقم الهاتف', 'Phone number'), value: phone),
          InfoRow(
              icon: Icons.location_city_rounded,
              label: tr('المحافظة', 'Province'),
              value: switch (c?.city ?? b.customerCity) {
                final city? => cityLabel(city),
                _ => null,
              }),
          InfoRow(icon: Icons.home_outlined, label: tr('عنوان حسابه', 'Account address'), value: c?.address),
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
            Expanded(child: Text(tr('لم يُعيَّن حرفي بعد', 'No craftsman assigned yet'), style: TextStyle(fontSize: 12.5))),
            PrimaryButton(label: tr('تعيين حرفي', 'Assign a craftsman'), compact: true, expand: false, onPressed: _assign),
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
                  name: w?.name ?? b.workerName ?? tr('حرفي', 'Craftsman'), size: 46, imagePath: w?.avatarPath),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w?.name ?? b.workerName ?? tr('حرفي', 'Craftsman'),
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
                    tooltip: tr('اتصال', 'Call'),
                    onTap: () => _call(phone)),
              const SizedBox(width: 4),
              SecondaryButton(label: tr('تغيير', 'Change'), compact: true, expand: false, onPressed: _assign),
            ],
          ),
          const SizedBox(height: 4),
          InfoRow(icon: Icons.phone_iphone_rounded, label: tr('رقم الهاتف', 'Phone number'), value: phone),
          InfoRow(icon: Icons.handyman_outlined, label: tr('الاختصاص', 'Specialty'), value: w?.specialty),
          InfoRow(
            icon: Icons.star_rounded,
            label: tr('التقييم والأعمال', 'Rating and jobs'),
            value: w == null ? null : tr('${w.rating.toStringAsFixed(1)} · ${w.jobsDone} عمل منجز', '${w.rating.toStringAsFixed(1)} · ${w.jobsDone} jobs done'),
          ),
          InfoRow(
            icon: Icons.event_available_rounded,
            label: tr('الحالة', 'Status'),
            value: w == null ? null : (w.available ? tr('متاح', 'Available') : tr('مشغول', 'Busy')),
          ),
          if (w?.bio != null && w!.bio!.trim().isNotEmpty)
            InfoRow(icon: Icons.notes_rounded, label: tr('نبذة', 'About'), value: w.bio),
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
                Text(tr('حجز #${b.id}', 'Booking #${b.id}'), style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                const Spacer(),
                if (open)
                  PrimaryButton(
                    label: tr('تعديل الحجز', 'Edit booking'),
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
            _section(tr('الزبون', 'Customer'), _customerCard(b)),
            _section(
              tr('تفاصيل الحجز', 'Booking details'),
              SoftCard(
                child: Column(
                  children: [
                    InfoRow(
                        icon: Icons.home_repair_service_rounded,
                        label: tr('الخدمة', 'Service'),
                        value: b.serviceTitle),
                    InfoRow(
                      icon: Icons.calendar_month_rounded,
                      label: tr('الموعد', 'Appointment'),
                      value: '${fmtDate(b.scheduledAt)} · ${fmtWeekday(b.scheduledAt)}',
                    ),
                    InfoRow(icon: Icons.schedule_rounded, label: tr('الوقت', 'Time'), value: fmtSlot(b.slot)),
                    InfoRow(
                        icon: Icons.location_on_outlined,
                        label: tr('عنوان الخدمة', 'Service address'),
                        value: b.address),
                    if (b.notes != null && b.notes!.isNotEmpty)
                      InfoRow(icon: Icons.notes_rounded, label: tr('ملاحظات الزبون', "Customer's notes"), value: b.notes),
                    InfoRow(
                        icon: Icons.history_rounded,
                        label: tr('وقت الطلب', 'Requested at'),
                        value: fmtDateTime(b.createdAt)),
                    if (b.dispatchedAt != null)
                      InfoRow(
                          icon: Icons.local_shipping_rounded,
                          label: tr('وقت إرسال الحرفي', 'Craftsman sent at'),
                          value: fmtDateTime(b.dispatchedAt!)),
                  ],
                ),
              ),
            ),
            _section(tr('السعر والوصل', 'Price and receipt'), _priceCard(b)),
            _section(tr('الحرفي', 'Craftsman'), _workerCard(b)),
            if (_receipt != null)
              _section(
                tr('الوصل', 'Receipt'),
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
                          tr('${_receipt!.invoiceNo} · ${_receipt!.paid ? 'مدفوع' : 'غير مدفوع'}', "${_receipt!.invoiceNo} · ${_receipt!.paid ? 'Paid' : 'Unpaid'}"),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      AppIconButton(
                        small: true,
                        tooltip: tr('طباعة', 'Print'),
                        onTap: () => ReceiptActions.print(context, _receipt!),
                        icon: Icons.print_rounded,
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(tr('تحديث الحالة', 'Update status'), style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (b.status == BookingStatus.pending)
                  _StatusAction(
                    label: tr('موافقة على الحجز', 'Approve booking'),
                    icon: Icons.verified_rounded,
                    color: AppColors.info,
                    onTap: () => _setStatus(BookingStatus.confirmed),
                  ),
                if (b.status == BookingStatus.confirmed)
                  _StatusAction(
                    label: tr('إرسال الحرفي', 'Send craftsman'),
                    icon: Icons.local_shipping_rounded,
                    color: AppColors.info,
                    onTap: () {
                      if (b.workerId == null) {
                        AppSnack.show(context, tr('عيّن حرفياً أولاً ثم أرسله', 'Assign a craftsman first, then send them'), error: true);
                        return;
                      }
                      if (b.customerAck == CustomerAck.pending) {
                        AppSnack.show(context, tr('بانتظار موافقة الزبون على تعديلك أولاً', 'Waiting for the customer to approve your change first'),
                            error: true);
                        return;
                      }
                      _setStatus(BookingStatus.dispatched);
                    },
                  ),
                if (b.status == BookingStatus.dispatched)
                  _StatusAction(
                    label: tr('بدء التنفيذ', 'Start work'),
                    icon: Icons.play_arrow_rounded,
                    color: AppColors.violet,
                    onTap: () => _setStatus(BookingStatus.inProgress),
                  ),
                if (b.status == BookingStatus.inProgress)
                  _StatusAction(
                    label: tr('إكمال الحجز', 'Complete booking'),
                    icon: Icons.done_all_rounded,
                    color: AppColors.success,
                    onTap: () => _setStatus(BookingStatus.completed),
                  ),
                if (open)
                  _StatusAction(
                    label: tr('إلغاء', 'Cancel'),
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
      setState(() => _error = tr('أدخل عنواناً تفصيلياً لا يقل عن 8 أحرف', 'Enter a detailed address of at least 8 characters'));
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
          _error = tr('تعذر حفظ التعديل. تحقق من الاتصال وحاول مرة أخرى.', "Couldn't save the change. Check the connection and try again.");
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
          SheetHeader(
            title: tr('تعديل الحجز', 'Edit booking'),
            subtitle: tr('يُرسَل التعديل إلى الزبون ليوافق عليه قبل إرسال الحرفي.', 'The change is sent to the customer to approve before the craftsman is sent.'),
          ),
          const SizedBox(height: 14),
          FieldLabel(tr('اليوم', 'Day')),
          SecondaryButton(
            label: '${fmtWeekday(_day)} · ${fmtDate(_day)}',
            icon: Icons.calendar_month_rounded,
            onPressed: _pickDay,
          ),
          const SizedBox(height: 8),
          FieldLabel(tr('الوقت', 'Time')),
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
          FieldLabel(tr('عنوان الخدمة', 'Service address'), required_: true),
          TextField(
            controller: _address,
            maxLines: 2,
            decoration:
                const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined, size: 20)),
          ),
          const SizedBox(height: 12),
          FieldLabel(tr('ملاحظات', 'Notes')),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.notes_rounded, size: 20)),
          ),
          const SizedBox(height: 12),
          FieldLabel(tr('رسالة للزبون (اختياري)', 'Message to the customer (optional)')),
          TextField(
            controller: _message,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: tr('مثال: اتفقنا معك هاتفياً على الموعد الجديد', 'Example: We agreed with you by phone on the new time'),
              prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 20),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: tr('حفظ وإرسال للزبون', 'Save and send to the customer'),
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
