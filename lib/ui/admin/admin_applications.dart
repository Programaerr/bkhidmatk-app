import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
      if (mounted) AppSnack.show(context, 'تعذر فتح الاتصال', error: true);
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
                label: 'رقم الهاتف',
                value: a.phone,
                trailing: AppIconButton(
                  small: true,
                  onTap: () => _call(a.phone),
                  icon: Icons.call_rounded,
                  tooltip: 'اتصال',
                ),
              ),
              InfoRow(icon: Icons.cake_outlined, label: 'العمر', value: '${a.age} سنة'),
              InfoRow(icon: Icons.location_city_rounded, label: 'المحافظة', value: a.city),
              InfoRow(icon: Icons.location_on_outlined, label: 'العنوان', value: a.address),
              InfoRow(
                icon: Icons.workspace_premium_outlined,
                label: 'سنوات الخبرة',
                value: '${a.experienceYears}',
              ),
              InfoRow(icon: Icons.notes_rounded, label: 'نبذة عن خبرته', value: a.about),
              InfoRow(
                icon: Icons.event_rounded,
                label: 'تاريخ التقديم',
                value: fmtDate(a.createdAt),
              ),
              if (a.isPending) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'رفض',
                        danger: true,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: 'قبول',
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
      accepted ? 'تم القبول — يصبح حسابه (حرفي) عند التسجيل بهذا الرقم' : 'تم رفض الطلب',
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الحرفيين'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<CraftsmanApplication>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
            }
            final applications = snapshot.data ?? const <CraftsmanApplication>[];
            if (applications.isEmpty) {
              return const EmptyState(
                icon: Icons.assignment_ind_outlined,
                title: 'لا توجد طلبات',
                subtitle: 'تظهر هنا معلومات من يقدّم كحرفي من الشاشة الأولى.',
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
                                '${a.trade} • خبرة ${a.experienceYears} سنة',
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
