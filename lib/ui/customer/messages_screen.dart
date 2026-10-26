import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/ui.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.threadId, this.threadName, this.threadPhone});

  /// When null the current customer's own support thread is used.
  final int? threadId;
  final String? threadName;
  final String? threadPhone;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with RealtimeRefresh<MessagesScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  late int _threadId;
  late bool _asAdmin;
  String _adminPhone = '07700000000';

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _asAdmin = state.isAdmin;
    _threadId = widget.threadId ?? state.user!.id!;
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final messages = await state.repo.threadMessages(_threadId);
    final adminPhone = await state.repo.getSetting('admin_phone', fallback: '07700000000');
    await state.repo.markThreadRead(_threadId, readerRole: _asAdmin ? 'admin' : 'customer');
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _adminPhone = adminPhone;
      _loading = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final state = context.read<AppState>();
    setState(() => _sending = true);
    await state.repo.sendMessage(ChatMessage(
      threadId: _threadId,
      senderId: state.user!.id!,
      senderRole: _asAdmin ? 'admin' : 'customer',
      body: text,
      createdAt: DateTime.now(),
    ));
    _input.clear();
    await _load();
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _call() async {
    final phone = widget.threadPhone ?? _adminPhone;
    if (!await launchUrl(Uri.parse('tel:${phoneForCall(phone)}'))) {
      if (mounted) AppSnack.show(context, 'تعذر فتح تطبيق الاتصال', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _asAdmin ? (widget.threadName ?? 'محادثة زبون') : 'الدعم الفني';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: .2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded, size: 20),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('متصل الآن',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: _call,
            tooltip: 'اتصال',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                  : _messages.isEmpty
                      ? EmptyState(
                          icon: Icons.forum_outlined,
                          title: 'ابدأ المحادثة',
                          subtitle: _asAdmin
                              ? 'أرسل رسالة ترحيبية للزبون.'
                              : 'فريق بخدمتك جاهز للإجابة على استفساراتك.\nلضمان حقوقك، التواصل يتم عبر التطبيق.',
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final m = _messages[i];
                            final mine = _asAdmin ? m.fromAdmin : !m.fromAdmin;
                            return _Bubble(
                              message: m,
                              mine: mine,
                              showDate: i == 0 ||
                                  _messages[i - 1].createdAt.day != m.createdAt.day,
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.colorScheme.outline)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالتك...',
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sending ? null : _send,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.ink),
                              )
                            : const Icon(Icons.send_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.showDate});

  final ChatMessage message;
  final bool mine;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (showDate)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(fmtDate(message.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5)),
          ),
        Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .74),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
            decoration: BoxDecoration(
              color: mine ? AppColors.gold : theme.colorScheme.surface,
              borderRadius: BorderRadius.only(
                topRight: const Radius.circular(16),
                topLeft: const Radius.circular(16),
                bottomRight: Radius.circular(mine ? 4 : 16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
              ),
              border: mine ? null : Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(message.body,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.7,
                      color: theme.colorScheme.onSurface,
                    )),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(fmtTimeOfDay(message.createdAt),
                        style: TextStyle(
                          fontSize: 8.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: .45),
                        )),
                    if (mine) ...[
                      const SizedBox(width: 3),
                      Icon(Icons.done_all_rounded,
                          size: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: .5)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
