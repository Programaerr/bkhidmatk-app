import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../auth/push_key.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';

/// طلبات الحرفيين: الإدارة تقرأ معلومات المتقدم، وعند القبول يدخل رقمه في التوظيف
/// فيصبح حسابه (حرفي) عند التسجيل.
class AdminApplicationsScreen extends StatefulWidget {
  const AdminApplicationsScreen({super.key});

  @override
  State<AdminApplicationsScreen> createState() => _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends State<AdminApplicationsScreen>
    with RealtimeRefresh<AdminApplicationsScreen> {
  late Future<List<CraftsmanApplication>> _future;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().repo.listApplications();
    });
  }

  Future<void> _call(String phone) async {
    if (!await launchUrl(Uri.parse('tel:${phoneForCall(phone)}'))) {
      if (mounted) AppSnack.show(context, tr('تعذر فتح الاتصال', "Couldn't open the call"), error: true);
    }
  }

  Future<void> _open(CraftsmanApplication a) async {
    final accepted = await showAppSheet<bool>(
      context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHeader(title: a.name, subtitle: a.trade, action: _StatusChip(a)),
              const SizedBox(height: 10),
              InfoRow(
                icon: Icons.phone_iphone_rounded,
                label: tr('رقم الهاتف', 'Phone number'),
                value: a.phone,
                trailing: AppIconButton(
                  small: true,
                  onTap: () => _call(a.phone),
                  icon: Icons.call_rounded,
                  tooltip: tr('اتصال', 'Call'),
                ),
              ),
              InfoRow(icon: Icons.cake_outlined, label: tr('العمر', 'Age'), value: tr('${a.age} سنة', '${a.age} years')),
              InfoRow(icon: Icons.location_city_rounded, label: tr('المحافظة', 'Province'), value: cityLabel(a.city)),
              InfoRow(icon: Icons.location_on_outlined, label: tr('العنوان', 'Address'), value: a.address),
              InfoRow(
                icon: Icons.workspace_premium_outlined,
                label: tr('سنوات الخبرة', 'Years of experience'),
                value: '${a.experienceYears}',
              ),
              InfoRow(icon: Icons.notes_rounded, label: tr('نبذة عن خبرته', 'About their experience'), value: a.about),
              InfoRow(
                icon: Icons.event_rounded,
                label: tr('تاريخ التقديم', 'Applied on'),
                value: fmtDate(a.createdAt),
              ),
              if (a.isPending) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: tr('رفض', 'Reject'),
                        danger: true,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: tr('قبول', 'Accept'),
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (accepted == null || !mounted) return;
    final repo = context.read<AppState>().repo;
    if (accepted) {
      await repo.acceptApplication(a);
    } else {
      await repo.rejectApplication(a.id!);
    }
    if (!mounted) return;
    AppSnack.show(
      context,
      accepted ? tr('تم القبول — يصبح حسابه (حرفي) عند التسجيل بهذا الرقم', 'Accepted. Their account becomes (craftsman) when they sign up with this number') : tr('تم رفض الطلب', 'The request was rejected'),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: PushKeyAppBar(title: tr('طلبات الحرفيين', 'Craftsman applications')),
      body: SafeArea(
        child: FutureBuilder<List<CraftsmanApplication>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
            }
            final applications = snapshot.data ?? const <CraftsmanApplication>[];
            if (applications.isEmpty) {
              return EmptyState(
                icon: Icons.assignment_ind_outlined,
                title: tr('لا توجد طلبات', 'No applications'),
                subtitle: tr('تظهر هنا معلومات من يقدّم كحرفي من الشاشة الأولى.', 'Details of anyone who applies as a craftsman from the first screen appear here.'),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                itemCount: applications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final a = applications[i];
                  return SoftCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => _open(a),
                    child: Row(
                      children: [
                        AvatarCircle(name: a.name, size: 44),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                              ),
                              Text(
                                tr('${a.trade} • خبرة ${a.experienceYears} سنة', '${a.trade} • ${a.experienceYears} years of experience'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                              ),
                              Text(
                                a.phone,
                                textDirection: TextDirection.ltr,
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        _StatusChip(a),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.application);

  final CraftsmanApplication application;

  @override
  Widget build(BuildContext context) {
    final color = switch (application.status) {
      CraftsmanApplication.accepted => AppColors.success,
      CraftsmanApplication.rejected => AppColors.danger,
      _ => const Color(0xFFF59E0B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        application.statusLabel,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}
