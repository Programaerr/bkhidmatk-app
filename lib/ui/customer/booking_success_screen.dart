import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../common/receipt_document.dart';
import '../widgets/ui.dart';
import 'booking_detail_screen.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key, required this.booking, this.receipt});

  final Booking booking;
  final Receipt? receipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 32, 22, 24),
          child: Column(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: .12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.success.withValues(alpha: .3), width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 46),
              ),
              const SizedBox(height: 18),
              Text('تم استلام حجزك بنجاح!', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'سيتواصل معك فريق بخدمتك لتأكيد الموعد خلال 15 دقيقة.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5, height: 1.7),
              ),
              const SizedBox(height: 24),
              SoftCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.home_repair_service_rounded, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(booking.serviceTitle ?? 'خدمة',
                                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                              Text('رقم الحجز #${booking.id}',
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                            ],
                          ),
                        ),
                        StatusPill(status: booking.status),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _SmallInfo(
                            icon: Icons.calendar_month_rounded,
                            label: 'التاريخ',
                            value: fmtDate(booking.scheduledAt),
                          ),
                        ),
                        Expanded(
                          child: _SmallInfo(
                            icon: Icons.schedule_rounded,
                            label: 'الوقت',
                            value: fmtSlot(booking.slot),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SmallInfo(
                            icon: Icons.engineering_rounded,
                            label: 'الفني',
                            value: booking.workerName ?? 'سيتم التعيين',
                          ),
                        ),
                        Expanded(
                          child: _SmallInfo(
                            icon: Icons.payments_rounded,
                            label: 'الإجمالي',
                            value: fmtMoney(booking.total),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (receipt != null) ...[
                const SizedBox(height: 12),
                SoftCard(
                  color: AppColors.gold.withValues(alpha: .1),
                  borderColor: AppColors.gold.withValues(alpha: .35),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('وصل الدفع جاهز',
                                style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
                            Text(receipt!.invoiceNo,
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => ReceiptActions.print(context, receipt!),
                        icon: const Icon(Icons.print_rounded),
                        tooltip: 'طباعة',
                      ),
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ReceiptPreviewScreen(receipt: receipt!)),
                        ),
                        icon: const Icon(Icons.receipt_long_rounded),
                        tooltip: 'معاينة',
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'عرض تفاصيل الحجز',
                icon: Icons.assignment_outlined,
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: booking.id!)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                  child: const Text('العودة للرئيسية'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  const _SmallInfo({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: .5)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5)),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}
