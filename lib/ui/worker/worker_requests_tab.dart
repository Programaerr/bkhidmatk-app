import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../auth/auth_route.dart';
import '../customer/home_keys.dart';
import '../customer/notifications_screen.dart';
import '../widgets/quick_route.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';

/// طلبات الحرفي: الحجوزات التي طلبها الزبائن باسمه. يؤكدها أو يعتذر عنها، وبعد أن ترسله الإدارة
/// يظهر له عنوان الزبون ورقمه فيذهب إليه مباشرة.
class WorkerRequestsTab extends StatefulWidget {
  const WorkerRequestsTab({super.key});

  @override
  State<WorkerRequestsTab> createState() => _WorkerRequestsTabState();
}

class _WorkerRequestsTabState extends State<WorkerRequestsTab>
    with RealtimeRefresh<WorkerRequestsTab> {
  late Future<List<Booking>> _future;
  final _fold = HeaderFold();
  int? _answering;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void dispose() {
    _fold.dispose();
    super.dispose();
  }

  Future<List<Booking>> _fetch() {
    final state = context.read<AppState>();
    return state.repo.bookingsForWorker(state.user!);
  }

  Future<void> _load() async {
    final next = _fetch();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _respond(Booking booking, bool accept) async {
    if (!accept) {
      final ok = await confirmAction(
        context,
        title: 'الاعتذار عن الحجز؟',
        message: 'سيصل اعتذارك إلى الإدارة لتعيّن حرفياً آخر.',
        confirmLabel: 'اعتذار',
        danger: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _answering = booking.id);
    try {
      await context.read<AppState>().repo.respondToBooking(booking.id!, accept: accept);
      if (!mounted) return;
      AppSnack.show(context, accept ? 'تم تأكيد قبولك للحجز' : 'وصل اعتذارك إلى الإدارة');
    } catch (_) {
      if (mounted) AppSnack.show(context, 'تعذر إرسال ردك، حاول مرة أخرى', error: true);
    }
    if (mounted) {
      setState(() => _answering = null);
      _load();
    }
  }

  Future<void> _call(String phone) async {
    if (!await launchUrl(Uri.parse('tel:${phoneForCall(phone)}')) && mounted) {
      AppSnack.show(context, 'تعذر فتح تطبيق الاتصال', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // شريط الحالة فوق الجهة الزرقاء، فأيقوناته بيضاء.
      value: appSystemBars(night: true),
      child: ColoredBox(
        color: night ? homeNightGround : homeCream,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final unit = homeUnit(width);
            final left = (width - homeDesignWidth * unit) / 2;
            final top = homePageTop(safeTop, unit);
            final hillBottom = homeHillBottom(top, unit);
            return Stack(
              children: [
                Positioned.fill(
                  child: RefreshIndicator(
                    edgeOffset: hillBottom,
                    onRefresh: _load,
                    child: _fold.track(
                      child: FutureBuilder<List<Booking>>(
                        future: _future,
                        builder: (context, snapshot) => _list(snapshot, hillBottom),
                      ),
                    ),
                  ),
                ),
                FoldingHeader(
                  fold: _fold,
                  unit: unit,
                  safeTop: safeTop,
                  top: top,
                  builder: (context, metrics) => Stack(
                    fit: StackFit.expand,
                    children: [
                      HomeHeader(width: width, metrics: metrics, title: 'طلبات الحجز'),
                      Positioned(
                        left: left + 14,
                        top: metrics.centerY(61.5) - 24,
                        child: Transform.scale(
                          scale: metrics.scale,
                          child: AppIconButton(
                            icon: Icons.notifications_none_rounded,
                            tooltip: 'الإشعارات',
                            onTap: () => Navigator.push(
                              context,
                              QuickRoute(builder: (_) => const NotificationsScreen()),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _list(AsyncSnapshot<List<Booking>> snapshot, double hillBottom) {
    final barRoom = MediaQuery.paddingOf(context).bottom;
    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
      return ListView(
        padding: EdgeInsets.only(top: hillBottom),
        children: const [
          Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          ),
        ],
      );
    }
    final bookings = snapshot.data ?? const <Booking>[];
    if (snapshot.hasError || bookings.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: hillBottom, bottom: barRoom),
        children: [
          EmptyState(
            icon: snapshot.hasError ? Icons.cloud_off_rounded : Icons.assignment_outlined,
            title: snapshot.hasError ? 'تعذّر جلب الطلبات' : 'لا توجد طلبات بعد',
            subtitle: snapshot.hasError
                ? 'تأكد من الاتصال، وأن رقم حسابك مضاف حرفياً عند الإدارة، ثم اسحب للتحديث.'
                : 'عندما يطلب زبون حجزاً باسمك يظهر هنا.',
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(18, hillBottom + 14, 18, barRoom + 16),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _RequestCard(
        booking: bookings[i],
        busy: _answering == bookings[i].id,
        onRespond: (accept) => _respond(bookings[i], accept),
        onCall: _call,
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.booking,
    required this.busy,
    required this.onRespond,
    required this.onCall,
  });

  final Booking booking;
  final bool busy;
  final ValueChanged<bool> onRespond;
  final ValueChanged<String> onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = booking;
    final canAnswer = b.workerResponse == WorkerResponse.pending &&
        (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed);
    final phone = b.customerPhone;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.serviceTitle ?? 'خدمة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
                ),
              ),
              StatusPill(status: b.status, dense: true),
            ],
          ),
          const SizedBox(height: 6),
          Text('الزبون: ${b.customerName ?? 'زبون'}', style: theme.textTheme.bodyMedium),
          Text(
            '${fmtDate(b.scheduledAt)} · ${fmtSlot(b.slot)}',
            style: theme.textTheme.bodySmall,
          ),
          if (b.notes != null && b.notes!.isNotEmpty)
            Text('ملاحظات: ${b.notes}', style: theme.textTheme.bodySmall),
          const Divider(height: 22),
          if (b.sentToCustomer) ...[
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    b.address.isEmpty ? 'العنوان عند الإدارة' : b.address,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'اتصال بالزبون',
                icon: Icons.call_outlined,
                compact: true,
                onPressed: () => onCall(phone),
              ),
            ],
          ] else if (b.status == BookingStatus.cancelled) ...[
            Text('أُلغي هذا الحجز.', style: theme.textTheme.bodySmall),
          ] else if (canAnswer) ...[
            Text(
              'الزبون طلبك لهذا الحجز. أكّد قبولك أو اعتذر، وستظهر لك بياناته بعد أن ترسلك الإدارة.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'موافق',
                    compact: true,
                    loading: busy,
                    onPressed: () => onRespond(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SecondaryButton(
                    label: 'اعتذار',
                    compact: true,
                    danger: true,
                    onPressed: busy ? null : () => onRespond(false),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              b.workerResponse == WorkerResponse.declined
                  ? 'اعتذرت عن هذا الحجز.'
                  : 'أكّدت قبولك. بانتظار أن ترسلك الإدارة إلى الزبون.',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
