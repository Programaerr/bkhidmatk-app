import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../auth/push_key.dart';
import '../common/receipt_document.dart';
import '../widgets/quick_route.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key, this.adminMode = false});

  final bool adminMode;

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen>
    with RealtimeRefresh<ReceiptsScreen> {
  late Future<List<Receipt>> _future;

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
      _future = widget.adminMode
          ? state.repo.allReceipts()
          : state.repo.receiptsForUser(state.user!.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: PushKeyAppBar(title: widget.adminMode ? tr('كل الوصولات', 'All receipts') : tr('وصولاتي', 'My receipts')),
      body: SafeArea(
        child: FutureBuilder<List<Receipt>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
            }
            final receipts = snapshot.data ?? const <Receipt>[];
            if (receipts.isEmpty) {
              return EmptyState(
                icon: Icons.receipt_long_outlined,
                title: tr('لا توجد وصولات بعد', 'No receipts yet'),
                subtitle: tr('ستظهر هنا جميع وصولات الدفع الخاصة بك بعد الحجز.', 'All your payment receipts will appear here after you book.'),
              );
            }
            final total = receipts.fold<double>(0, (s, r) => s + r.amount);
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    color: const Color(0xFF17171B),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            color: AppColors.gold, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('إجمالي المدفوعات', 'Total payments'),
                              style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                          const SizedBox(height: 2),
                          Text(fmtMoney(total),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              )),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(tr('${receipts.length} وصل', receipts.length == 1 ? '1 receipt' : '${receipts.length} receipts'),
                            style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final r in receipts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftCard(
                      padding: const EdgeInsets.all(12),
                      onTap: () => Navigator.push(
                        context,
                        QuickRoute(builder: (_) => ReceiptPreviewScreen(receipt: r)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  r.paid
                                      ? Icons.check_circle_rounded
                                      : Icons.pending_actions_rounded,
                                  size: 20,
                                  color: r.paid ? AppColors.success : AppColors.danger,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.serviceTitle ?? r.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
                                    Text(
                                      '${r.invoiceNo} · ${fmtDate(r.createdAt)}',
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                                    ),
                                    if (widget.adminMode && r.customerName != null)
                                      Text(r.customerName!,
                                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(fmtMoney(r.amount),
                                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 12.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.paid ? tr('مدفوع', 'Paid') : tr('غير مدفوع', 'Unpaid'),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: r.paid ? AppColors.success : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Divider(),
                          ),
                          Row(
                            children: [
                              PaymentMethodBadge(
                                  method: r.method, brand: r.cardBrand, last4: r.last4),
                              const Spacer(),
                              SecondaryButton(
                                label: tr('معاينة', 'Preview'),
                                icon: Icons.visibility_outlined,
                                compact: true,
                                expand: false,
                                onPressed: () => Navigator.push(
                                  context,
                                  QuickRoute(
                                      builder: (_) => ReceiptPreviewScreen(receipt: r)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              AppIconButton(
                                small: true,
                                onTap: () => ReceiptActions.print(context, r),
                                icon: Icons.print_rounded,
                                tooltip: tr('طباعة', 'Print'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
