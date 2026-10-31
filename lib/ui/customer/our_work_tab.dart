import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/ui.dart';
import '../widgets/work_card.dart';
import 'our_work_detail_screen.dart';

/// قسم «أعمالنا»: فيديوهات الشركة التي ينشرها المدير من لوحة التحكم.
class OurWorkTab extends StatefulWidget {
  const OurWorkTab({super.key, required this.refreshTick});

  final int refreshTick;

  @override
  State<OurWorkTab> createState() => _OurWorkTabState();
}

class _OurWorkTabState extends State<OurWorkTab> with RealtimeRefresh<OurWorkTab> {
  late Future<List<OurWork>> _future;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OurWorkTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _load();
  }

  void _load() {
    final state = context.read<AppState>();
    setState(() {
      _future = state.repo.listWorks(
        onlyActive: true,
        viewerId: state.user?.id,
      );
    });
  }

  Future<void> _open(OurWork work) async {
    if (work.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OurWorkDetailScreen(workId: work.id!)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أعمالنا', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  'أحدث فيديوهات فريق جايك موثّقة بالصور',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
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
                    subtitle: 'ستنشر جايك أحدث أعمالها وفيديوهاتها هنا قريباً.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                    itemCount: works.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        WorkCard(work: works[i], onOpen: () => _open(works[i])),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
