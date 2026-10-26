import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../common/receipt_document.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final int bookingId;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen>
    with RealtimeRefresh<BookingDetailScreen> {
  Booking? _booking;
  Receipt? _receipt;
  bool _loading = true;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<AppState>().repo;
    final booking = await repo.bookingById(widget.bookingId);
    final receipt = await repo.receiptForBooking(widget.bookingId);
    if (!mounted) return;
    setState(() {
      _booking = booking;
      _receipt = receipt;
      _loading = false;
    });
  }

  Future<void> _cancel() async {
    final ok = await confirmAction(
      context,
      title: 'إلغاء الحجز؟',
      message: 'هل أنت متأكد من رغبتك بإلغاء هذا الحجز؟',
      confirmLabel: 'نعم، إلغاء',
      danger: true,
    );
    if (!ok) return;
    await context.read<AppState>().repo.updateBookingStatus(_booking!.id!, BookingStatus.cancelled);
    if (!mounted) return;
    AppSnack.show(context, 'تم إلغاء الحجز');
    _load();
  }

  Future<void> _call(String phone) async {
    if (!await launchUrl(Uri.parse('tel:${phoneForCall(phone)}'))) {
      if (mounted) AppSnack.show(context, 'تعذر فتح تطبيق الاتصال', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final b = _booking;
    if (b == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الحجز')),
        body: const EmptyState(icon: Icons.search_off_rounded, title: 'الحجز غير موجود'),
      );
    }
    final canCancel = b.status == BookingStatus.pending || b.status == BookingStatus.confirmed;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الحجز'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
          children: [
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('حجز #${b.id}',
                            style: theme.textTheme.titleSmall?.copyWith(fontSize: 12)),
                      ),
                      StatusPill(status: b.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(b.serviceTitle ?? 'خدمة', style: theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
                  const SizedBox(height: 4),
                  Text('تم الإنشاء ${timeAgo(b.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(),
                  ),
                  _Timeline(status: b.status),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SoftCard(
              child: Column(
                children: [
                  InfoRow(
                    icon: Icons.calendar_month_rounded,
                    label: 'الموعد',
                    value: '${fmtDate(b.scheduledAt)} · ${fmtWeekday(b.scheduledAt)}',
                  ),
                  InfoRow(icon: Icons.schedule_rounded, label: 'الوقت', value: fmtSlot(b.slot)),
                  InfoRow(icon: Icons.location_on_outlined, label: 'العنوان', value: b.address),
                  if (b.notes != null && b.notes!.isNotEmpty)
                    InfoRow(icon: Icons.notes_rounded, label: 'ملاحظات', value: b.notes),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SoftCard(
              child: Row(
                children: [
                  AvatarCircle(name: b.workerName ?? 'فريق بخدمتك', size: 46),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.workerName ?? 'لم يتم تعيين فني بعد',
                            style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5)),
                        Text('الفني المسؤول',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                  if (b.workerPhone != null)
                    AppIconButton(
                      icon: Icons.call_outlined,
                      onTap: () => _call(b.workerPhone!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SoftCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('الدفع', style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
                      const Spacer(),
                      PaymentMethodBadge(
                        method: b.paymentMethod,
                        brand: _receipt?.cardBrand,
                        last4: _receipt?.last4,
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                  Row(
                    children: [
                      Text('الإجمالي', style: theme.textTheme.bodySmall),
                      const Spacer(),
                      Text(fmtMoney(b.total),
                          style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
            if (_receipt != null) ...[
              const SizedBox(height: 12),
              SoftCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(receipt: _receipt!)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('وصل الدفع', style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
                          Text('${_receipt!.invoiceNo} · ${_receipt!.paid ? 'مدفوع' : 'غير مدفوع'}',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => ReceiptActions.print(context, _receipt!),
                      icon: const Icon(Icons.print_rounded, size: 20),
                    ),
                    const Icon(Icons.chevron_left_rounded, size: 20),
                  ],
                ),
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: .35)),
                  ),
                  child: const Text('إلغاء الحجز'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancelled = status == BookingStatus.cancelled;
    final steps = [
      (BookingStatus.pending, 'تم الطلب', Icons.receipt_long_rounded),
      (BookingStatus.confirmed, 'تم التأكيد', Icons.verified_rounded),
      (BookingStatus.inProgress, 'قيد التنفيذ', Icons.engineering_rounded),
      (BookingStatus.completed, 'مكتمل', Icons.done_all_rounded),
    ];
    final activeIndex = cancelled
        ? 0
        : steps.indexWhere((s) => s.$1 == status).clamp(0, steps.length - 1);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: i <= activeIndex && !cancelled
                          ? (i == activeIndex ? AppColors.gold : AppColors.success.withValues(alpha: .15))
                          : theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i <= activeIndex && !cancelled
                            ? (i == activeIndex ? AppColors.gold : AppColors.success)
                            : theme.colorScheme.outline,
                      ),
                    ),
                    child: Icon(
                      i < activeIndex && !cancelled ? Icons.check_rounded : steps[i].$3,
                      size: 13,
                      color: i <= activeIndex && !cancelled ? AppColors.ink : theme.colorScheme.onSurface.withValues(alpha: .35),
                    ),
                  ),
                  if (i != steps.length - 1)
                    Container(
                      width: 2,
                      height: 26,
                      color: i < activeIndex && !cancelled
                          ? AppColors.success.withValues(alpha: .4)
                          : theme.colorScheme.outline,
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  steps[i].$2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: i == activeIndex ? FontWeight.w800 : FontWeight.w500,
                    color: i <= activeIndex && !cancelled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: .45),
                  ),
                ),
              ),
            ],
          ),
        if (cancelled)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 16),
                const SizedBox(width: 6),
                Text('تم إلغاء هذا الحجز',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 11.5)),
              ],
            ),
          ),
      ],
    );
  }
}
