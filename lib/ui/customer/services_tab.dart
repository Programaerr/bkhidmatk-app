import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'service_detail_screen.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key, this.initialCategoryId, this.initialQuery = ''});

  final int? initialCategoryId;
  final String initialQuery;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CustomerHeader(
              title: 'كل الخدمات',
              subtitle: 'اختر الخدمة المناسبة واحجز خلال دقيقة',
              showBack: true,
            ),
            Expanded(
              child: ServicesTab(
                initialCategoryId: initialCategoryId,
                initialQuery: initialQuery,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key, this.initialCategoryId, this.initialQuery = ''});

  final int? initialCategoryId;
  final String initialQuery;

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  late final TextEditingController _search = TextEditingController(text: widget.initialQuery);
  int? _categoryId;
  Future<List<Service>>? _future;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    final repo = context.read<AppState>().repo;
    setState(() {
      _future = repo.listServices(categoryId: _categoryId, query: _search.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
          child: TextField(
            controller: _search,
            onChanged: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'ابحث عن خدمة، عامل، أو قسم...',
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _search.clear();
                        _load();
                      },
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: FutureBuilder<List<Category>>(
            future: state.repo.listCategories(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? const <Category>[];
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  _FilterChip(
                    label: 'الكل',
                    selected: _categoryId == null,
                    onTap: () {
                      setState(() => _categoryId = null);
                      _load();
                    },
                  ),
                  for (final c in categories) ...[
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: c.name,
                      selected: _categoryId == c.id,
                      onTap: () {
                        setState(() => _categoryId = c.id);
                        _load();
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: FutureBuilder<List<Service>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                );
              }
              final services = snapshot.data ?? const <Service>[];
              if (services.isEmpty) {
                return const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'لا توجد خدمات مطابقة',
                  subtitle: 'جرّب كلمة بحث أخرى أو اختر قسماً مختلفاً.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                itemCount: services.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => ServiceTile(service: services[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? AppColors.gold : theme.colorScheme.outline),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.ink : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class ServiceTile extends StatelessWidget {
  const ServiceTile({super.key, required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(service.categoryColor ?? 0xFFFFD400);
    return SoftCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: service)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryBadge(color: color, title: service.title, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 14.5),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    RatingStars(rating: service.rating),
                    const SizedBox(width: 8),
                    Text('·', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        service.workerName ?? 'فريق بخدمتك',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      fmtMoney(service.price),
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(width: 6),
                    Text('/ ${fmtDuration(service.durationMinutes)}',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text('احجز',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.color,
    required this.title,
    this.size = 48,
    this.icon,
  });

  final Color color;
  final String title;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .22), color.withValues(alpha: .1)],
        ),
        borderRadius: BorderRadius.circular(size * .32),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Icon(icon ?? Icons.handyman_rounded, color: color, size: size * .45),
    );
  }
}
