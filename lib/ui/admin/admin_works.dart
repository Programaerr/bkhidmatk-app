import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'admin_shell.dart';

/// إدارة قسم «أعمالنا»: إضافة فيديو برابط، إظهار/إخفاء، تعديل وحذف، وإحصائيات.
class AdminWorks extends StatefulWidget {
  const AdminWorks({super.key, required this.refreshTick});

  final int refreshTick;

  @override
  State<AdminWorks> createState() => _AdminWorksState();
}

class _AdminWorksState extends State<AdminWorks> with RealtimeRefresh<AdminWorks> {
  late Future<List<OurWork>> _future;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminWorks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _load();
  }

  void _load() {
    final state = context.read<AppState>();
    setState(() {
      _future = state.repo.listWorks(
        onlyActive: false,
        viewerId: state.user?.id,
      );
    });
  }

  Future<void> _toggleActive(OurWork work) async {
    if (work.id == null) return;
    await context
        .read<AppState>()
        .repo
        .setWorkActive(work.id!, !work.active);
    if (mounted) _load();
  }

  Future<void> _delete(OurWork work) async {
    if (work.id == null) return;
    final ok = await confirmAction(
      context,
      title: 'حذف العمل؟',
      message: 'سيتم حذف «${work.title}» نهائياً مع تعليقاته.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().repo.deleteWork(work.id!);
    if (mounted) {
      AppSnack.show(context, 'تم حذف العمل');
      _load();
    }
  }

  Future<void> _edit({OurWork? work}) async {
    final state = context.read<AppState>();
    final title = TextEditingController(text: work?.title ?? '');
    final description = TextEditingController(text: work?.description ?? '');
    final url = TextEditingController(text: work?.videoUrl ?? '');
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
                SheetHeader(
                  title: work == null ? 'إضافة عمل جديد' : 'تعديل العمل',
                  subtitle: 'الصق رابط الفيديو (MP4 / رابط مشاهدة)',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: title,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'عنوان العمل',
                    prefixIcon: Icon(Icons.title_rounded, size: 20),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'أدخل عنوان العمل' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: url,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'https://example.com/video.mp4',
                    labelText: 'رابط الفيديو',
                    prefixIcon: Icon(Icons.link_rounded, size: 20),
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'أدخل رابط الفيديو';
                    if (!t.startsWith('http://') && !t.startsWith('https://')) {
                      return 'الرابط يجب أن يبدأ بـ http';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'وصف (اختياري)',
                    prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: work == null ? 'إضافة العمل' : 'حفظ التعديلات',
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
      title.dispose();
      description.dispose();
      url.dispose();
      return;
    }
    if (work == null) {
      await state.repo.createWork(OurWork(
        title: title.text.trim(),
        description: description.text.trim().isEmpty ? null : description.text.trim(),
        videoUrl: url.text.trim(),
        createdAt: DateTime.now(),
      ));
    } else {
      await state.repo.updateWork(work.copyWith(
        title: title.text.trim(),
        description: description.text.trim().isEmpty ? null : description.text.trim(),
        videoUrl: url.text.trim(),
      ));
    }
    title.dispose();
    description.dispose();
    url.dispose();
    if (!mounted) return;
    AppSnack.show(context, work == null ? 'تمت إضافة العمل' : 'تم حفظ التعديلات');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        AdminHeader(
          title: 'أعمالنا',
          subtitle: 'نشر فيديوهات الشركة ومتابعة المشاهدات والتفاعل',
          actions: [
            AppIconButton(icon: Icons.add_rounded, onTap: () => _edit()),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<OurWork>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.4));
              }
              final works = snapshot.data ?? const <OurWork>[];
              if (works.isEmpty) {
                return const EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'لا توجد أعمال بعد',
                  subtitle: 'اضغط (+) لإضافة أول فيديو برابط من لوحة التحكم.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _load(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
                  itemCount: works.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final w = works[i];
                    return SoftCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                    colors: [Color(0xFF141416), Color(0xFF3A3308)],
                                  ),
                                ),
                                child: const Icon(Icons.play_arrow_rounded,
                                    color: AppColors.gold, size: 26),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      w.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(fontSize: 13),
                                    ),
                                    Text(
                                      w.videoUrl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textDirection: TextDirection.ltr,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(fontSize: 9.5),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_vert_rounded, size: 20),
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    _edit(work: w);
                                  } else if (v == 'delete') {
                                    _delete(w);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [
                                      Icon(Icons.edit_outlined, size: 17),
                                      SizedBox(width: 8),
                                      Text('تعديل'),
                                    ]),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      Icon(Icons.delete_outline_rounded,
                                          size: 17, color: AppColors.danger),
                                      SizedBox(width: 8),
                                      Text('حذف',
                                          style: TextStyle(color: AppColors.danger)),
                                    ]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              _StatLabel(
                                icon: Icons.visibility_outlined,
                                label: '${fmtNumber(w.views)} مشاهدة',
                              ),
                              _StatLabel(
                                icon: Icons.favorite_outline_rounded,
                                label: '${fmtNumber(w.likes)} إعجاب',
                              ),
                              _StatLabel(
                                icon: Icons.mode_comment_outlined,
                                label: '${fmtNumber(w.commentCount)} تعليق',
                              ),
                              _StatLabel(
                                icon: Icons.schedule_rounded,
                                label: fmtDateShort(w.createdAt),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Switch(
                                value: w.active,
                                onChanged: (_) => _toggleActive(w),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                w.active ? 'ظاهر للزبائن' : 'مخفي',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 10.5),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _edit(work: w),
                                child: const Text(
                                  'تعديل',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700),
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
    );
  }
}

class _StatLabel extends StatelessWidget {
  const _StatLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 13, color: theme.colorScheme.onSurface.withValues(alpha: .55)),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10.5,
            color: theme.colorScheme.onSurface.withValues(alpha: .7),
          ),
        ),
      ],
    );
  }
}
