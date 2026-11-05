import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../auth/auth_route.dart';
import '../auth/push_key.dart';
import '../widgets/quick_route.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/ui.dart';
import 'booking_detail_screen.dart';
import 'home_keys.dart';

/// مقاسات التصميم المعتمد بالبكسل (إطار عرضه 391).
abstract final class _Design {
  // العنوان أبعد عن وسط الشاشة قليلاً نحو اليمين، كما في التصميم.
  static const titleShift = 4.6;

  // الاختيارات الثلاثة في وسط الشاشة.
  static const choiceTop = 150.1;
  static const choiceGap = 22.4;

  static const listGap = 24.2;

  static const browseWidth = 144.7;
  static const browseHeight = 39.0;
  static const browseRadius = 11.1;
  static const browseTextSize = 13.0;

  static const pageBottom = 24.0;
}

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key, required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab>
    with RealtimeRefresh<BookingsTab> {
  int _filter = 0;
  late Future<List<Booking>> _future;
  final _fold = HeaderFold();

  static const _filters = ['الكل', 'المكتملة', 'الملغاة'];

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fold.dispose();
    super.dispose();
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
        return all.where((b) => b.status == BookingStatus.completed).toList();
      case 2:
        return all.where((b) => b.status == BookingStatus.cancelled).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // شريط الحالة فوق الجهة الصفراء دائماً، نهاراً وليلاً.
      value: appSystemBars(night: false),
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
                    onRefresh: () async => _load(),
                    child: _fold.track(
                      child: FutureBuilder<List<Booking>>(
                        future: _future,
                        builder: (context, snapshot) =>
                            _page(snapshot, constraints.biggest, unit, left, top, night),
                      ),
                    ),
                  ),
                ),
                FoldingHeader(
                  fold: _fold,
                  unit: unit,
                  safeTop: safeTop,
                  top: top,
                  builder: (context, metrics) => HomeHeader(
                    width: width,
                    metrics: metrics,
                    title: 'كل الحجوزات',
                    titleShift: _Design.titleShift,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _page(
    AsyncSnapshot<List<Booking>> snapshot,
    Size size,
    double unit,
    double left,
    double top,
    bool night,
  ) {
    final chromeInset = PushKey.faceInset * unit * homeKeyChrome;
    final barRoom = MediaQuery.paddingOf(context).bottom;
    final choicesTop = _Design.choiceTop - ChoiceKey.touchMargin;
    final choicesBottom = _Design.choiceTop +
        ChoiceKey.faceHeight +
        PushKey.depth * homeKeyChrome +
        ChoiceKey.touchMargin;
    final loading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
    final bookings = _apply(snapshot.data ?? const []);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // يبقى آخر حجز فوق شريط التنقل الزجاجي.
      padding: EdgeInsets.only(bottom: barRoom),
      children: [
        SizedBox(height: top + choicesTop * unit),
        // في وسط الشاشة، ويتحرك جانبياً إذا كبّر الهاتف الخط حتى لم تعد تتسع.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: size.width),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (i, label) in _filters.indexed) ...[
                  if (i > 0) SizedBox(width: _Design.choiceGap * unit - chromeInset * 2),
                  ChoiceKey(
                    label: label,
                    selected: i == _filter,
                    unit: unit,
                    onPressed: () => setState(() => _filter = i),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (loading || bookings.isEmpty) ...[
          SizedBox(
            height: _browseTop(size.height - barRoom, top, unit) - (top + choicesBottom * unit),
          ),
          // بلا حجوزات يبقى زر التصفح وحده في الصفحة.
          Center(
            child: _browseRoom(
              unit,
              loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                  : _browseKey(unit, night),
            ),
          ),
          SizedBox(height: _Design.pageBottom * unit),
        ] else ...[
          SizedBox(
            height: (_Design.choiceTop + ChoiceKey.faceHeight + _Design.listGap - choicesBottom) *
                unit,
          ),
          for (final (i, booking) in bookings.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: left + 18),
              child: _BookingCard(booking: booking, onChanged: _load),
            ),
          ],
          const SizedBox(height: 26),
        ],
      ],
    );
  }

  /// أعلى زر التصفح: في وسط المكان الفارغ بين الاختيارات وشريط التنقل، ولا يلتصق بالاختيارات.
  double _browseTop(double barTop, double top, double unit) {
    final chromeDepth = PushKey.depth * homeKeyChrome;
    final choicesEnd = top + (_Design.choiceTop + ChoiceKey.faceHeight + chromeDepth) * unit;
    final browseHeight = (_Design.browseHeight + chromeDepth) * unit;
    return math.max(
      choicesEnd + _Design.listGap * unit,
      (choicesEnd + barTop - browseHeight) / 2,
    );
  }

  /// مكان زر التصفح مع جانبه وقاعدته.
  Widget _browseRoom(double unit, Widget child) {
    final chrome = unit * homeKeyChrome;
    return SizedBox(
      width: _Design.browseWidth * unit + PushKey.faceInset * 2 * chrome,
      height: _Design.browseHeight * unit + PushKey.depth * chrome,
      child: child,
    );
  }

  Widget _browseKey(double unit, bool night) {
    return Semantics(
      button: true,
      label: 'تصفح الحرفيين',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onBrowse,
        child: PushKey(
          unit: unit * homeKeyChrome,
          faceHeight: _Design.browseHeight * unit,
          faceRadius: _Design.browseRadius,
          lemon: true,
          night: night ? kAlwaysCompleteAnimation : kAlwaysDismissedAnimation,
          child: ExcludeSemantics(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'تصفح الحرفيين',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: _Design.browseTextSize * unit,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: homeInk,
                  ),
                ),
              ),
            ),
          ),
        ),
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
          QuickRoute(builder: (_) => BookingDetailScreen(bookingId: booking.id!)),
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
          if (booking.customerAck == CustomerAck.pending) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.edit_calendar_rounded, size: 15, color: AppColors.goldDeep),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'عدّلت الإدارة حجزك، افتحه ووافق على التعديل',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface),
                  ),
                ),
              ],
            ),
          ],
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
              Text(bookingPriceLabel(booking),
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 12.5)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}
