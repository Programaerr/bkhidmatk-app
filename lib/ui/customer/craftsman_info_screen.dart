import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../auth/push_key.dart';
import '../widgets/quick_route.dart';
import '../widgets/ui.dart';
import 'booking_flow.dart';
import 'guest_gate.dart';
import 'home_keys.dart';
import 'messages_screen.dart';

const _circleSize = 96.0;

/// معلومات الحرفي بعد الضغط على زره، وخدماته التي يُحجز منها.
class CraftsmanInfoScreen extends StatefulWidget {
  const CraftsmanInfoScreen({super.key, required this.worker});

  final Worker worker;

  @override
  State<CraftsmanInfoScreen> createState() => _CraftsmanInfoScreenState();
}

class _CraftsmanInfoScreenState extends State<CraftsmanInfoScreen> {
  late final Future<List<Service>> _services = _loadServices();

  /// خدمات قسمه، وما كان منها لحرفي آخر لا يظهر هنا.
  Future<List<Service>> _loadServices() async {
    final worker = widget.worker;
    final all = await context
        .read<AppState>()
        .repo
        .listServices(categoryId: worker.categoryId);
    final own = all
        .where((s) => s.workerId == null || s.workerId == worker.id)
        .toList();
    return own.isEmpty ? all : own;
  }

  @override
  Widget build(BuildContext context) {
    final worker = widget.worker;
    final theme = Theme.of(context);
    final night = theme.brightness == Brightness.dark;
    final ground = night ? homeNightGround : homeCream;
    final ink = night ? homeNightInk : homeLabel;
    final bio = worker.bio?.trim() ?? '';
    return Scaffold(
      backgroundColor: ground,
      appBar: PushKeyAppBar(
          title: tr('معلومات الحرفي', 'Craftsman info'),
          backgroundColor: ground),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        children: [
          Center(
            child: Container(
              width: _circleSize,
              height: _circleSize,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x40000000),
                      offset: Offset(0, 4),
                      blurRadius: 10),
                ],
              ),
              child: Center(
                child: PersonFace(
                  name: worker.name,
                  imagePath: worker.avatarPath,
                  size: _circleSize,
                  color: homeInk,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            worker.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 19,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          Text(
            worker.specialty,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          if (worker.city != null && worker.city!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_rounded, size: 15, color: ink),
                  const SizedBox(width: 4),
                  Text(
                    cityLabel(worker.city!),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Fact(
                  icon: Icons.star_rounded,
                  value: worker.rating.toStringAsFixed(1),
                  label: tr('التقييم', 'Rating'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Fact(
                  icon: Icons.task_alt_rounded,
                  value: '${worker.jobsDone}',
                  label: tr('عمل منجز', 'Jobs done'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Fact(
                  icon: Icons.event_available_rounded,
                  value: worker.available
                      ? tr('متاح', 'Available')
                      : tr('مشغول', 'Busy'),
                  label: tr('الحالة', 'Status'),
                ),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            SoftCard(
              child: Text(bio, style: theme.textTheme.bodyMedium),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            tr('احجز خدمة', 'Book a service'),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Service>>(
            future: _services,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.4)),
                );
              }
              final services = snapshot.data ?? const <Service>[];
              if (snapshot.hasError || services.isEmpty) {
                return Column(
                  children: [
                    Text(
                      snapshot.hasError
                          ? tr('تعذّر جلب الخدمات الآن.',
                              "Couldn't load the services right now.")
                          : tr(
                              'لا توجد خدمات لهذا القسم بعد. راسل جايك ونرتب لك الموعد.',
                              'No services in this category yet. Message Jaik and we will arrange the appointment for you.'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: ink),
                    ),
                    const SizedBox(height: 10),
                    SecondaryButton(
                      label: tr('مراسلة جايك', 'Message Jaik'),
                      icon: Icons.chat_bubble_outline_rounded,
                      onPressed: () {
                        // الضيف لا يراسل، فيُطلب منه تسجيل الدخول أولاً.
                        if (!hasAccount(context)) return;
                        Navigator.push(
                          context,
                          QuickRoute(builder: (_) => const MessagesScreen()),
                        );
                      },
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  for (final service in services)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ServiceRow(
                        service: service,
                        onBook: () => startServiceBooking(context, service,
                            workerId: worker.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, required this.onBook});

  final Service service;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('المدة المتوقعة: ${fmtDuration(service.durationMinutes)}',
                      'Expected time: ${fmtDuration(service.durationMinutes)}'),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PrimaryButton(
              label: tr('احجز', 'Book'),
              compact: true,
              expand: false,
              onPressed: onBook),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: theme.textTheme.titleSmall),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
          ),
        ],
      ),
    );
  }
}
