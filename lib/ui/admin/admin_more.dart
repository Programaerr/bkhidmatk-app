import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../customer/messages_screen.dart';
import '../customer/receipts_screen.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'admin_hires.dart';
import 'admin_shell.dart';
import 'admin_threads.dart';

class AdminMore extends StatefulWidget {
  const AdminMore({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<AdminMore> createState() => _AdminMoreState();
}

class _AdminMoreState extends State<AdminMore> with RealtimeRefresh<AdminMore> {
  Future<AppStats>? _stats;

  /// حالة البانر الرئيسي في الصفحة الرئيسية للزبائن.
  bool? _showBanner;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<AppState>().repo;
    final future = repo.stats();
    final banner = repo.getSetting('show_hero_banner', fallback: '0');
    if (mounted) {
      setState(() {
        _stats = future;
      });
      banner.then((value) {
        if (mounted) setState(() => _showBanner = value == '1');
      });
    }
  }

  Future<void> _toggleBanner(bool value) async {
    setState(() => _showBanner = value);
    await context.read<AppState>().repo.setSetting(
          'show_hero_banner',
          value ? '1' : '0',
        );
    if (!mounted) return;
    AppSnack.show(
      context,
      value ? 'تم تفعيل البانر الرئيسي' : 'تم إخفاء البانر الرئيسي',
    );
  }

  Future<void> _logout() async {
    final ok = await confirmAction(
      context,
      title: 'تسجيل الخروج',
      message: 'هل تريد الخروج من لوحة التحكم؟',
      confirmLabel: 'خروج',
      danger: true,
    );
    if (ok && mounted) await context.read<AppState>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final user = state.user!;
    return Column(
      children: [
        AdminHeader(
          title: 'المزيد',
          subtitle: 'الإدارة، الزبائن، والإعدادات',
          actions: [
            AppIconButton(icon: Icons.refresh_rounded, onTap: _load),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF111113), Color(0xFF332D07)],
                  ),
                ),
                child: Row(
                  children: [
                    AvatarCircle(name: user.name, size: 54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.phone,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'صلاحيات كاملة',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FutureBuilder<AppStats>(
                      future: _stats,
                      builder: (context, snapshot) {
                        final s = snapshot.data;
                        return Column(
                          children: [
                            Text(
                              '${s?.customers ?? 0}',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text('زبون',
                                style:
                                    TextStyle(color: Colors.white54, fontSize: 9)),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'إدارة التطبيق'),
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Tile(
                      icon: Icons.people_alt_rounded,
                      title: 'الزبائن',
                      subtitle: 'عرض الحسابات والتواصل معهم',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminCustomersScreen()),
                      ),
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.forum_rounded,
                      title: 'الرسائل',
                      subtitle: 'محادثات الزبائن والدعم',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminThreadsScreen()),
                      ).then((_) => _load()),
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.receipt_long_rounded,
                      title: 'الوصولات',
                      subtitle: 'كل وصولات الدفع القابلة للطباعة',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReceiptsScreen(adminMode: true)),
                      ),
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.event_note_rounded,
                      title: 'الحجوزات',
                      subtitle: 'متابعة وتحديث حالات الحجز',
                      onTap: () => widget.onNavigate(1),
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.handyman_rounded,
                      title: 'الخدمات والفنيون',
                      subtitle: 'إضافة وتعديل الخدمات والأقسام',
                      onTap: () => widget.onNavigate(2),
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'التوظيف',
                      subtitle: 'إضافة أرقام موظفين ومتابعة التسجيل',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminHiresScreen()),
                      ).then((_) => _load()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const SectionHeader(title: 'الإعدادات'),
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Tile(
                      icon: Icons.support_agent_rounded,
                      title: 'بيانات الدعم',
                      subtitle: 'رقم الدعم الظاهر للزبائن في الوصولات',
                      onTap: () => _editSupportPhone(context),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      value: _showBanner ?? false,
                      onChanged: _toggleBanner,
                      secondary: Icon(
                        (_showBanner ?? false)
                            ? Icons.web_asset_rounded
                            : Icons.web_asset_off_rounded,
                        size: 20,
                      ),
                      title: const Text('البانر الرئيسي',
                          style:
                              TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: const Text('إظهار البانر في أعلى الصفحة الرئيسية',
                          style: TextStyle(fontSize: 10.5)),
                    ),
                    const Divider(height: 1),
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
                          style:
                              TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: const Text('تغيير مظهر التطبيق بالكامل',
                          style: TextStyle(fontSize: 10.5)),
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.restart_alt_rounded,
                      title: 'إعادة ضبط البيانات التجريبية',
                      subtitle: 'حذف كل التعديلات والعودة لبيانات البداية',
                      danger: true,
                      onTap: () async {
                        final ok = await confirmAction(
                          context,
                          title: 'إعادة الضبط؟',
                          message:
                              'سيتم حذف كل الحجوزات والأعمال والزبائن الذين أنشأتهم، والعودة للبيانات التجريبية الأصلية.',
                          confirmLabel: 'إعادة الضبط',
                          danger: true,
                        );
                        if (!ok) return;
                        await context.read<AppState>().repo.resetDemoData();
                        if (!mounted) return;
                        await context.read<AppState>().logout();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SoftCard(
                padding: EdgeInsets.zero,
                child: _Tile(
                  icon: Icons.info_outline_rounded,
                  title: 'عن جايك',
                  subtitle: 'الإصدار 1.0.0 · Jaik',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'جايك',
                    applicationVersion: '1.0.0',
                    applicationIcon: const BrandLogo(size: 56, radius: 16),
                    children: const [
                      Text(
                        'منصة الخدمات المنزلية الأولى في العراق: حجز عمال موثوقين، دفع بماستركارد، ووصولات إلكترونية قابلة للطباعة.',
                        style: TextStyle(fontSize: 12, height: 1.8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 14),
              Center(
                child: Text('جايك · لوحة الإدارة',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editSupportPhone(BuildContext context) async {
    final repo = context.read<AppState>().repo;
    final current = await repo.getSetting('admin_phone', fallback: '07700000000');
    if (!context.mounted) return;
    final controller = TextEditingController(text: current);
    final saved = await showAppSheet<bool>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader(
              title: 'رقم الدعم',
              subtitle: 'يظهر في صفحة الدعم ووصولات الدفع',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                hintText: '07XXXXXXXXX',
                prefixIcon: Icon(Icons.phone_iphone_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'حفظ',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (saved == true && validIraqiPhone(controller.text)) {
      await repo.setSetting('admin_phone', normalizePhone(controller.text));
      if (context.mounted) AppSnack.show(context, 'تم تحديث رقم الدعم');
    }
    controller.dispose();
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (danger ? AppColors.danger : AppColors.gold).withValues(alpha: .15),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          icon,
          size: 19,
          color: danger ? AppColors.danger : null,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: danger ? AppColors.danger : null,
        ),
      ),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
      trailing: const Icon(Icons.chevron_left_rounded, size: 20),
    );
  }
}

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen>
    with RealtimeRefresh<AdminCustomersScreen> {
  final _search = TextEditingController();
  String _query = '';
  late Future<List<AppUser>> _future;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().repo.listCustomers(query: _query);
    });
  }

  Future<void> _call(String phone) async {
    if (!await launchUrl(Uri.parse('tel:${phoneForCall(phone)}'))) {
      if (mounted) AppSnack.show(context, 'تعذر فتح تطبيق الاتصال', error: true);
    }
  }

  Future<void> _sms(String phone) async {
    if (!await launchUrl(Uri.parse('sms:${phoneForCall(phone)}'))) {
      if (mounted) AppSnack.show(context, 'تعذر فتح تطبيق الرسائل', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('الزبائن'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: TextField(
                controller: _search,
                onChanged: (v) {
                  _query = v;
                  _load();
                },
                decoration: const InputDecoration(
                  hintText: 'ابحث بالاسم أو رقم الهاتف...',
                  prefixIcon: Icon(Icons.search_rounded, size: 21),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<AppUser>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.4));
                  }
                  final users = snapshot.data ?? const <AppUser>[];
                  if (users.isEmpty) {
                    return const EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'لا يوجد زبائن',
                      subtitle: 'سيظهر هنا كل زبون ينشئ حساباً في التطبيق.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final u = users[i];
                      return SoftCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            AvatarCircle(name: u.name, size: 44),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(fontSize: 13)),
                                  Text(
                                    u.phone,
                                    textDirection: TextDirection.ltr,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(fontSize: 10.5),
                                  ),
                                  Text(
                                    '${u.city ?? 'العراق'} · ${fmtDateShort(u.createdAt)}',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(fontSize: 9.5),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _call(u.phone),
                              icon: const Icon(Icons.call_outlined, size: 19),
                              tooltip: 'اتصال',
                            ),
                            IconButton(
                              onPressed: () => _sms(u.phone),
                              icon: const Icon(Icons.sms_outlined, size: 19),
                              tooltip: 'رسالة',
                            ),
                            IconButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MessagesScreen(
                                    threadId: u.id,
                                    threadName: u.name,
                                    threadPhone: u.phone,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline_rounded,
                                  size: 19),
                              tooltip: 'محادثة',
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
