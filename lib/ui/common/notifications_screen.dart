import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/supabase_services.dart';
import '../../state/app_state.dart';
import '../widgets/ui.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _phone = TextEditingController();
  String _audience = 'all';
  bool _sending = false;
  Future<List<AppNotification>>? _history;

  SupabaseServices get _cloud => context.read<AppState>().cloudServices!;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _loadHistory() {
    setState(() => _history = _cloud.recentSentNotifications());
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final count = await _cloud.sendNotification(
        audience: _audience,
        phone: _audience == 'phone' ? _phone.text : null,
        title: _title.text,
        body: _body.text,
      );
      if (!mounted) return;
      _title.clear();
      _body.clear();
      AppSnack.show(context, 'تم إرسال الإشعار إلى $count مستخدم');
      _loadHistory();
    } catch (error) {
      if (mounted) AppSnack.show(context, 'تعذر إرسال الإشعار: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('إشعارات جايك')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.goldSoft.withValues(alpha: .42),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: AppColors.ink),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تصل الرسائل إلى صندوق الإشعارات داخل التطبيق باسم جايك. اختر الفئة أو أرسلها إلى رقم مسجل.',
                    style: TextStyle(fontSize: 12, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _audience,
                  decoration: const InputDecoration(
                    labelText: 'المستلمون',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('جميع الحسابات المسجلة')),
                    DropdownMenuItem(
                        value: 'customer', child: Text('الزبائن فقط')),
                    DropdownMenuItem(
                        value: 'worker', child: Text('الحرفيون فقط')),
                    DropdownMenuItem(
                        value: 'phone', child: Text('رقم هاتف محدد')),
                  ],
                  onChanged: _sending
                      ? null
                      : (value) => setState(() => _audience = value ?? 'all'),
                ),
                if (_audience == 'phone') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف المسجل',
                      hintText: '07XX XXX XXXX',
                      prefixIcon: Icon(Icons.phone_iphone_outlined),
                    ),
                    validator: (value) => _audience == 'phone' &&
                            (value == null || !validIraqiPhone(value))
                        ? 'أدخل رقم هاتف عراقي صحيح'
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الإشعار',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'أدخل عنوان الإشعار'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _body,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'نص الرسالة',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'اكتب نص الإشعار'
                      : null,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال الإشعار'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'آخر الإشعارات المرسلة',
            actionLabel: 'تحديث',
            onAction: _loadHistory,
          ),
          FutureBuilder<List<AppNotification>>(
            future: _history,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return SoftCard(
                  child: Text('تعذر تحميل سجل الإشعارات: ${snapshot.error}'),
                );
              }
              final items = snapshot.data ?? const <AppNotification>[];
              if (items.isEmpty) {
                return const SoftCard(
                  child: Text('لا توجد إشعارات مرسلة بعد.',
                      textAlign: TextAlign.center),
                );
              }
              return Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const BrandTitle(
                                    fontSize: 14, color: AppColors.goldDeep),
                                const Spacer(),
                                Text(
                                  fmtDateTime(item.sentAt),
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontSize: 10),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(item.title,
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(item.body, style: theme.textTheme.bodyMedium),
                            if (item.recipientPhone != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                item.recipientPhone!,
                                textDirection: TextDirection.ltr,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  late Future<List<AppNotification>> _notifications;
  late final RealtimeChannel _channel;

  SupabaseServices get _cloud => context.read<AppState>().cloudServices!;

  @override
  void initState() {
    super.initState();
    _reload();
    _channel = _cloud.subscribeToNotifications(() {
      if (mounted) setState(_reload);
    });
  }

  void _reload() => _notifications = _cloud.notifications();

  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await _cloud.markNotificationRead(notification.id);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) AppSnack.show(context, 'تعذر تحديث الإشعار: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إشعارات جايك')),
      body: FutureBuilder<List<AppNotification>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('تعذر تحميل الإشعارات: ${snapshot.error}'));
          }
          final items = snapshot.data ?? const <AppNotification>[];
          if (items.isEmpty) {
            return const Center(child: Text('لا توجد إشعارات حتى الآن.'));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => _markRead(item),
                    child: SoftCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item.isRead
                                ? Icons.notifications_none_rounded
                                : Icons.notifications_active_rounded,
                            color: item.isRead
                                ? AppColors.inkMuted
                                : AppColors.goldDeep,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const BrandTitle(
                                    fontSize: 13, color: AppColors.goldDeep),
                                const SizedBox(height: 5),
                                Text(item.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(item.body),
                                const SizedBox(height: 6),
                                Text(fmtDateTime(item.sentAt),
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
