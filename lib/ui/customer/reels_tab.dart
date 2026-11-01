import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/media_view.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/ui.dart';
import 'our_work_detail_screen.dart';

class ReelsTab extends StatefulWidget {
  const ReelsTab({super.key});

  @override
  State<ReelsTab> createState() => _ReelsTabState();
}

class _ReelsTabState extends State<ReelsTab> with RealtimeRefresh<ReelsTab> {
  late Future<List<OurWork>> _future;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onRealtimeChange() => _load();

  void _load() {
    setState(() {
      _future = context.read<AppState>().repo.listWorks(onlyActive: true);
    });
  }

  Future<void> _open(OurWork work) async {
    final id = work.id;
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OurWorkDetailScreen(workId: id)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<OurWork>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final works = snapshot.data ?? const <OurWork>[];
          if (works.isEmpty) {
            return const SafeArea(
              child: EmptyState(
                icon: Icons.video_library_outlined,
                title: 'لا توجد ريلز حالياً',
                subtitle: 'ستظهر هنا الفيديوهات التي تنشرها الإدارة.',
              ),
            );
          }
          if (_currentPage >= works.length) _currentPage = works.length - 1;
          return Stack(
            children: [
              PageView.builder(
                key: const PageStorageKey('customer-reels'),
                scrollDirection: Axis.vertical,
                itemCount: works.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  final id = works[index].id;
                  if (id != null) {
                    context.read<AppState>().repo.incrementWorkViews(id);
                  }
                },
                itemBuilder: (context, index) => _ReelPage(
                  key: ValueKey(works[index].id ?? index),
                  work: works[index],
                  active: index == _currentPage,
                  onDetails: () => _open(works[index]),
                ),
              ),
              const PositionedDirectional(
                top: 10,
                end: 18,
                child: SafeArea(
                  bottom: false,
                  child: Text(
                    'ريلز',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _ReelPage extends StatelessWidget {
  const _ReelPage({
    super.key,
    required this.work,
    required this.active,
    required this.onDetails,
  });

  final OurWork work;
  final bool active;
  final VoidCallback onDetails;

  static bool _isDirectVideo(String url) {
    final path = url.toLowerCase().split('?').first.split('#').first;
    return ['.mp4', '.m3u8', '.webm', '.mov'].any(path.endsWith);
  }

  Future<void> _openVideo() async {
    final uri = Uri.tryParse(work.videoUrl);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black,
                child: _isDirectVideo(work.videoUrl)
                    ? InlineVideoPlayer(
                        path: work.videoUrl,
                        height: height,
                        autoPlay: active,
                      )
                    : Center(
                        child: IconButton(
                          onPressed: _openVideo,
                          icon: const Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.gold,
                            size: 78,
                          ),
                          tooltip: 'فتح الفيديو',
                        ),
                      ),
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x55000000),
                          Colors.transparent,
                          Color(0xCC000000),
                        ],
                        stops: [0, .48, 1],
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: 18,
                end: 18,
                bottom: 24,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onDetails,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              work.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                              ),
                            ),
                            if (work.description?.isNotEmpty == true) ...[
                              const SizedBox(height: 6),
                              Text(
                                work.description!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.4,
                                  shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              '${work.views} مشاهدة',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      onPressed: onDetails,
                      icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
                      tooltip: 'تفاصيل الفيديو',
                    ),
                    if (!_isDirectVideo(work.videoUrl))
                      IconButton(
                        onPressed: _openVideo,
                        icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
                        tooltip: 'فتح رابط الفيديو',
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}
