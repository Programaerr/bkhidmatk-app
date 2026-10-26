import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/media_view.dart';
import '../widgets/ui.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  final _picker = ImagePicker();

  List<Category> _categories = const [];
  Category? _category;
  String? _mediaPath;
  String _mediaType = 'none';
  bool _busy = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _locations();
  }

  Future<void> _locations() async {
    final state = context.read<AppState>();
    final cats = await state.repo.listCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _category = cats.isEmpty ? null : cats.first;
      _location.text = state.user?.city ?? '';
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source, {required bool video}) async {
    setState(() => _uploading = true);
    try {
      XFile? file;
      if (video) {
        file = await _picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 2),
        );
      } else {
        file = await _picker.pickImage(
          source: source,
          maxWidth: 1800,
          imageQuality: 85,
        );
      }
      if (file == null) {
        if (mounted) setState(() => _uploading = false);
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(dir.path, 'media'));
      if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
      final ext = p.extension(file.path).isEmpty
          ? (video ? '.mp4' : '.jpg')
          : p.extension(file.path);
      final dest = p.join(
        mediaDir.path,
        'work_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await File(file.path).copy(dest);
      if (!mounted) return;
      setState(() {
        _mediaPath = dest;
        _mediaType = video ? 'video' : 'image';
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      AppSnack.show(context, 'تعذر اختيار الملف، تحقق من صلاحيات الكاميرا والمعرض',
          error: true);
    }
  }

  Future<void> _pickCategory() async {
    final picked = await showAppSheet<Category>(
      context,
      builder: (ctx) => SizedBox(
        height: 460,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SheetHeader(title: 'اختر القسم'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final c in _categories)
                    ListTile(
                      leading: Icon(appIcon(c.icon)),
                      title: Text(c.name),
                      trailing: c.id == _category?.id
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 20)
                          : null,
                      onTap: () => Navigator.pop(ctx, c),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mediaPath == null) {
      AppSnack.show(context, 'أضف فيديو أو صورة توثّق العمل قبل النشر', error: true);
      return;
    }
    final user = context.read<AppState>().user;
    if (user?.id == null || _category?.id == null) return;

    setState(() => _busy = true);
    try {
      await context.read<AppState>().repo.createPost(Post(
            customerId: user!.id!,
            categoryId: _category!.id!,
            title: _title.text.trim(),
            description: _desc.text.trim(),
            price: double.tryParse(_price.text) ?? 0,
            mediaPath: _mediaPath,
            mediaType: _mediaType,
            location: _location.text.trim(),
            approved: true,
            createdAt: DateTime.now(),
          ));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.show(context, 'تعذر نشر العمل، حاول مرة أخرى', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('نشر عمل جديد'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withValues(alpha: .35)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.videocam_rounded, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'وثّق عملك بالفيديو ليزيد عدد الزبائن الذين يثقون بخدمتك. الفيديو حتى دقيقتين.',
                        style: TextStyle(fontSize: 11, height: 1.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_mediaPath != null) ...[
                Stack(
                  children: [
                    _mediaType == 'video'
                        ? InlineVideoPlayer(path: _mediaPath!, height: 210)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Image.file(File(_mediaPath!),
                                height: 210, width: double.infinity, fit: BoxFit.cover),
                          ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _mediaPath = null;
                          _mediaType = 'none';
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .6),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          _mediaType == 'video' ? 'فيديو جاهز للنشر' : 'صورة جاهزة للنشر',
                          style: const TextStyle(color: Colors.white, fontSize: 9.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                Container(
                  height: 170,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: theme.colorScheme.outline,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _uploading
                      ? const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: .18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.file_upload_outlined, size: 24),
                            ),
                            const SizedBox(height: 8),
                            const Text('أضف فيديو أو صورة للعمل',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('MP4 · JPG · PNG',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _PickButton(
                                  icon: Icons.videocam_rounded,
                                  label: 'فيديو',
                                  onTap: () => _pick(ImageSource.gallery, video: true),
                                ),
                                const SizedBox(width: 8),
                                _PickButton(
                                  icon: Icons.photo_library_outlined,
                                  label: 'صورة',
                                  onTap: () => _pick(ImageSource.gallery, video: false),
                                ),
                                const SizedBox(width: 8),
                                _PickButton(
                                  icon: Icons.camera_alt_rounded,
                                  label: 'كاميرا',
                                  onTap: () => _pick(ImageSource.camera, video: false),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              const SizedBox(height: 18),
              const FieldLabel('عنوان العمل', required_: true),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'مثال: تصليح لوحة كهرباء كاملة',
                  prefixIcon: Icon(Icons.title_rounded, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 5) ? 'اكتب عنواناً واضحاً للعمل' : null,
              ),
              const SizedBox(height: 14),
              const FieldLabel('وصف العمل', required_: true),
              TextFormField(
                controller: _desc,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'اشرح ما تم إنجازه، المواد المستخدمة، والمدة...',
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 10) ? 'أضف وصفاً مفصلاً للعمل' : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('القسم'),
                        InkWell(
                          onTap: _pickCategory,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.category_outlined, size: 20),
                              suffixIcon: Icon(Icons.expand_more_rounded, size: 20),
                            ),
                            child: Text(_category?.name ?? 'اختر القسم'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('السعر (د.ع)', required_: true),
                        TextFormField(
                          controller: _price,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(hintText: '25000'),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'سعر غير صالح';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const FieldLabel('الموقع'),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  hintText: 'بغداد - الكرادة',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'نشر العمل',
                icon: Icons.publish_rounded,
                loading: _busy,
                onPressed: _publish,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'بالنشر أنت توافق على أن يكون العمل موثقاً وحقيقياً.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
