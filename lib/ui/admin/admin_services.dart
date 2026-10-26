import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'admin_shell.dart';

class AdminServices extends StatefulWidget {
  const AdminServices({super.key, required this.refreshTick});

  final int refreshTick;

  @override
  State<AdminServices> createState() => _AdminServicesState();
}

class _AdminServicesState extends State<AdminServices>
    with RealtimeRefresh<AdminServices> {
  int _tab = 0;
  late Future<List<Service>> _services;
  late Future<List<Worker>> _workers;
  late Future<List<Category>> _categories;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminServices oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _load();
  }

  void _load() {
    final repo = context.read<AppState>().repo;
    setState(() {
      _services = repo.listServices(onlyActive: false);
      _workers = repo.listWorkers();
      _categories = repo.listCategories();
    });
  }

  Future<void> _editService([Service? service]) async {
    final saved = await showAppSheet<bool>(
      context,
      builder: (_) => _ServiceForm(service: service),
    );
    if (saved == true) _load();
  }

  Future<void> _editWorker([Worker? worker]) async {
    final saved = await showAppSheet<bool>(
      context,
      builder: (_) => _WorkerForm(worker: worker),
    );
    if (saved == true) _load();
  }

  Future<void> _editCategory([Category? category]) async {
    final saved = await showAppSheet<bool>(
      context,
      builder: (_) => _CategoryForm(category: category),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteService(Service s) async {
    final ok = await confirmAction(context,
        title: 'حذف الخدمة؟',
        message: 'سيتم حذف «${s.title}» من قائمة الخدمات. الحجوزات السابقة تبقى محفوظة.',
        confirmLabel: 'حذف',
        danger: true);
    if (!ok) return;
    await context.read<AppState>().repo.deleteService(s.id!);
    _load();
  }

  Future<void> _deleteWorker(Worker w) async {
    final ok = await confirmAction(context,
        title: 'حذف الفني؟',
        message: 'سيتم حذف «${w.name}» وإلغاء ربطه بالخدمات.',
        confirmLabel: 'حذف',
        danger: true);
    if (!ok) return;
    await context.read<AppState>().repo.deleteWorker(w.id!);
    _load();
  }

  Future<void> _deleteCategory(Category c) async {
    final repo = context.read<AppState>().repo;
    final count = await repo.serviceCountForCategory(c.id!);
    if (count > 0) {
      if (!mounted) return;
      AppSnack.show(context, 'لا يمكن حذف قسم يحتوي على $count خدمة', error: true);
      return;
    }
    if (!mounted) return;
    final ok = await confirmAction(context,
        title: 'حذف القسم؟',
        message: 'سيتم حذف قسم «${c.name}» نهائياً.',
        confirmLabel: 'حذف',
        danger: true);
    if (!ok) return;
    await repo.deleteCategory(c.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['الخدمات', 'الفنيون', 'الأقسام'];
    return Column(
      children: [
        AdminHeader(
          title: 'إدارة الخدمات',
          subtitle: 'أضف وعدّل الخدمات والفنيين والأقسام',
          actions: [
            AppIconButton(
              icon: Icons.add_rounded,
              onTap: () => _tab == 0
                  ? _editService()
                  : _tab == 1
                      ? _editWorker()
                      : _editCategory(),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SegmentedTabs(
            values: tabs,
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _tab == 0
              ? _servicesList()
              : _tab == 1
                  ? _workersList()
                  : _categoriesList(),
        ),
      ],
    );
  }

  Widget _servicesList() {
    final theme = Theme.of(context);
    return FutureBuilder<List<Service>>(
      future: _services,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
        }
        final services = snapshot.data ?? const <Service>[];
        if (services.isEmpty) {
          return const EmptyState(
            icon: Icons.handyman_outlined,
            title: 'لا توجد خدمات',
            subtitle: 'أضف أول خدمة ليبدأ الزبائن بالحجز.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
          itemCount: services.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final s = services[i];
            return SoftCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Color(s.categoryColor ?? 0xFFFFD400).withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(appIcon(s.categoryIcon ?? 'build'),
                        size: 20, color: Color(s.categoryColor ?? 0xFFFFD400)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Text(
                          '${s.categoryName ?? ''} · ${s.workerName ?? 'بدون فني'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5),
                        ),
                        Text(fmtMoney(s.price),
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface)),
                      ],
                    ),
                  ),
                  if (!s.active)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text('مخفي',
                          style: TextStyle(fontSize: 8.5, color: AppColors.danger)),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 19),
                    onSelected: (v) {
                      if (v == 'edit') _editService(s);
                      if (v == 'delete') _deleteService(s);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _workersList() {
    final theme = Theme.of(context);
    return FutureBuilder<List<Worker>>(
      future: _workers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
        }
        final workers = snapshot.data ?? const <Worker>[];
        if (workers.isEmpty) {
          return const EmptyState(
            icon: Icons.engineering_outlined,
            title: 'لا يوجد فنيون',
            subtitle: 'أضف فنيين ليتم تعيينهم على الحجوزات.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
          itemCount: workers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final w = workers[i];
            return SoftCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  AvatarCircle(name: w.name, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(w.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 12.5)),
                            ),
                            const SizedBox(width: 4),
                            RatingStars(rating: w.rating, size: 9.5),
                          ],
                        ),
                        Text('${w.specialty} · ${w.jobsDone} عمل',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5)),
                        Text(w.phone,
                            textDirection: TextDirection.ltr,
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: w.available,
                    onChanged: (v) async {
                      await context.read<AppState>().repo.saveWorker(Worker(
                            id: w.id,
                            name: w.name,
                            phone: w.phone,
                            specialty: w.specialty,
                            categoryId: w.categoryId,
                            rating: w.rating,
                            jobsDone: w.jobsDone,
                            bio: w.bio,
                            available: v,
                          ));
                      _load();
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 19),
                    onSelected: (v) {
                      if (v == 'edit') _editWorker(w);
                      if (v == 'delete') _deleteWorker(w);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _categoriesList() {
    final theme = Theme.of(context);
    return FutureBuilder<List<Category>>(
      future: _categories,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
        }
        final categories = snapshot.data ?? const <Category>[];
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = categories[i];
            return SoftCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Color(c.color).withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(appIcon(c.icon), size: 20, color: Color(c.color)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(c.name,
                        style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
                  ),
                  IconButton(
                    onPressed: () => _editCategory(c),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    onPressed: () => _deleteCategory(c),
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.danger),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ServiceForm extends StatefulWidget {
  const _ServiceForm({this.service});

  final Service? service;

  @override
  State<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<_ServiceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _duration;
  List<Category> _categories = const [];
  List<Worker> _workers = const [];
  int? _categoryId;
  int? _workerId;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _title = TextEditingController(text: s?.title ?? '');
    _desc = TextEditingController(text: s?.description ?? '');
    _price = TextEditingController(text: s == null ? '' : s.price.round().toString());
    _duration = TextEditingController(text: '${s?.durationMinutes ?? 60}');
    _categoryId = s?.categoryId;
    _workerId = s?.workerId;
    _active = s?.active ?? true;
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final repo = context.read<AppState>().repo;
    final cats = await repo.listCategories();
    final workers = await repo.listWorkers();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _workers = workers;
      _categoryId ??= cats.isEmpty ? null : cats.first.id;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) return;
    setState(() => _saving = true);
    await context.read<AppState>().repo.saveService(Service(
          id: widget.service?.id,
          categoryId: _categoryId!,
          workerId: _workerId,
          title: _title.text.trim(),
          description: _desc.text.trim(),
          price: double.tryParse(_price.text) ?? 0,
          durationMinutes: int.tryParse(_duration.text) ?? 60,
          rating: widget.service?.rating ?? 4.8,
          active: _active,
          createdAt: widget.service?.createdAt ?? DateTime.now(),
        ));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHeader(
                title: widget.service == null ? 'إضافة خدمة' : 'تعديل الخدمة',
                subtitle: 'تظهر الخدمة للزبائن مباشرة عند تفعيلها',
              ),
              const SizedBox(height: 16),
              const FieldLabel('اسم الخدمة', required_: true),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(hintText: 'تصليح أعطال كهربائية'),
                validator: (v) =>
                    (v == null || v.trim().length < 4) ? 'أدخل اسم الخدمة' : null,
              ),
              const SizedBox(height: 12),
              const FieldLabel('الوصف', required_: true),
              TextFormField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'تفاصيل ما تشمله الخدمة'),
                validator: (v) =>
                    (v == null || v.trim().length < 10) ? 'أدخل وصفاً للخدمة' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('السعر', required_: true),
                        TextFormField(
                          controller: _price,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(suffixText: 'د.ع'),
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'سعر غير صالح' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('المدة (دقيقة)', required_: true),
                        TextFormField(
                          controller: _duration,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(suffixText: 'د'),
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'غير صالح' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const FieldLabel('القسم'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in _categories)
                    ChoiceChip(
                      label: Text(c.name),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const FieldLabel('الفني المسؤول'),
              DropdownButtonFormField<int?>(
                initialValue: _workerId,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.engineering_outlined, size: 20),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('بدون تعيين')),
                  for (final w in _workers)
                    DropdownMenuItem<int?>(
                      value: w.id,
                      child: Text('${w.name} · ${w.specialty}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                ],
                onChanged: (v) => setState(() => _workerId = v),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('الخدمة مفعّلة',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                subtitle: Text('عند الإيقاف لن تظهر للزبائن',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'حفظ',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerForm extends StatefulWidget {
  const _WorkerForm({this.worker});

  final Worker? worker;

  @override
  State<_WorkerForm> createState() => _WorkerFormState();
}

class _WorkerFormState extends State<_WorkerForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _specialty;
  late final TextEditingController _bio;
  List<Category> _categories = const [];
  int? _categoryId;
  bool _available = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final w = widget.worker;
    _name = TextEditingController(text: w?.name ?? '');
    _phone = TextEditingController(text: w?.phone ?? '');
    _specialty = TextEditingController(text: w?.specialty ?? '');
    _bio = TextEditingController(text: w?.bio ?? '');
    _categoryId = w?.categoryId;
    _available = w?.available ?? true;
    _load();
  }

  Future<void> _load() async {
    final cats = await context.read<AppState>().repo.listCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _categoryId ??= cats.isEmpty ? null : cats.first.id;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _specialty.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await context.read<AppState>().repo.saveWorker(Worker(
          id: widget.worker?.id,
          name: _name.text.trim(),
          phone: normalizePhone(_phone.text),
          specialty: _specialty.text.trim(),
          categoryId: _categoryId,
          rating: widget.worker?.rating ?? 4.8,
          jobsDone: widget.worker?.jobsDone ?? 0,
          bio: _bio.text.trim(),
          available: _available,
        ));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHeader(
                title: widget.worker == null ? 'إضافة فني' : 'تعديل الفني',
                subtitle: 'بيانات الفني تُستخدم في الحجز والتواصل',
              ),
              const SizedBox(height: 16),
              const FieldLabel('اسم الفني', required_: true),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'أحمد الجبوري'),
                validator: (v) => (v == null || v.trim().length < 3) ? 'أدخل الاسم' : null,
              ),
              const SizedBox(height: 12),
              const FieldLabel('رقم الهاتف', required_: true),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(hintText: '07XXXXXXXXX'),
                validator: (v) => validIraqiPhone(v ?? '') ? null : 'رقم غير صالح',
              ),
              const SizedBox(height: 12),
              const FieldLabel('التخصص', required_: true),
              TextFormField(
                controller: _specialty,
                decoration: const InputDecoration(hintText: 'كهربائي منازل'),
                validator: (v) => (v == null || v.trim().length < 3) ? 'أدخل التخصص' : null,
              ),
              const SizedBox(height: 12),
              const FieldLabel('القسم'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in _categories)
                    ChoiceChip(
                      label: Text(c.name),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const FieldLabel('نبذة'),
              TextFormField(
                controller: _bio,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'خبرة، مهارات، ملاحظات...'),
              ),
              SwitchListTile.adaptive(
                value: _available,
                onChanged: (v) => setState(() => _available = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('متاح للحجوزات',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              PrimaryButton(label: 'حفظ', loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({this.category});

  final Category? category;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final TextEditingController _name;
  String _icon = 'handyman';
  int _color = 0xFFFFC107;
  bool _saving = false;

  static const _colors = [
    0xFFFFC107,
    0xFF03A9F4,
    0xFF8BC34A,
    0xFFE91E63,
    0xFF00BCD4,
    0xFF3F51B5,
    0xFF9C27B0,
    0xFF795548,
    0xFFFF7043,
    0xFF009688,
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _icon = widget.category?.icon ?? 'handyman';
    _color = widget.category?.color ?? 0xFFFFC107;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      AppSnack.show(context, 'أدخل اسم القسم', error: true);
      return;
    }
    setState(() => _saving = true);
    await context.read<AppState>().repo.saveCategory(Category(
          id: widget.category?.id,
          name: _name.text.trim(),
          icon: _icon,
          color: _color,
          sortOrder: widget.category?.sortOrder ?? 99,
        ));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              title: widget.category == null ? 'إضافة قسم' : 'تعديل القسم',
              subtitle: 'اختر أيقونة ولوناً يميز القسم',
            ),
            const SizedBox(height: 16),
            const FieldLabel('اسم القسم', required_: true),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'كهرباء'),
            ),
            const SizedBox(height: 14),
            const FieldLabel('الأيقونة'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in categoryIconKeys)
                  GestureDetector(
                    onTap: () => setState(() => _icon = key),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _icon == key
                            ? Color(_color).withValues(alpha: .2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _icon == key ? Color(_color) : const Color(0xFFE9E9DF),
                          width: _icon == key ? 2 : 1,
                        ),
                      ),
                      child: Icon(appIcon(key), size: 20, color: Color(_color)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const FieldLabel('اللون'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _colors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c ? AppColors.ink : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: _color == c
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'حفظ', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
