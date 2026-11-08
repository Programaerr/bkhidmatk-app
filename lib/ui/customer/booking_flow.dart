import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../data/models.dart';
import '../../core/utils.dart';
import '../../state/app_state.dart';
import '../widgets/quick_route.dart';
import '../widgets/ui.dart';
import 'booking_screen.dart';
import 'profile_completion_screen.dart';

/// يبدأ حجز [service]: يكمل بيانات الزبون إن نقصت، ثم يفتح صفحة الحجز. [workerId] هو الحرفي
/// الذي اختاره الزبون من صفحته.
Future<void> startServiceBooking(
  BuildContext context,
  Service service, {
  int? workerId,
}) async {
  final user = context.read<AppState>().user;
  if (user == null) {
    AppSnack.show(context, tr('سجل الدخول أولاً لإتمام الحجز', 'Log in first to complete the booking'), error: true);
    return;
  }

  final profileIncomplete = user.name.trim().length < 3 ||
      !iraqCities.contains(user.city) ||
      (user.address?.trim().length ?? 0) < 8;
  if (profileIncomplete) {
    final completed = await Navigator.push<bool>(
      context,
      QuickRoute(builder: (_) => const ProfileCompletionScreen()),
    );
    if (completed != true || !context.mounted) return;
  }
  if (!context.mounted) return;
  Navigator.push(
    context,
    QuickRoute(builder: (_) => BookingScreen(service: service, workerId: workerId)),
  );
}
