import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'admin_shell.dart';

class AdminServices extends StatefulWidget {
  const AdminServices({super.key});

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
    final repo = context.read<AppState>().repo;
    final ok = await confirmAction(context,
        title: tr('حذف الخدمة؟', 'Delete the service?'),
        message: tr('سيتم حذف «${s.title}» من قائمة الخدمات. الحجوزات السابقة تبقى محفوظة.', 'The service "${s.title}" will be removed from the services list. Past bookings stay saved.'),
        confirmLabel: tr('حذف', 'Delete'),
        danger: true);
    if (!ok) return;
    await repo.deleteService(s.id!);
    if (!mounted) return;
    _load();
  }

  Future<void> _deleteWorker(Worker w) async {
    final repo = context.read<AppState>().repo;
    final ok = await confirmAction(context,
        title: tr('حذف الفني؟', 'Delete the technician?'),
        message: tr('سيتم حذف «${w.name}» وإلغاء ربطه بالخدمات.', '"${w.name}" will be deleted and unlinked from the services.'),
        confirmLabel: tr('حذف', 'Delete'),
        danger: true);
    if (!ok) return;
    await repo.deleteWorker(w.id!);
    if (!mounted) return;
    _load();
  }

  Future<void> _deleteCategory(Category c) async {
    final repo = context.read<AppState>().repo;
    final count = await repo.serviceCountForCategory(c.id!);
    if (count > 0) {
      if (!mounted) return;
      AppSnack.show(context, tr('لا يمكن حذف قسم يحتوي على $count خدمة', count == 1 ? "A category with 1 service can't be deleted" : "A category with $count services can't be deleted"), error: true);
      return;
    }
    if (!mounted) return;
    final ok = await confirmAction(context,
        title: tr('حذف القسم؟', 'Delete the category?'),
        message: tr('سيتم حذف قسم «${c.name}» نهائياً.', 'The category "${sectionLabel(c.name)}" will be deleted permanently.'),
        confirmLabel: tr('حذف', 'Delete'),
        danger: true);
    if (!ok) return;
    await repo.deleteCategory(c.id!);
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [tr('الخدمات', 'Services'), tr('الفنيون', 'Technicians'), tr('الأقسام', 'Categories')];
    return Column(
      children: [
        AdminHeader(
          title: tr('إدارة الخدمات', 'Manage services'),
          subtitle: tr('أضف وعدّل الخدمات والفنيين والأقسام', 'Add and edit services, technicians and categories'),
          actions: [
            AppIconButton(
              icon: Icons.add_rounded,
              tooltip: tr('إضافة', 'Add'),
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

  /// زرا التعديل والحذف في آخر كل صف، بشكل واحد للخدمات والفنيين والأقسام.
  Widget _rowActions({required VoidCallback onEdit, required VoidCallback onDelete}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconButton(small: true, icon: Icons.edit_outlined, tooltip: tr('تعديل', 'Edit'), onTap: onEdit),
        AppIconButton(
          small: true,
          icon: Icons.delete_outline_rounded,
          tooltip: tr('حذف', 'Delete'),
          color: AppColors.danger,
          onTap: onDelete,
        ),
      ],
    );
  }

  Widget _servicesList() {
    final theme = Theme.of(context);
    return FutureBuilder<List<Service>>(
      future: _services,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
        }
        final services = snapshot.data ?? const <Service>[];
        if (services.isEmpty) {
          return EmptyState(
            icon: Icons.handyman_outlined,
            title: tr('لا توجد خدمات', 'No services'),
            subtitle: tr('أضف أول خدمة ليبدأ الزبائن بالحجز.', 'Add the first service so customers can start booking.'),
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
                      color: Color(s.categoryColor ?? 0xFF416F9E).withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(appIcon(s.categoryIcon ?? 'build'),
                        size: 20, color: Color(s.categoryColor ?? 0xFF416F9E)),
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
                          tr('${s.categoryName ?? ''} · ${s.workerName ?? 'بدون فني'}', "${sectionLabel(s.categoryName ?? '')} · ${s.workerName ?? 'No technician'}"),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5),
                        ),
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
                      child: Text(tr('مخفي', 'Hidden'),
                          style: TextStyle(fontSize: 8.5, color: AppColors.danger)),
                    ),
                  _rowActions(
                    onEdit: () => _editService(s),
                    onDelete: () => _deleteService(s),
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
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
        }
        final workers = snapshot.data ?? const <Worker>[];
        if (workers.isEmpty) {
          return EmptyState(
            icon: Icons.engineering_outlined,
            title: tr('لا يوجد فنيون', 'No technicians'),
            subtitle: tr('أضف فنيين ليتم تعيينهم على الحجوزات.', 'Add technicians so they can be assigned to bookings.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
          itemCount: workers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final w = workers[i];
            return SoftCard(
              key: ValueKey(w.id),
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
                        Text(tr('${w.specialty} · ${w.jobsDone} عمل', '${w.specialty} · ${w.jobsDone} jobs'),
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
                      final repo = context.read<AppState>().repo;
                      try {
                        await repo.saveWorker(Worker(
                              id: w.id,
                              name: w.name,
                              phone: w.phone,
                              specialty: w.specialty,
                              categoryId: w.categoryId,
                              rating: w.rating,
                              jobsDone: w.jobsDone,
                              bio: w.bio,
                              // بدونها كانت صورته تُمحى عند كل تبديل للتوفر.
                              avatarPath: w.avatarPath,
                              available: v,
                            ));
                      } catch (_) {
                        if (mounted) {
                          AppSnack.show(this.context, tr('تعذر تغيير حالة الحرفي', "Couldn't change the craftsman's status"), error: true);
                        }
                      }
                      if (mounted) _load();
                    },
                  ),
                  _rowActions(
                    onEdit: () => _editWorker(w),
                    onDelete: () => _deleteWorker(w),
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
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
                    child: Text(sectionLabel(c.name),
                        style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
                  ),
                  _rowActions(
                    onEdit: () => _editCategory(c),
                    onDelete: () => _deleteCategory(c),
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
          // السعر يُتفق عليه لكل حجز، فلا سعر للخدمة نفسها.
          price: widget.service?.price ?? 0,
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
                title: widget.service == null ? tr('إضافة خدمة', 'Add service') : tr('تعديل الخدمة', 'Edit service'),
                subtitle: tr('تظهر الخدمة للزبائن مباشرة عند تفعيلها', 'The service appears to customers as soon as it is enabled'),
              ),
              const SizedBox(height: 16),
              FieldLabel(tr('اسم الخدمة', 'Service name'), required_: true),
              TextFormField(
                controller: _title,
                decoration: InputDecoration(hintText: tr('تصليح أعطال كهربائية', 'Electrical fault repair')),
                validator: (v) =>
                    (v == null || v.trim().length < 4) ? tr('أدخل اسم الخدمة', 'Enter the service name') : null,
              ),
              const SizedBox(height: 12),
              FieldLabel(tr('الوصف', 'Description'), required_: true),
              TextFormField(
                controller: _desc,
                maxLines: 3,
                decoration: InputDecoration(hintText: tr('تفاصيل ما تشمله الخدمة', 'Details of what the service includes')),
                validator: (v) =>
                    (v == null || v.trim().length < 10) ? tr('أدخل وصفاً للخدمة', 'Enter a description for the service') : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FieldLabel(tr('المدة (دقيقة)', 'Duration (minutes)'), required_: true),
                        TextFormField(
                          controller: _duration,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(suffixText: tr('د', 'min')),
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? tr('غير صالح', 'Invalid') : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FieldLabel(tr('القسم', 'Category')),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in _categories)
                    ChoiceChip(
                      label: Text(sectionLabel(c.name)),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              FieldLabel(tr('الفني المسؤول', 'Assigned technician')),
              DropdownButtonFormField<int?>(
                initialValue: _workerId,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.engineering_outlined, size: 20),
                ),
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text(tr('بدون تعيين', 'Unassigned'))),
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
                title: Text(tr('الخدمة مفعّلة', 'Service enabled'),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                subtitle: Text(tr('عند الإيقاف لن تظهر للزبائن', "When off, it won't show to customers"),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: tr('حفظ', 'Save'),
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
                title: widget.worker == null ? tr('إضافة فني', 'Add technician') : tr('تعديل الفني', 'Edit technician'),
                subtitle: tr('بيانات الفني تُستخدم في الحجز والتواصل', "The technician's details are used for booking and contact"),
              ),
              const SizedBox(height: 16),
              FieldLabel(tr('اسم الفني', 'Technician name'), required_: true),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(hintText: tr('أحمد الجبوري', 'Ahmed Al-Jubouri')),
                validator: (v) => (v == null || v.trim().length < 3) ? tr('أدخل الاسم', 'Enter the name') : null,
              ),
              const SizedBox(height: 12),
              FieldLabel(tr('رقم الهاتف', 'Phone number'), required_: true),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(hintText: '07XXXXXXXXX'),
                validator: (v) => validIraqiPhone(v ?? '') ? null : tr('رقم غير صالح', 'Invalid number'),
              ),
              const SizedBox(height: 12),
              FieldLabel(tr('التخصص', 'Specialty'), required_: true),
              TextFormField(
                controller: _specialty,
                decoration: InputDecoration(hintText: tr('كهربائي منازل', 'Home electrician')),
                validator: (v) => (v == null || v.trim().length < 3) ? tr('أدخل التخصص', 'Enter the specialty') : null,
              ),
              const SizedBox(height: 12),
              FieldLabel(tr('القسم', 'Category')),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in _categories)
                    ChoiceChip(
                      label: Text(sectionLabel(c.name)),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FieldLabel(tr('نبذة', 'About')),
              TextFormField(
                controller: _bio,
                maxLines: 2,
                decoration: InputDecoration(hintText: tr('خبرة، مهارات، ملاحظات...', 'Experience, skills, notes...')),
              ),
              SwitchListTile.adaptive(
                value: _available,
                onChanged: (v) => setState(() => _available = v),
                contentPadding: EdgeInsets.zero,
                title: Text(tr('متاح للحجوزات', 'Available for bookings'),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              PrimaryButton(label: tr('حفظ', 'Save'), loading: _saving, onPressed: _save),
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
  int _color = 0xFF416F9E;
  bool _saving = false;

  static const _colors = [
    0xFF416F9E,
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
    _color = widget.category?.color ?? 0xFF416F9E;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      AppSnack.show(context, tr('أدخل اسم القسم', 'Enter the category name'), error: true);
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
              title: widget.category == null ? tr('إضافة قسم', 'Add category') : tr('تعديل القسم', 'Edit category'),
              subtitle: tr('اختر أيقونة ولوناً يميز القسم', 'Choose an icon and a color for the category'),
            ),
            const SizedBox(height: 16),
            FieldLabel(tr('اسم القسم', 'Category name'), required_: true),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(hintText: tr('كهرباء', 'Electrical')),
            ),
            const SizedBox(height: 14),
            FieldLabel(tr('الأيقونة', 'Icon')),
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
                          color: _icon == key ? Color(_color) : const Color(0xFFE6E6E6),
                          width: _icon == key ? 2 : 1,
                        ),
                      ),
                      child: Icon(appIcon(key), size: 20, color: Color(_color)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            FieldLabel(tr('اللون', 'Color')),
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
            PrimaryButton(label: tr('حفظ', 'Save'), loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
