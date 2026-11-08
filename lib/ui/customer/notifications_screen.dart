import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/utils.dart';
import '../../data/supabase_services.dart';
import '../../state/app_state.dart';
import '../auth/push_key.dart';
import '../widgets/ui.dart';
import 'home_keys.dart';

/// إشعارات الزبون. الإشعارات تأتي من السيرفر، فالنسخة المحلية تعرض الصفحة فارغة.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final SupabaseServices? _services = context.read<AppState>().cloudServices;
  late final Future<List<AppNotification>> _notifications = _load();

  Future<List<AppNotification>> _load() async {
    final services = _services;
    if (services == null) return const [];
    final notifications = await services.notifications();
    // ما ظهر هنا صار مقروءاً، وفشل هذا الوسم لا يخفي الإشعارات عن صاحبها.
    for (final notification in notifications.where((n) => !n.isRead)) {
      services.markNotificationRead(notification.id).catchError((_) {});
    }
    return notifications;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ground = theme.brightness == Brightness.dark ? homeNightGround : homeCream;
    return Scaffold(
      backgroundColor: ground,
      appBar: PushKeyAppBar(title: tr('الإشعارات', 'Notifications'), backgroundColor: ground),
      body: FutureBuilder<List<AppNotification>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: tr('تعذّر جلب الإشعارات', "Couldn't load notifications"),
              subtitle: tr('تحقق من الاتصال بالإنترنت ثم حاول مرة أخرى.', 'Check your internet connection and try again.'),
            );
          }
          final notifications = snapshot.data ?? const <AppNotification>[];
          if (notifications.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_none_rounded,
              title: tr('لا توجد إشعارات', 'No notifications'),
              subtitle: tr('ستظهر هنا الإشعارات عند وصولها.', 'Notifications will appear here when they arrive.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final notification = notifications[i];
              return SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(notification.body, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    Text(
                      fmtDate(notification.sentAt),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
