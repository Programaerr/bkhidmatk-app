import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../auth/push_key.dart';
import '../widgets/quick_route.dart';
import '../widgets/ui.dart';
import 'booking_success_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.service, this.workerId});

  final Service service;

  /// الحرفي الذي اختاره الزبون من صفحته، وإلا فحرفي الخدمة نفسها.
  final int? workerId;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final List<DateTime> _days;
  late DateTime _selectedDay;
  String _slot = '10:00';
  int? _workerId;
  List<Worker> _workers = const [];
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
    _workerId = widget.workerId ?? widget.service.workerId;
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
    final list = await context.read<AppState>().repo.listWorkers(
        categoryId: widget.service.categoryId, onlyAvailable: true);
    if (mounted) setState(() => _workers = list);
  }

  Future<void> _pickWorker() async {
    final picked = await showAppSheet<int>(
      context,
      builder: (ctx) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 460),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: SheetHeader(
                title: tr('اختر الفني', 'Choose a technician'),
                subtitle: tr('كل الفنيين موثوقون ومقيّمون من الزبائن',
                    'All technicians are verified and rated by customers'),
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
                                  Text(w.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  Text(
                                      tr(
                                        '${w.specialty} · ${w.jobsDone} عمل${w.city == null ? '' : ' · ${w.city}'}',
                                        '${w.specialty} · ${w.jobsDone} jobs${w.city == null ? '' : ' · ${cityLabel(w.city!)}'}',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 10.5)),
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
    final state = context.read<AppState>();
    final repo = state.repo;
    final user = state.user;
    if (user?.id == null) return;
    if (_address.text.trim().length < 8) {
      AppSnack.show(
          context,
          tr('أدخل عنواناً تفصيلياً للخدمة',
              'Enter a detailed address for the service'),
          error: true);
      return;
    }
    setState(() => _loading = true);
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
        // السعر يُحدد بالاتفاق لاحقاً، ثم يُنشأ الوصل به.
        total: 0,
        createdAt: DateTime.now(),
      ));
      final booking = await repo.bookingById(bookingId);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        QuickRoute(
          builder: (_) => BookingSuccessScreen(booking: booking!),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnack.show(
            context,
            tr('تعذر إنشاء الحجز، حاول مرة أخرى',
                "Couldn't create the booking, please try again"),
            error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = _workers.where((w) => w.id == _workerId);
    final worker = matches.isEmpty ? null : matches.first;

    return Scaffold(
      appBar: PushKeyAppBar(title: tr('حجز الخدمة', 'Book a service')),
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
                    child:
                        const Icon(Icons.home_repair_service_rounded, size: 22),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.service.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                            '${sectionLabel(widget.service.categoryName ?? '')} · ${fmtDuration(widget.service.durationMinutes)}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(
                title: tr('الفني', 'Technician'),
                subtitle: tr('يمكنك ترك الاختيار لنا وسنرسل الأنسب',
                    "You can leave the choice to us and we'll send the best fit")),
            SoftCard(
              onTap: _pickWorker,
              child: Row(
                children: [
                  AvatarCircle(
                      name: worker?.name ?? tr('تلقائي', 'Auto'), size: 42),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            worker?.name ??
                                tr('اختيار تلقائي', 'Automatic choice'),
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontSize: 13.5)),
                        Text(
                            worker?.specialty ??
                                tr('سنختار أفضل فني متاح',
                                    "We'll choose the best available technician"),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 10.5)),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(title: tr('موعد الخدمة', 'Appointment')),
            SizedBox(
              height: 86,
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
                        color: selected
                            ? AppColors.ink
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: selected
                                ? AppColors.ink
                                : theme.colorScheme.outline),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            fmtWeekday(day),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white60
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: .6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: selected
                                  ? AppColors.gold
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            _monthShort(day.month),
                            style: TextStyle(
                              fontSize: 9,
                              color: selected
                                  ? Colors.white54
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: .5),
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
            FieldLabel(tr('الوقت المناسب', 'Preferred time')),
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
                          color: _slot == slot
                              ? AppColors.gold
                              : theme.colorScheme.outline,
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
            SectionHeader(title: tr('عنوان الخدمة', 'Service address')),
            TextField(
              controller: _address,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: tr('المنطقة، الشارع، رقم البناية، أقرب نقطة دالة',
                    'Area, street, building number, nearest landmark'),
                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: tr('ملاحظات إضافية للفني (اختياري)',
                    'Extra notes for the technician (optional)'),
                prefixIcon: Icon(Icons.notes_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 22),
            SoftCard(
              color: AppColors.gold.withValues(alpha: .1),
              borderColor: AppColors.gold.withValues(alpha: .35),
              child: Row(
                children: [
                  Icon(Icons.handshake_outlined, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('السعر يُحدد بالاتفاق بعد مراجعة الإدارة لطلبك، ثم يُضاف إلى وصلك لتدفع لاحقاً.',
                          'The price is agreed after the admin reviews your request, then added to your receipt to pay later.'),
                      style: TextStyle(fontSize: 12, height: 1.6),
                    ),
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
            label: tr('إرسال طلب الحجز', 'Send booking request'),
            icon: Icons.send_rounded,
            loading: _loading,
            onPressed: _confirm,
          ),
        ),
      ),
    );
  }

  String _monthShort(int m) => [
        tr('كانون2', 'Jan'),
        tr('شباط', 'Feb'),
        tr('آذار', 'Mar'),
        tr('نيسان', 'Apr'),
        tr('أيار', 'May'),
        tr('حزيران', 'Jun'),
        tr('تموز', 'Jul'),
        tr('آب', 'Aug'),
        tr('أيلول', 'Sep'),
        tr('تشرين1', 'Oct'),
        tr('تشرين2', 'Nov'),
        tr('كانون1', 'Dec')
      ][m - 1];

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
