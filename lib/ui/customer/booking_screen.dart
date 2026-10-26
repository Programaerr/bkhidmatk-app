import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/ui.dart';
import 'booking_success_screen.dart';
import 'payment_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.service});

  final Service service;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final List<DateTime> _days;
  late DateTime _selectedDay;
  String _slot = '10:00';
  int? _workerId;
  List<Worker> _workers = const [];
  String _method = 'cash';
  CardResult? _card;
  bool _loading = false;
  late final TextEditingController _address;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _days = List.generate(14, (i) {
      final d = now.add(Duration(days: i + 1));
      return DateTime(d.year, d.month, d.day);
    });
    _selectedDay = _days.first;
    _workerId = widget.service.workerId;
    _address = TextEditingController(
        text: context.read<AppState>().user?.address ?? '');
    _loadWorkers();
  }

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    final list = await context
        .read<AppState>()
        .repo
        .listWorkers(categoryId: widget.service.categoryId, onlyAvailable: true);
    if (mounted) setState(() => _workers = list);
  }

  Future<void> _pickWorker() async {
    final picked = await showAppSheet<int>(
      context,
      builder: (ctx) => SizedBox(
        height: 460,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: SheetHeader(
                title: 'اختر الفني',
                subtitle: 'كل الفنيين موثوقون ومقيّمون من الزبائن',
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final w in _workers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        padding: const EdgeInsets.all(12),
                        borderColor: w.id == _workerId ? AppColors.gold : null,
                        onTap: () => Navigator.pop(ctx, w.id),
                        child: Row(
                          children: [
                            AvatarCircle(name: w.name, size: 44),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(w.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('${w.specialty} · ${w.jobsDone} عمل',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                                ],
                              ),
                            ),
                            RatingStars(rating: w.rating),
                            if (w.id == _workerId)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _workerId = picked);
  }

  Future<void> _confirm() async {
    final user = context.read<AppState>().user;
    if (user?.id == null) return;
    if (_address.text.trim().length < 8) {
      AppSnack.show(context, 'أدخل عنواناً تفصيلياً للخدمة', error: true);
      return;
    }
    if (_method == 'card' && _card == null) {
      final result = await Navigator.push<CardResult>(
        context,
        MaterialPageRoute(builder: (_) => PaymentScreen(amount: widget.service.price)),
      );
      if (result == null) return;
      setState(() => _card = result);
    }

    setState(() => _loading = true);
    final repo = context.read<AppState>().repo;
    try {
      final bookingId = await repo.createBooking(Booking(
        customerId: user!.id!,
        serviceId: widget.service.id!,
        workerId: _workerId,
        scheduledAt: _selectedDay,
        slot: _slot,
        address: _address.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        status: BookingStatus.pending,
        paymentMethod: _method,
        total: widget.service.price,
        createdAt: DateTime.now(),
      ));
      await repo.createReceiptForBooking(
        bookingId: bookingId,
        userId: user.id!,
        title: 'وصل دفع خدمة',
        amount: widget.service.price,
        method: _method,
        cardBrand: _card?.brand,
        last4: _card?.last4,
        paid: _method == 'card',
      );
      final booking = await repo.bookingById(bookingId);
      final receipt = await repo.receiptForBooking(bookingId);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(booking: booking!, receipt: receipt),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnack.show(context, 'تعذر إنشاء الحجز، حاول مرة أخرى', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = _workers.where((w) => w.id == _workerId);
    final worker = matches.isEmpty ? null : matches.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجز الخدمة'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            SoftCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.home_repair_service_rounded, size: 22),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.service.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('${widget.service.categoryName ?? ''} · ${fmtDuration(widget.service.durationMinutes)}',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                      ],
                    ),
                  ),
                  Text(fmtMoney(widget.service.price),
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'الفني', subtitle: 'يمكنك ترك الاختيار لنا وسنرسل الأنسب'),
            SoftCard(
              onTap: _pickWorker,
              child: Row(
                children: [
                  AvatarCircle(name: worker?.name ?? 'تلقائي', size: 42),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(worker?.name ?? 'اختيار تلقائي',
                            style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5)),
                        Text(worker?.specialty ?? 'سنختار أفضل فني متاح',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'موعد الخدمة'),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final day = _days[i];
                  final selected = day == _selectedDay;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDay = day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 62,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.ink : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: selected ? AppColors.ink : theme.colorScheme.outline),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            fmtWeekday(day),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white60 : theme.colorScheme.onSurface.withValues(alpha: .6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: selected ? AppColors.gold : theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            _monthShort(day.month),
                            style: TextStyle(
                              fontSize: 9,
                              color: selected ? Colors.white54 : theme.colorScheme.onSurface.withValues(alpha: .5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const FieldLabel('الوقت المناسب'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in _slots)
                  GestureDetector(
                    onTap: () => setState(() => _slot = slot),
                    child: Container(
                      width: (MediaQuery.sizeOf(context).width - 36 - 24) / 3.2,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _slot == slot
                            ? AppColors.gold.withValues(alpha: .22)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _slot == slot ? AppColors.gold : theme.colorScheme.outline,
                          width: _slot == slot ? 1.6 : 1,
                        ),
                      ),
                      child: Text(
                        fmtSlot(slot),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'عنوان الخدمة'),
            TextField(
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'المنطقة، الشارع، رقم البناية، أقرب نقطة دالة',
                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'ملاحظات إضافية للفني (اختياري)',
                prefixIcon: Icon(Icons.notes_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'طريقة الدفع'),
            Row(
              children: [
                Expanded(
                  child: _PayOption(
                    selected: _method == 'cash',
                    icon: Icons.payments_outlined,
                    title: 'عند الوصول',
                    subtitle: 'نقداً للفني',
                    onTap: () => setState(() => _method = 'cash'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PayOption(
                    selected: _method == 'card',
                    icon: Icons.credit_card_rounded,
                    title: 'ماستركارد',
                    subtitle: _card == null ? 'دفع آمن' : '•••• ${_card!.last4}',
                    onTap: () => setState(() => _method = 'card'),
                  ),
                ),
              ],
            ),
            if (_method == 'card' && _card == null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SoftCard(
                  color: AppColors.gold.withValues(alpha: .1),
                  borderColor: AppColors.gold.withValues(alpha: .35),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'ستُطلب بيانات البطاقة عند تأكيد الحجز (بيئة تجريبية).',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final result = await Navigator.push<CardResult>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PaymentScreen(amount: widget.service.price)),
                          );
                          if (result != null) setState(() => _card = result);
                        },
                        child: const Text('إدخال'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SoftCard(
              child: Column(
                children: [
                  _SummaryRow(label: 'سعر الخدمة', value: fmtMoney(widget.service.price)),
                  const SizedBox(height: 8),
                  _SummaryRow(label: 'رسوم التطبيق', value: fmtMoney(0)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                  _SummaryRow(
                    label: 'الإجمالي',
                    value: fmtMoney(widget.service.price),
                    bold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outline)),
          ),
          child: PrimaryButton(
            label: _method == 'card' && _card == null ? 'متابعة الدفع' : 'تأكيد الحجز',
            icon: _method == 'card' ? Icons.lock_outline_rounded : Icons.check_circle_outline_rounded,
            loading: _loading,
            onPressed: _confirm,
          ),
        ),
      ),
    );
  }

  String _monthShort(int m) =>
      const ['كانون2', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', 'تموز', 'آب', 'أيلول', 'تشرين1', 'تشرين2', 'كانون1'][m - 1];

  static const _slots = [
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
  ];
}

class _PayOption extends StatelessWidget {
  const _PayOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: .16) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppColors.gold : theme.colorScheme.outline,
              width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? AppColors.gold : theme.colorScheme.onSurface.withValues(alpha: .3),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: bold ? 13 : 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: bold ? theme.colorScheme.onSurface : null,
            )),
        const Spacer(),
        Text(value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: bold ? 15 : 12.5,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            )),
      ],
    );
  }
}


