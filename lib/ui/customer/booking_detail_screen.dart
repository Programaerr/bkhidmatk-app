import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../auth/push_key.dart';
import '../common/receipt_document.dart';
import '../widgets/quick_route.dart';
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

  // نموذج التقييم
  int _rating = 0;
  final _review = TextEditingController();
  bool _ratingBusy = false;
  bool _ackBusy = false;

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

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
    final repo = context.read<AppState>().repo;
    final ok = await confirmAction(
      context,
      title: tr('إلغاء الحجز؟', 'Cancel the booking?'),
      message: tr('هل أنت متأكد من رغبتك بإلغاء هذا الحجز؟', 'Are you sure you want to cancel this booking?'),
      confirmLabel: tr('نعم، إلغاء', 'Yes, cancel'),
      danger: true,
    );
    if (!ok) return;
    await repo.updateBookingStatus(_booking!.id!, BookingStatus.cancelled);
    if (!mounted) return;
    AppSnack.show(context, tr('تم إلغاء الحجز', 'The booking was cancelled'));
    _load();
  }

  Future<void> _submitRating() async {
    if (_rating < 1) {
      AppSnack.show(context, tr('اختر عدد النجوم أولاً', 'Choose the number of stars first'), error: true);
      return;
    }
    setState(() => _ratingBusy = true);
    final repo = context.read<AppState>().repo;
    final success = await repo.rateBooking(
      bookingId: _booking!.id!,
      rating: _rating,
      review: _review.text.trim().isEmpty ? null : _review.text.trim(),
    );
    if (!mounted) return;
    setState(() => _ratingBusy = false);
    if (success) {
      AppSnack.show(context, tr('شكراً لتقييمك', 'Thanks for your rating'));
      _load();
    } else {
      AppSnack.show(
          context, tr('تعذر حفظ التقييم. تأكد أن الحجز مكتمل ولم تقيّمه مسبقاً.', "Couldn't save the rating. Make sure the booking is completed and you haven't rated it before."),
          error: true);
    }
  }

  Future<void> _answerEdit(bool approve) async {
    setState(() => _ackBusy = true);
    try {
      await context.read<AppState>().repo.respondToBookingEdit(_booking!.id!, approve: approve);
      if (mounted) {
        AppSnack.show(context, approve ? tr('وافقتَ على التعديل', 'You approved the change') : tr('وصل رفضك إلى الإدارة', 'Your refusal reached the admin'));
      }
    } catch (_) {
      if (mounted) AppSnack.show(context, tr('تعذر إرسال ردك، حاول مرة أخرى', "Couldn't send your reply, please try again"), error: true);
    }
    if (mounted) setState(() => _ackBusy = false);
    await _load();
  }

  /// تعديل الإدارة للحجز: متى، وما الذي تغيّر، وموافقتك عليه.
  Widget _editCard(ThemeData theme, Booking b) {
    final pending = b.customerAck == CustomerAck.pending;
    final color = switch (b.customerAck) {
      CustomerAck.approved => AppColors.success,
      CustomerAck.declined => AppColors.danger,
      _ => AppColors.goldDeep,
    };
    return SoftCard(
      borderColor: color.withValues(alpha: .6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_calendar_rounded, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pending ? tr('عدّلت الإدارة حجزك', 'The admin changed your booking') : tr('تعديل الإدارة على حجزك', "The admin's change to your booking"),
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr('تاريخ التعديل: ${fmtDateTime(b.adminEditedAt!)}', 'Changed on: ${fmtDateTime(b.adminEditedAt!)}'),
              style: theme.textTheme.bodySmall),
          if (b.editSummary != null) ...[
            const SizedBox(height: 6),
            Text(b.editSummary!, style: theme.textTheme.bodyMedium),
          ],
          if (b.adminNote != null) ...[
            const SizedBox(height: 4),
            Text(tr('رسالة الإدارة: ${b.adminNote}', 'Admin message: ${b.adminNote}'), style: theme.textTheme.bodySmall),
          ],
          if (!pending) ...[
            const SizedBox(height: 6),
            Text(CustomerAck.label(b.customerAck),
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: tr('موافق', 'Approve'),
                    compact: true,
                    loading: _ackBusy,
                    onPressed: () => _answerEdit(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SecondaryButton(
                    label: tr('لا أوافق', "Don't approve"),
                    compact: true,
                    danger: true,
                    onPressed: _ackBusy ? null : () => _answerEdit(false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// بطاقة تقييم الفني بعد اكتمال الحجز.
  Widget _ratingCard(ThemeData theme, Booking b) {
    final alreadyRated = b.rating != null;
    return SoftCard(
      borderColor: AppColors.gold.withValues(alpha: .55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.star_rounded,
                    size: 19, color: AppColors.goldDeep),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alreadyRated ? tr('تقييمك لهذا الحجز', 'Your rating for this booking') : tr('قيّم تجربتك مع الفني', 'Rate your experience with the technician'),
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (alreadyRated) ...[
            RatingStars(rating: b.rating!.toDouble(), size: 18),
            if (b.review != null && b.review!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(b.review!, style: theme.textTheme.bodySmall),
            ],
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                final active = star <= _rating;
                return IconButton(
                  onPressed:
                      _ratingBusy ? null : () => setState(() => _rating = star),
                  icon: Icon(
                    active ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: active
                        ? const Color(0xFFF5A623)
                        : theme.colorScheme.outline,
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _review,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: tr('ملاحظتك عن العمل (اختياري)', 'Your note about the work (optional)'),
                hintText: tr('اكتب رأيك في جودة الخدمة...', 'Write your opinion of the service quality...'),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: tr('إرسال التقييم', 'Send rating'),
              icon: Icons.how_to_reg_rounded,
              loading: _ratingBusy,
              onPressed: _ratingBusy ? null : _submitRating,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: PushKeyAppBar(title: tr('تفاصيل الحجز', 'Booking details')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final b = _booking;
    if (b == null) {
      return Scaffold(
        appBar: PushKeyAppBar(title: tr('تفاصيل الحجز', 'Booking details')),
        body: EmptyState(
            icon: Icons.search_off_rounded, title: tr('الحجز غير موجود', 'Booking not found')),
      );
    }
    final canCancel = b.status == BookingStatus.pending ||
        b.status == BookingStatus.confirmed;
    return Scaffold(
      appBar: PushKeyAppBar(title: tr('تفاصيل الحجز', 'Booking details')),
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
                        child: Text(tr('حجز #${b.id}', 'Booking #${b.id}'),
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontSize: 12)),
                      ),
                      StatusPill(status: b.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(b.serviceTitle ?? tr('خدمة', 'Service'),
                      style:
                          theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
                  const SizedBox(height: 4),
                  Text(tr('تم الإنشاء ${timeAgo(b.createdAt)}', 'Created ${timeAgo(b.createdAt)}'),
                      style:
                          theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(),
                  ),
                  _Timeline(status: b.status),
                ],
              ),
            ),
            if (b.adminEditedAt != null) ...[
              const SizedBox(height: 12),
              _editCard(theme, b),
            ],
            const SizedBox(height: 12),
            SoftCard(
              child: Column(
                children: [
                  InfoRow(
                    icon: Icons.calendar_month_rounded,
                    label: tr('الموعد', 'Appointment'),
                    value:
                        '${fmtDate(b.scheduledAt)} · ${fmtWeekday(b.scheduledAt)}',
                  ),
                  InfoRow(
                      icon: Icons.schedule_rounded,
                      label: tr('الوقت', 'Time'),
                      value: fmtSlot(b.slot)),
                  InfoRow(
                      icon: Icons.location_on_outlined,
                      label: tr('العنوان', 'Address'),
                      value: b.address),
                  if (b.notes != null && b.notes!.isNotEmpty)
                    InfoRow(
                        icon: Icons.notes_rounded,
                        label: tr('ملاحظات', 'Notes'),
                        value: b.notes),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SoftCard(
              child: Row(
                children: [
                  AvatarCircle(name: b.workerName ?? tr('فريق جايك', 'Jaik team'), size: 46),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.workerName ?? tr('لم يتم تعيين فني بعد', 'No technician assigned yet'),
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontSize: 13.5)),
                        Text(
                            b.workerName == null
                                ? tr('الفني المسؤول', 'Assigned technician')
                                : tr('الفني المسؤول · ${WorkerResponse.label(b.workerResponse)}', 'Assigned technician · ${WorkerResponse.label(b.workerResponse)}'),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 10)),
                      ],
                    ),
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
                      Text(tr('السعر', 'Price'),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontSize: 13)),
                      const Spacer(),
                      Text(bookingPriceLabel(b),
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontSize: b.hasPrice ? 18 : 13)),
                    ],
                  ),
                  if (!b.hasPrice) ...[
                    const SizedBox(height: 6),
                    Text(
                      tr('يُتفق على السعر مع الإدارة، ثم يُضاف إلى وصلك لتدفعه لاحقاً.', 'The price is agreed with the admin, then added to your receipt to pay later.'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else if (_receipt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _receipt!.paid ? tr('تم دفعه.', 'Paid.') : tr('أُضيف إلى وصلك ولم يُدفع بعد.', 'Added to your receipt and not paid yet.'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (_receipt != null) ...[
              const SizedBox(height: 12),
              SoftCard(
                onTap: () => Navigator.push(
                  context,
                  QuickRoute(
                      builder: (_) => ReceiptPreviewScreen(receipt: _receipt!)),
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
                          Text(tr('وصل الدفع', 'Payment receipt'),
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontSize: 13)),
                          Text(
                              tr('${_receipt!.invoiceNo} · ${_receipt!.paid ? 'مدفوع' : 'غير مدفوع'}', "${_receipt!.invoiceNo} · ${_receipt!.paid ? 'Paid' : 'Unpaid'}"),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                    AppIconButton(
                      small: true,
                      onTap: () => ReceiptActions.print(context, _receipt!),
                      icon: Icons.print_rounded,
                      tooltip: tr('طباعة', 'Print'),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              ),
            ],
            if (b.status == BookingStatus.completed) ...[
              const SizedBox(height: 12),
              _ratingCard(theme, b),
            ],
            if (canCancel) ...[
              const SizedBox(height: 18),
              SecondaryButton(
                label: tr('إلغاء الحجز', 'Cancel booking'),
                danger: true,
                onPressed: _cancel,
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
      (BookingStatus.pending, tr('وصل طلبك إلى الإدارة', 'Your request reached the admin'), Icons.receipt_long_rounded),
      (BookingStatus.confirmed, tr('تم حجزك بموافقة الإدارة', 'You are booked, approved by the admin'), Icons.verified_rounded),
      (BookingStatus.dispatched, tr('الحرفي في الطريق إليك', 'The craftsman is on the way to you'), Icons.local_shipping_rounded),
      (BookingStatus.inProgress, tr('قيد التنفيذ', 'In progress'), Icons.engineering_rounded),
      (BookingStatus.completed, tr('مكتمل', 'Completed'), Icons.done_all_rounded),
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
                          ? (i == activeIndex
                              ? AppColors.gold
                              : AppColors.success.withValues(alpha: .15))
                          : theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i <= activeIndex && !cancelled
                            ? (i == activeIndex
                                ? AppColors.gold
                                : AppColors.success)
                            : theme.colorScheme.outline,
                      ),
                    ),
                    child: Icon(
                      i < activeIndex && !cancelled
                          ? Icons.check_rounded
                          : steps[i].$3,
                      size: 13,
                      color: i <= activeIndex && !cancelled
                          ? (i == activeIndex ? AppColors.onGold : AppColors.ink)
                          : theme.colorScheme.onSurface.withValues(alpha: .35),
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
                    fontWeight:
                        i == activeIndex ? FontWeight.w800 : FontWeight.w500,
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
                const Icon(Icons.cancel_rounded,
                    color: AppColors.danger, size: 16),
                const SizedBox(width: 6),
                Text(tr('تم إلغاء هذا الحجز', 'This booking was cancelled'),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5)),
              ],
            ),
          ),
      ],
    );
  }
}
