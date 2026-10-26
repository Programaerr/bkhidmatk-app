import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../widgets/shell_layout.dart';
import '../widgets/ui.dart';
import 'booking_screen.dart';
import 'messages_screen.dart';

class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key, required this.service});

  final Service service;

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:${phoneForCall(phone)}');
    if (!await launchUrl(uri)) {
      if (context.mounted) AppSnack.show(context, 'تعذر فتح تطبيق الاتصال', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(service.categoryColor ?? 0xFFFFD400);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: AppIconButton(
                icon: Icons.arrow_forward_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF111114), Color(0xFF2B2606)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: -40,
                      bottom: -60,
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withValues(alpha: .1),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 58,
                      right: 22,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          service.categoryName ?? 'خدمة',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      bottom: 26,
                      right: 24,
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: color.withValues(alpha: .35)),
                            ),
                            child: Icon(appIcon(service.categoryIcon ?? 'build'), color: color, size: 30),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 15),
                                    const SizedBox(width: 3),
                                    Text(service.rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.schedule_rounded, color: Colors.white54, size: 14),
                                    const SizedBox(width: 4),
                                    Text(fmtDuration(service.durationMinutes),
                                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: PagePadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SoftCard(
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('سعر الخدمة يبدأ من',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                            const SizedBox(height: 3),
                            Text(fmtMoney(service.price),
                                style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22)),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text('ضمان الخدمة',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'عن الخدمة'),
                  Text(service.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.85)),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'الفني المسؤول'),
                  SoftCard(
                    child: Row(
                      children: [
                        AvatarCircle(name: service.workerName ?? 'فريق بخدمتك', size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(service.workerName ?? 'فريق بخدمتك',
                                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5)),
                              const SizedBox(height: 2),
                              Text('فني معتمد · موثّق من بخدمتك',
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                              const SizedBox(height: 6),
                              RatingStars(rating: service.rating),
                            ],
                          ),
                        ),
                        if (service.workerPhone != null) ...[
                          AppIconButton(
                            icon: Icons.call_outlined,
                            tooltip: 'اتصال',
                            onTap: () => _call(context, service.workerPhone!),
                          ),
                          const SizedBox(width: 6),
                          AppIconButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            tooltip: 'مراسلة',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MessagesScreen()),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'ماذا تشمل الخدمة؟'),
                  _IncludeRow(text: 'فني موثوق ومُقيّم من قبل الزبائن'),
                  _IncludeRow(text: 'أسعار واضحة بدون مفاجآت'),
                  _IncludeRow(text: 'إمكانية الدفع نقداً أو بماستركارد'),
                  _IncludeRow(text: 'وصل إلكتروني قابل للطباعة بعد الدفع'),
                  _IncludeRow(text: 'إلغاء مجاني قبل 3 ساعات من الموعد'),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outline)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('الإجمالي', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                  Text(fmtMoney(service.price),
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 17)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PrimaryButton(
                  label: 'احجز هذه الخدمة',
                  icon: Icons.calendar_month_rounded,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BookingScreen(service: service)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncludeRow extends StatelessWidget {
  const _IncludeRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
