import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../auth/push_key.dart';

IconData appIcon(String key) {
  switch (key) {
    case 'electrical_services':
      return Icons.electrical_services_rounded;
    case 'local_laundry_service':
      return Icons.local_laundry_service_rounded;
    case 'format_paint':
      return Icons.format_paint_rounded;
    case 'chair_alt':
      return Icons.chair_alt_rounded;
    case 'plumbing':
      return Icons.plumbing_rounded;
    case 'ac_unit':
      return Icons.ac_unit_rounded;
    case 'cleaning_services':
      return Icons.cleaning_services_rounded;
    case 'carpenter':
      return Icons.carpenter_rounded;
    case 'home_repair_service':
      return Icons.home_repair_service_rounded;
    case 'handyman':
      return Icons.handyman_rounded;
    case 'construction':
      return Icons.construction_rounded;
    case 'roofing':
      return Icons.roofing_rounded;
    case 'water_damage':
      return Icons.water_damage_rounded;
    case 'kitchen':
      return Icons.kitchen_rounded;
    case 'solar_power':
      return Icons.solar_power_rounded;
    case 'window':
      return Icons.window_rounded;
    case 'garage':
      return Icons.garage_rounded;
    case 'pest_control':
      return Icons.pest_control_rounded;
    case 'hardware':
      return Icons.hardware_rounded;
    case 'videocam':
      return Icons.videocam_rounded;
    case 'yard':
      return Icons.yard_rounded;
    case 'engineering':
      return Icons.engineering_rounded;
    case 'local_shipping':
      return Icons.local_shipping_rounded;
    case 'local_car_wash':
      return Icons.local_car_wash_rounded;
    default:
      return Icons.build_rounded;
  }
}

const categoryIconKeys = [
  'electrical_services',
  'local_laundry_service',
  'format_paint',
  'chair_alt',
  'plumbing',
  'ac_unit',
  'cleaning_services',
  'carpenter',
  'home_repair_service',
  'handyman',
  'construction',
  'roofing',
  'water_damage',
  'kitchen',
  'solar_power',
  'window',
  'garage',
  'pest_control',
  'hardware',
  'videocam',
  'yard',
  'engineering',
  'local_shipping',
  'local_car_wash',
  'build',
];

/// شعار جايك. كان يُرسم فارغاً بلا صورة، فيظهر مربعاً خالياً حيث يوضع.
class BrandLogo extends StatelessWidget {
  const BrandLogo(
      {super.key, this.size = 44, this.radius = 12, this.showBorder = false});

  final double size;
  final double radius;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: showBorder
            ? Border.all(color: AppColors.ink.withValues(alpha: .08))
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/logo.jpg',
        fit: BoxFit.cover,
        cacheWidth: pixels,
        cacheHeight: pixels,
        errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.gold),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: 12, top: 4),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12.5)),
                  const SizedBox(width: 2),
                  // يتجه إلى اليسار في العربية، فهو ينقل إلى الأمام لا إلى الخلف.
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor ?? theme.colorScheme.outline),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// الزر الرئيسي في أي صفحة: أصفر بشكل أزرار الصفحة الرئيسية. [tone] يغيّر لونه للأزرار الأخرى.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.compact = false,
    this.tone = KeyTone.yellow,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool compact;
  final KeyTone tone;

  @override
  Widget build(BuildContext context) {
    return PushKeyButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      expand: expand,
      compact: compact,
      tone: tone,
    );
  }
}

/// الزر الثانوي: أبيض بالشكل نفسه، لما يلي الإجراء الرئيسي أو يخالفه.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.compact = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool compact;

  /// للإجراء الذي لا رجعة فيه، مثل الإلغاء والحذف.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return PushKeyButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      expand: expand,
      compact: compact,
      tone: danger ? KeyTone.red : KeyTone.white,
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.dense = false});

  final String status;
  final bool dense;

  static Color colorOf(String s) => switch (s) {
        BookingStatus.pending => const Color(0xFFF59E0B),
        BookingStatus.confirmed => AppColors.info,
        BookingStatus.dispatched => const Color(0xFF0D9488),
        BookingStatus.inProgress => AppColors.violet,
        BookingStatus.completed => AppColors.success,
        BookingStatus.cancelled => AppColors.danger,
        _ => AppColors.inkMuted,
      };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(status);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10, vertical: dense ? 4 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            BookingStatus.label(status),
            style: TextStyle(
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle(
      {super.key, required this.name, this.size = 44, this.imagePath, this.bg});

  final String name;
  final double size;
  final String? imagePath;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final hasImage = fileExists(imagePath);
    final isNetwork = imagePath != null &&
        (imagePath!.startsWith('http://') || imagePath!.startsWith('https://'));
    Widget image = _initials(context);
    if (isNetwork) {
      image = Image.network(
        imagePath!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        errorBuilder: (_, __, ___) => _initials(context),
      );
    } else if (hasImage) {
      image = Image.file(
        File(imagePath!),
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        errorBuilder: (_, __, ___) => _initials(context),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? AppColors.gold.withValues(alpha: .25),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withValues(alpha: .5)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: image,
    );
  }

  Widget _initials(BuildContext context) {
    return Text(
      initialsOf(name),
      style: TextStyle(
        fontSize: size * .36,
        fontWeight: FontWeight.w900,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class RatingStars extends StatelessWidget {
  const RatingStars(
      {super.key, required this.rating, this.size = 13, this.showValue = true});

  final double rating;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 16),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
            fontSize: size,
          ),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: .18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            PrimaryButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
          ],
        ],
      ),
    );
    // في الشاشة القصيرة يُسحب بدل أن يخرج عن مكانه.
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: constraints.hasBoundedHeight
            ? SingleChildScrollView(child: content)
            : content,
      ),
    );
  }
}

class AppSnack {
  static void show(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: error ? const Color(0xFFFF8A80) : AppColors.gold,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        SecondaryButton(
          label: 'إلغاء',
          compact: true,
          expand: false,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        PrimaryButton(
          label: confirmLabel,
          compact: true,
          expand: false,
          tone: danger ? KeyTone.red : KeyTone.yellow,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    builder: (ctx) => Padding(
      // رفع المحتوى فوق لوحة المفاتيح حتى لا تتداخل مع الحقول أو الأزرار.
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: ConstrainedBox(
        // تحديد أقصى ارتفاع حسب المساحة المتاحة حتى لا يفيض المحتوى.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height -
              MediaQuery.viewInsetsOf(ctx).bottom -
              24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // زر إغلاق ظاهر في كل نافذة سفلية، فلا يُترك الخروج منها للسحب (الآيفون لا زر رجوع فيه).
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14, bottom: 2),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: PushKeyIconButton(
                  icon: Icons.close_rounded,
                  label: 'إغلاق',
                  small: true,
                  onPressed: () => Navigator.maybePop(ctx),
                ),
              ),
            ),
            Flexible(child: builder(ctx)),
          ],
        ),
      ),
    ),
  );
}

class SheetHeader extends StatelessWidget {
  const SheetHeader(
      {super.key, required this.title, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text,
      {super.key, this.required_ = false, this.filled = false});

  final String text;
  final bool required_;

  /// الخانة المطلوبة مملوءة: تختفي نقطتها الحمراء ويبقى مكانها، فلا يتحرك ما تحتها.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, top: 2),
      child: Row(
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
          if (required_)
            Opacity(
              opacity: filled ? 0 : 1,
              child: const Text(' *',
                  style: TextStyle(
                      color: AppColors.danger, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(
      {super.key,
      required this.icon,
      required this.label,
      this.value,
      this.trailing});

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                const SizedBox(height: 1),
                Text(
                  value ?? '—',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.gold,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(11),
      // يتكيف مع ارتفاع الخلية فلا يخرج المحتوى أبداً (حتى مع تكبير الخط).
      child: LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.topStart,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon,
                          size: 17,
                          color: color == AppColors.gold ? null : color),
                    ),
                    // السهم لا يظهر إلا لما يفتح صفحة، فلا يوحي بزر لا يعمل.
                    if (onTap != null) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_outward_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: .35)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(label,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.values,
    required this.index,
    required this.onChanged,
    this.labels,
  });

  final List<String> values;
  final int index;
  final ValueChanged<int> onChanged;
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    // أزرار الاختيار نفسها في الصفحة الرئيسية: المختار بلون الجهة الصفراء، والبقية بيضاء.
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: PushKeyButton(
              label: labels?[i] ?? values[i],
              compact: true,
              tone: i == index ? KeyTone.lemon : KeyTone.white,
              onPressed: () => onChanged(i),
            ),
          ),
        ],
      ],
    );
  }
}

/// سعر الحجز كما يُعرض: المتفق عليه إن حُدد، وإلا يُقال إنه بالاتفاق.
String bookingPriceLabel(Booking booking) =>
    booking.hasPrice ? fmtMoney(booking.total) : 'يُحدد بالاتفاق';
