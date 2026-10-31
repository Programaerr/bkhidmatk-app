import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../state/app_state.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/ui.dart';
import 'messages_screen.dart';
import 'receipts_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.onOpenBookings,
    this.workerMode = false,
  });

  final VoidCallback onOpenBookings;

  /// وضع الموظف بالتوضيف: يُخفى كل ما لا يخصه (حجوزات، وصولات، نقاط).
  final bool workerMode;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with RealtimeRefresh<ProfileTab> {
  Future<List<int>>? _stats;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final state = context.read<AppState>();
    final id = state.user!.id!;
    setState(() {
      _stats = Future.wait([
        state.repo.bookingsForCustomer(id).then((v) => v.length),
        state.repo.receiptsForUser(id).then((v) => v.length),
      ]);
    });
  }

  Future<void> _editProfile() async {
    final state = context.read<AppState>();
    final user = state.user!;
    final name = TextEditingController(text: user.name);
    final address = TextEditingController(text: user.address ?? '');
    String city = user.city ?? 'بغداد';

    final saved = await showAppSheet<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetHeader(title: 'تعديل الملف الشخصي'),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showAppSheet<String>(
                    context,
                    builder: (ctx) => ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 440),
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                            child: SheetHeader(title: 'المحافظة'),
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              children: [
                                for (final c in iraqCities)
                                  ListTile(
                                    title: Text(c),
                                    onTap: () => Navigator.pop(ctx, c),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (picked != null) setSheetState(() => city = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_city_rounded, size: 20),
                    suffixIcon: Icon(Icons.expand_more_rounded, size: 20),
                  ),
                  child: Text(city),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'حفظ التغييرات',
                onPressed: () => Navigator.pop(ctx, true),
              ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      await state.updateProfile(user.copyWith(
        name: name.text.trim().isEmpty ? user.name : name.text.trim(),
        city: city,
        address: address.text.trim(),
      ));
      if (mounted) AppSnack.show(context, 'تم تحديث بياناتك');
      _load();
    }
  }

  Future<void> _logout() async {
    final ok = await confirmAction(context,
        title: 'تسجيل الخروج',
        message: 'هل تريد تسجيل الخروج من حسابك؟',
        confirmLabel: 'خروج',
        danger: true);
    if (ok && mounted) await context.read<AppState>().logout();
  }

  void _about() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 74, radius: 20),
            const SizedBox(height: 10),
            const BrandTitle(fontSize: 22),
            const SizedBox(height: 4),
            Text('الإصدار 1.0.0',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontSize: 10.5)),
            const SizedBox(height: 12),
            const Text(
              'منصة عراقية تربط الزبائن بعمال وفنيين موثوقين: كهرباء، صباغة، سباكة، ديكور، تنظيف وأكثر.\n\nالدفع بماستركارد، وصولات إلكترونية قابلة للطباعة، ومتابعة كاملة للحجز.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.8),
            ),
            const SizedBox(height: 12),
            Text('الدعم: 0770 000 0000',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final user = state.user!;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF111113), Color(0xFF2E2907)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AvatarCircle(name: user.name, size: 58, imagePath: user.avatarPath),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(user.phone,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 12, color: AppColors.gold),
                              const SizedBox(width: 3),
                              Text(user.city ?? 'العراق',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // وضع الموظف: بدون إحصائيات حجوزات أو وصولات.
                if (!widget.workerMode)
                  FutureBuilder<List<int>>(
                    future: _stats,
                    builder: (context, snapshot) {
                      final s = snapshot.data ?? const [0, 0];
                      return Row(
                        children: [
                          _Stat(label: 'حجز', value: '${s[0]}'),
                          Container(
                              width: 1,
                              height: 30,
                              color: Colors.white.withValues(alpha: .1)),
                          _Stat(label: 'وصل', value: '${s[1]}'),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          if (!widget.workerMode) ...[
            const SizedBox(height: 16),
            // ------------------------------------------------ بطاقة النقاط
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [AppColors.gold, AppColors.goldDeep],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: AppColors.ink, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${user.points} نقطة',
                            style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.1)),
                        const SizedBox(height: 2),
                        Text(
                          'رصيد مكافآتك — اجمعها بتقييم الفنيين',
                          style: TextStyle(
                              color: AppColors.ink.withValues(alpha: .7),
                              fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (!widget.workerMode) ...[
                  _MenuTile(
                    icon: Icons.event_note_rounded,
                    title: 'حجوزاتي',
                    subtitle: 'كل حجوزاتك وحالتها',
                    onTap: widget.onOpenBookings,
                  ),
                  const Divider(height: 1),
                  _MenuTile(
                    icon: Icons.receipt_long_rounded,
                    title: 'وصولات الدفع',
                    subtitle: 'معاينة وطباعة الوصولات',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReceiptsScreen()),
                      );
                      _load();
                    },
                  ),
                  const Divider(height: 1),
                ],
                _MenuTile(
                  icon: Icons.support_agent_rounded,
                  title: 'الرسائل والدعم',
                  subtitle: 'تواصل مع إدارة جايك',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: state.themeMode == ThemeMode.dark,
                  onChanged: (v) => state.setTheme(v),
                  secondary: Icon(
                    state.themeMode == ThemeMode.dark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    size: 20,
                  ),
                  title: const Text('الوضع الليلي',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: const Text('مريح للعين في الإضاءة المنخفضة',
                      style: TextStyle(fontSize: 10.5)),
                ),
                const Divider(height: 1),
                _MenuTile(
                  icon: Icons.info_outline_rounded,
                  title: 'عن جايك',
                  subtitle: 'الإصدار 1.0.0',
                  onTap: _about,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('تسجيل الخروج'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger.withValues(alpha: .3)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('جايك · صُنع بحب في العراق',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
      trailing: const Icon(Icons.chevron_left_rounded, size: 20),
    );
  }
}
