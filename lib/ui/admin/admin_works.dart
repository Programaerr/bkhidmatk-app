import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
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
  const AdminWorks({super.key});

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
      title: tr('حذف العمل؟', 'Delete the work?'),
      message: tr('سيتم حذف «${work.title}» نهائياً مع تعليقاته.', '"${work.title}" will be deleted permanently with its comments.'),
      confirmLabel: tr('حذف', 'Delete'),
      danger: true,
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().repo.deleteWork(work.id!);
    if (mounted) {
      AppSnack.show(context, tr('تم حذف العمل', 'The work was deleted'));
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
                  title: work == null ? tr('إضافة عمل جديد', 'Add new work') : tr('تعديل العمل', 'Edit work'),
                  subtitle: tr('الصق رابط الفيديو (MP4 / رابط مشاهدة)', 'Paste the video link (MP4 / watch link)'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: title,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: tr('عنوان العمل', 'Work title'),
                    prefixIcon: Icon(Icons.title_rounded, size: 20),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? tr('أدخل عنوان العمل', 'Enter the work title') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: url,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: tr('رابط يوتيوب أو فيديو مباشر (mp4)', 'YouTube link or direct video (mp4)'),
                    labelText: tr('رابط الفيديو', 'Video link'),
                    prefixIcon: Icon(Icons.link_rounded, size: 20),
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return tr('أدخل رابط الفيديو', 'Enter the video link');
                    if (!t.startsWith('http://') && !t.startsWith('https://')) {
                      return tr('الرابط يجب أن يبدأ بـ http', 'The link must start with http');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: description,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: tr('وصف (اختياري)', 'Description (optional)'),
                    prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: work == null ? tr('إضافة العمل', 'Add work') : tr('حفظ التعديلات', 'Save changes'),
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
    AppSnack.show(context, work == null ? tr('تمت إضافة العمل', 'The work was added') : tr('تم حفظ التعديلات', 'Changes saved'));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        AdminHeader(
          title: tr('أعمالنا', 'Our work'),
          subtitle: tr('نشر فيديوهات الشركة ومتابعة المشاهدات والتفاعل', "Publish the company's videos and follow views and engagement"),
          actions: [
            AppIconButton(
                icon: Icons.add_rounded, tooltip: tr('إضافة', 'Add'), onTap: () => _edit()),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<OurWork>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.4));
              }
              final works = snapshot.data ?? const <OurWork>[];
              if (works.isEmpty) {
                return EmptyState(
                  icon: Icons.video_library_outlined,
                  title: tr('لا توجد أعمال بعد', 'No work yet'),
                  subtitle: tr('اضغط (+) لإضافة أول فيديو برابط من لوحة التحكم.', 'Tap (+) to add the first video with a link from the dashboard.'),
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
                                  color: const Color(0xFF17171B),
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
                              AppIconButton(
                                small: true,
                                icon: Icons.edit_outlined,
                                tooltip: tr('تعديل', 'Edit'),
                                onTap: () => _edit(work: w),
                              ),
                              AppIconButton(
                                small: true,
                                icon: Icons.delete_outline_rounded,
                                tooltip: tr('حذف', 'Delete'),
                                color: AppColors.danger,
                                onTap: () => _delete(w),
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
                                label: tr('${fmtNumber(w.views)} مشاهدة', '${fmtNumber(w.views)} views'),
                              ),
                              _StatLabel(
                                icon: Icons.favorite_outline_rounded,
                                label: tr('${fmtNumber(w.likes)} إعجاب', '${fmtNumber(w.likes)} likes'),
                              ),
                              _StatLabel(
                                icon: Icons.mode_comment_outlined,
                                label: tr('${fmtNumber(w.commentCount)} تعليق', '${fmtNumber(w.commentCount)} comments'),
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
                                w.active ? tr('ظاهر للزبائن', 'Visible to customers') : tr('مخفي', 'Hidden'),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 10.5),
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
