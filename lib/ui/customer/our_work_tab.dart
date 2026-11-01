import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/ui.dart';
import 'work_reel.dart';

/// قسم «أعمالنا»: فيديوهات الشركة التي ينشرها المدير من لوحة التحكم.
class OurWorkTab extends StatefulWidget {
  const OurWorkTab({
    super.key,
    required this.refreshTick,
    this.isActive = true,
  });

  final int refreshTick;
  final bool isActive;

  @override
  State<OurWorkTab> createState() => _OurWorkTabState();
}

class _OurWorkTabState extends State<OurWorkTab> with RealtimeRefresh<OurWorkTab> {
  late Future<List<OurWork>> _future;
  int _currentPage = 0;
  final Set<int> _viewedWorkIds = {};

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

  Future<void> _countView(OurWork work) async {
    final id = work.id;
    if (id == null || !_viewedWorkIds.add(id)) return;
    try {
      await context.read<AppState>().repo.incrementWorkViews(id);
    } catch (error, stackTrace) {
      debugPrint('Failed to count work view: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
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
                if (_currentPage >= works.length) {
                  _currentPage = works.length - 1;
                }
                if (widget.isActive && works.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && widget.isActive) {
                      _countView(works[_currentPage]);
                    }
                  });
                }
                return PageView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: works.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _countView(works[index]);
                  },
                  itemBuilder: (context, index) => WorkReel(
                    key: ValueKey(works[index].id ?? index),
                    work: works[index],
                    isActive: widget.isActive && index == _currentPage,
                    onChanged: _load,
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
