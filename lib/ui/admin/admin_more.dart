import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../customer/messages_screen.dart';
import '../auth/push_key.dart';
import '../customer/receipts_screen.dart';
import '../widgets/quick_route.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'admin_applications.dart';
import 'admin_hires.dart';
import 'admin_shell.dart';
import 'admin_threads.dart';

/// «المزيد» في لوحة التحكم: ما لا يملك تبويباً خاصاً به. الحجوزات والخدمات والأعمال في تبويباتها،
/// والمظهر وتسجيل الخروج في صفحة الحساب، فلا تتكرر هنا.
class AdminMore extends StatefulWidget {
  const AdminMore({super.key});

  @override
  State<AdminMore> createState() => _AdminMoreState();
}

class _AdminMoreState extends State<AdminMore> with RealtimeRefresh<AdminMore> {
  Future<AppStats>? _stats;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final future = context.read<AppState>().repo.stats();
    if (mounted) {
      setState(() {
        _stats = future;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final user = state.user!;
    return Column(
      children: [
        AdminHeader(
          title: tr('المزيد', 'More'),
          subtitle: tr('الزبائن والتوظيف والإعدادات', 'Customers, hiring and settings'),
          actions: [
            AppIconButton(
              icon: Icons.refresh_rounded,
              tooltip: tr('تحديث', 'Refresh'),
              onTap: _load,
            ),
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
                  color: const Color(0xFF17171B),
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
                            child: Text(
                              tr('صلاحيات كاملة', 'Full permissions'),
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.onGold,
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
                            Text(tr('زبون', 'Customer'),
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
              SectionHeader(title: tr('إدارة التطبيق', 'App management')),
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Tile(
                      icon: Icons.people_alt_rounded,
                      title: tr('الزبائن', 'Customers'),
                      subtitle: tr('عرض الحسابات والتواصل معهم', 'View accounts and contact them'),
                      onTap: () => Navigator.push(
                        context,
                        QuickRoute(builder: (_) => const AdminCustomersScreen()),
                      ),
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.forum_rounded,
                      title: tr('الرسائل', 'Messages'),
                      subtitle: tr('محادثات الزبائن والدعم', 'Customer chats and support'),
                      onTap: () => Navigator.push(
                        context,
                        QuickRoute(builder: (_) => const AdminThreadsScreen()),
                      ).then((_) => _load()),
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.receipt_long_rounded,
                      title: tr('الوصولات', 'Receipts'),
                      subtitle: tr('كل وصولات الدفع القابلة للطباعة', 'All printable payment receipts'),
                      onTap: () => Navigator.push(
                        context,
                        QuickRoute(
                            builder: (_) => const ReceiptsScreen(adminMode: true)),
                      ),
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: tr('التوظيف', 'Hiring'),
                      subtitle: tr('إضافة أرقام موظفين ومتابعة التسجيل', 'Add employee numbers and follow sign-ups'),
                      onTap: () => Navigator.push(
                        context,
                        QuickRoute(builder: (_) => const AdminHiresScreen()),
                      ).then((_) => _load()),
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.assignment_ind_outlined,
                      title: tr('طلبات الحرفيين', 'Craftsman applications'),
                      subtitle: tr('قراءة معلومات المتقدمين وقبولهم أو رفضهم', 'Read applicant details and accept or reject them'),
                      onTap: () => Navigator.push(
                        context,
                        QuickRoute(builder: (_) => const AdminApplicationsScreen()),
                      ).then((_) => _load()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionHeader(title: tr('الإعدادات', 'Settings')),
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Tile(
                      icon: Icons.link_rounded,
                      title: tr('روابط التواصل', 'Social links'),
                      subtitle: tr('تحديد روابط فيسبوك وإنستغرام وتيك توك', 'Set the Facebook, Instagram and TikTok links'),
                      onTap: _editSocialLinks,
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.support_agent_rounded,
                      title: tr('بيانات الدعم', 'Support details'),
                      subtitle: tr('رقم الدعم الظاهر للزبائن في الوصولات', 'The support number customers see on receipts'),
                      onTap: () => _editSupportPhone(context),
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.restart_alt_rounded,
                      title: tr('إعادة ضبط البيانات التجريبية', 'Reset demo data'),
                      subtitle: tr('حذف كل التعديلات والعودة لبيانات البداية', 'Delete all changes and go back to the starting data'),
                      danger: true,
                      onTap: () async {
                        final ok = await confirmAction(
                          context,
                          title: tr('إعادة الضبط؟', 'Reset?'),
                          message:
                              tr('سيتم حذف كل الحجوزات والأعمال والزبائن الذين أنشأتهم، والعودة للبيانات التجريبية الأصلية.', 'All bookings, works and customers you created will be deleted, and the original demo data restored.'),
                          confirmLabel: tr('إعادة الضبط', 'Reset'),
                          danger: true,
                        );
                        if (!ok) return;
                        await state.repo.resetDemoData();
                        await state.logout();
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
                  title: tr('عن جايك', 'About Jaik'),
                  subtitle: tr('الإصدار 1.0.0 · Jaik', 'Version 1.0.0 · Jaik'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: tr('جايك', 'Jaik'),
                    applicationVersion: '1.0.0',
                    applicationIcon: const BrandLogo(size: 56, radius: 16),
                    children: [
                      Text(
                        tr('منصة الخدمات المنزلية الأولى في العراق: حجز عمال موثوقين، دفع بماستركارد، ووصولات إلكترونية قابلة للطباعة.', "Iraq's first home services platform: book trusted workers, pay by Mastercard, and get printable electronic receipts."),
                        style: TextStyle(fontSize: 12, height: 1.8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(tr('جايك · لوحة الإدارة', 'Jaik · Admin panel'),
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
            SheetHeader(
              title: tr('رقم الدعم', 'Support number'),
              subtitle: tr('يظهر في صفحة الدعم ووصولات الدفع', 'Shown on the support page and payment receipts'),
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
              label: tr('حفظ', 'Save'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (saved == true && validIraqiPhone(controller.text)) {
      await repo.setSetting('admin_phone', normalizePhone(controller.text));
      if (context.mounted) AppSnack.show(context, tr('تم تحديث رقم الدعم', 'The support number was updated'));
    }
    controller.dispose();
  }

  Future<void> _editSocialLinks() async {
    final repo = context.read<AppState>().repo;
    final keys = [
      'social_facebook_url',
      'social_instagram_url',
      'social_tiktok_url'
    ];
    final urls = await Future.wait([
      for (final key in keys) repo.getSetting(key),
    ]);
    if (!mounted) return;

    final controllers =
        urls.map((url) => TextEditingController(text: url)).toList();
    final formKey = GlobalKey<FormState>();
    final saved = await showAppSheet<bool>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SheetHeader(
                  title: tr('روابط التواصل', 'Social links'),
                  subtitle:
                      tr('تظهر الأيقونات في صفحة تسجيل الدخول. اترك الرابط فارغاً لإيقافه.', 'The icons appear on the login page. Leave a link empty to turn it off.'),
                ),
                const SizedBox(height: 16),
                for (final (index, label) in [
                  tr('فيسبوك', 'Facebook'),
                  tr('إنستغرام', 'Instagram'),
                  tr('تيك توك', 'TikTok'),
                ].indexed) ...[
                  TextFormField(
                    controller: controllers[index],
                    keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: 'https://',
                      prefixIcon: const Icon(Icons.link_rounded, size: 20),
                    ),
                    validator: (value) =>
                        _normalizeSocialUrl(value ?? '') == null
                            ? tr('أدخل رابطاً صحيحاً يبدأ بـ https://', 'Enter a valid link starting with https://')
                            : null,
                  ),
                  if (index < controllers.length - 1)
                    const SizedBox(height: 12),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  label: tr('حفظ الروابط', 'Save links'),
                  icon: Icons.save_outlined,
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, true);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      try {
        for (var i = 0; i < keys.length; i++) {
          await repo.setSetting(
            keys[i],
            _normalizeSocialUrl(controllers[i].text) ?? '',
          );
        }
        if (mounted) AppSnack.show(context, tr('تم حفظ روابط التواصل', 'Social links saved'));
      } catch (error, stackTrace) {
        debugPrint('Failed to save social links: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (mounted) {
          AppSnack.show(context, tr('تعذر حفظ الروابط. حاول مرة أخرى.', "Couldn't save the links. Try again."),
              error: true);
        }
      }
    }
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  String? _normalizeSocialUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    final withScheme = text.contains('://') ? text : 'https://$text';
    final uri = Uri.tryParse(withScheme);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      return null;
    }
    return uri.toString();
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
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
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
      if (mounted) AppSnack.show(context, tr('تعذر فتح تطبيق الاتصال', "Couldn't open the phone app"), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: PushKeyAppBar(title: tr('الزبائن', 'Customers')),
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
                decoration: InputDecoration(
                  hintText: tr('ابحث بالاسم أو رقم الهاتف...', 'Search by name or phone number...'),
                  prefixIcon: Icon(Icons.search_rounded, size: 21),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<AppUser>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.4));
                  }
                  final users = snapshot.data ?? const <AppUser>[];
                  if (users.isEmpty) {
                    return EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: tr('لا يوجد زبائن', 'No customers'),
                      subtitle: tr('سيظهر هنا كل زبون ينشئ حساباً في التطبيق.', 'Every customer who creates an account in the app will appear here.'),
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
                                    tr('${u.city ?? 'العراق'} · ${fmtDateShort(u.createdAt)}', "${u.city == null ? 'Iraq' : cityLabel(u.city!)} · ${fmtDateShort(u.createdAt)}"),
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(fontSize: 9.5),
                                  ),
                                ],
                              ),
                            ),
                            AppIconButton(
                              small: true,
                              onTap: () => _call(u.phone),
                              icon: Icons.call_outlined,
                              tooltip: tr('اتصال', 'Call'),
                            ),
                            AppIconButton(
                              small: true,
                              onTap: () => Navigator.push(
                                context,
                                QuickRoute(
                                  builder: (_) => MessagesScreen(
                                    threadId: u.id,
                                    threadName: u.name,
                                    threadPhone: u.phone,
                                  ),
                                ),
                              ),
                              icon: Icons.chat_bubble_outline_rounded,
                              tooltip: tr('محادثة', 'Chat'),
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
