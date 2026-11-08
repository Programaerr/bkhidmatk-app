import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../auth/auth_route.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/ui.dart';
import 'work_reel.dart';

/// قسم «أعمالنا»: فيديوهات الشركة التي ينشرها المدير من لوحة التحكم.
class OurWorkTab extends StatefulWidget {
  const OurWorkTab({super.key, this.isActive = true});

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

  /// يجهّز الفيديو التالي وهو يشاهد الحالي، فيبدأ فور الوصول إليه.
  void _prepareNext(List<OurWork> works) {
    final next = _currentPage + 1;
    if (next < works.length) prepareWorkVideo(works[next]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OurWork>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(strokeWidth: 2.4));
        }
        final works = snapshot.data ?? const <OurWork>[];
        if (works.isEmpty) {
          return SafeArea(
            bottom: false,
            child: EmptyState(
              icon: Icons.video_library_outlined,
              title: tr('لا توجد أعمال بعد', 'No work yet'),
              subtitle: tr('ستنشر جايك أحدث أعمالها وفيديوهاتها هنا قريباً.', 'Jaik will post its latest work and videos here soon.'),
            ),
          );
        }
        if (_currentPage >= works.length) {
          _currentPage = works.length - 1;
        }
        if (widget.isActive && works.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.isActive) {
              _countView(works[_currentPage]);
              _prepareNext(works);
            }
          });
        }
        // الفيديو يملأ الشاشة كلها حتى ما تحت شريط الحالة، وأيقونات الشريط بيضاء فوقه.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: appSystemBars(night: true),
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: works.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              _countView(works[index]);
              _prepareNext(works);
            },
            itemBuilder: (context, index) => WorkReel(
              key: ValueKey(works[index].id ?? index),
              work: works[index],
              isActive: widget.isActive && index == _currentPage,
              onChanged: _load,
            ),
          ),
        );
      },
    );
  }
}
