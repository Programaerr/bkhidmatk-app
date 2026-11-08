import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../customer/messages_screen.dart';
import '../widgets/quick_route.dart';
import '../auth/push_key.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';

/// Admin inbox: one row per customer conversation.
class AdminThreadsScreen extends StatefulWidget {
  const AdminThreadsScreen({super.key});

  @override
  State<AdminThreadsScreen> createState() => _AdminThreadsScreenState();
}

class _AdminThreadsScreenState extends State<AdminThreadsScreen>
    with RealtimeRefresh<AdminThreadsScreen> {
  late Future<List<ChatThread>> _future;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().repo.messageThreads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: PushKeyAppBar(
        title: tr('الرسائل', 'Messages'),
        actions: [
          AppIconButton(icon: Icons.refresh_rounded, tooltip: tr('تحديث', 'Refresh'), onTap: _load),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<ChatThread>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
            }
            final threads = snapshot.data ?? const <ChatThread>[];
            if (threads.isEmpty) {
              return EmptyState(
                icon: Icons.forum_outlined,
                title: tr('لا توجد محادثات', 'No conversations'),
                subtitle: tr('ستظهر هنا رسائل الزبائن فور إرسالها.', "Customers' messages will appear here as soon as they're sent."),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final t = threads[i];
                return SoftCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      QuickRoute(
                        builder: (_) => MessagesScreen(
                          threadId: t.customerId,
                          threadName: t.customerName,
                          threadPhone: t.customerPhone,
                        ),
                      ),
                    );
                    _load();
                  },
                  child: Row(
                    children: [
                      AvatarCircle(name: t.customerName, size: 44),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.customerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  timeAgo(t.lastAt),
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontSize: 9.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(fontSize: 10.5),
                                  ),
                                ),
                                if (t.unread > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      '${t.unread}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.onGold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
