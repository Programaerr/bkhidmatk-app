import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

/// يعيد تحميل بيانات الشاشة تلقائياً عند أي تغيير على قاعدة البيانات
/// المشتركة (Supabase Realtime). في الوضع المحلي لا تصل أي أحداث.
mixin RealtimeRefresh<T extends StatefulWidget> on State<T> {
  StreamSubscription<void>? _realtimeSub;

  /// نفّذ هنا تحميل بيانات الشاشة من جديد.
  void onRealtimeChange();

  @override
  void initState() {
    super.initState();
    final repo = context.read<AppState>().repo;
    _realtimeSub = repo.changes.listen((_) {
      if (mounted) onRealtimeChange();
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}
