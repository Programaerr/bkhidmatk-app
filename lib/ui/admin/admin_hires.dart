import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/ui.dart';

/// التوظيف بالرقم: الإدارة تضيف أرقام الأشخاص، وعند تسجيلهم بالتطبيق
/// يصبحون (حرفيين) ويرَون فقط ما تسمح به الإدارة (قسم أعمالنا + حسابهم).
class AdminHiresScreen extends StatefulWidget {
  const AdminHiresScreen({super.key});

  @override
  State<AdminHiresScreen> createState() => _AdminHiresScreenState();
}

class _AdminHiresScreenState extends State<AdminHiresScreen>
    with RealtimeRefresh<AdminHiresScreen> {
  late Future<List<Hire>> _future;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().repo.listHires();
    });
  }

  Future<void> _delete(Hire hire) async {
    if (hire.id == null) return;
    final ok = await confirmAction(
      context,
      title: 'حذف الرقم؟',
      message: 'سيتم حذف ${hire.phone} من قائمة التوظيف، ويعود صاحبه زبوناً عادياً.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().repo.deleteHire(hire.id!);
    if (mounted) {
      AppSnack.show(context, 'تم حذف الرقم');
      _load();
    }
  }

  Future<void> _add() async {
    final phone = TextEditingController();
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showAppSheet<bool>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHeader(
                  title: 'إضافة رقم للتوظيف',
                  subtitle: 'عند تسجيل هذا الرقم في التطبيق يصبح حسابه (حرفي)',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    hintText: '07XXXXXXXXX',
                    labelText: 'رقم الهاتف',
                    prefixIcon: Icon(Icons.phone_iphone_rounded, size: 20),
                  ),
                  validator: (v) =>
                      validIraqiPhone(v ?? '') ? null : 'أدخل رقم عراقي صحيح',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: note,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (المسمى الوظيفي مثلاً)',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'إضافة الرقم',
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
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
    if (saved != true || !mounted) {
      phone.dispose();
      note.dispose();
      return;
    }
    final state = context.read<AppState>();
    final normalized = normalizePhone(phone.text.trim());
    final existing = await state.repo.findUserByPhone(normalized);
    await state.repo.createHire(Hire(
      phone: normalized,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      createdAt: DateTime.now(),
    ));
    phone.dispose();
    note.dispose();
    if (!mounted) return;
    AppSnack.show(
      context,
      existing != null
          ? 'تمت الإضافة وتم تحويل الحساب الموجود إلى (حرفي)'
          : 'تمت إضافة الرقم — سيصبح (حرفياً) عند التسجيل',
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('التوظيف'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _add,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'إضافة رقم',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
              child: SoftCard(
                padding: const EdgeInsets.all(13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.info_outline_rounded, size: 19),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'أضف رقم الشخص الذي تريد توظيفه. عند تسجيله بالتطبيق يظهر له فقط ما تسمح به الإدارة من الأقسام.',
                        style: TextStyle(fontSize: 11.5, height: 1.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Hire>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.4));
                  }
                  final hires = snapshot.data ?? const <Hire>[];
                  if (hires.isEmpty) {
                    return const EmptyState(
                      icon: Icons.badge_outlined,
                      title: 'لا توجد أرقام توظيف',
                      subtitle: 'اضغط (+) لإضافة رقم أول شخص للتوظيف.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _load(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
                      itemCount: hires.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final h = hires[i];
                        return SoftCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              AvatarCircle(
                                name: h.userName ?? h.phone,
                                size: 44,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h.userName ?? 'بانتظار التسجيل',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(fontSize: 13),
                                    ),
                                    Text(
                                      h.phone,
                                      textDirection: TextDirection.ltr,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(fontSize: 10.5),
                                    ),
                                    if (h.note != null && h.note!.isNotEmpty)
                                      Text(
                                        h.note!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(fontSize: 9.5),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (h.registered
                                              ? AppColors.gold
                                              : theme.colorScheme.outline)
                                          .withValues(alpha: .22),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      h.registered ? 'مسجّل' : 'بانتظار',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: h.registered
                                            ? AppColors.ink
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 30,
                                    width: 34,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _delete(h),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: AppColors.danger,
                                      ),
                                      tooltip: 'حذف',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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
