import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

/// صفحة تحدّث بياناتها وهي ظاهرة فقط، فلا تعمل في الخلفية ولا تُبقي اتصالاً بالسيرفر.
///
/// تعيد التحميل كلما رجعت إلى الظهور. والصفحة التي تحتاج تحديثاً فورياً وهي
/// مفتوحة تجعل [listensLive] صحيحة، فيُفتح الاتصال معها ويُغلق عند اختفائها.
mixin RealtimeRefresh<T extends StatefulWidget> on State<T> {
  // بعد انتهاء انتقال الصفحة، حتى لا يزاحم التحميل حركتها.
  static const _settle = Duration(milliseconds: 350);

  ValueListenable<TickerModeData>? _visible;
  StreamSubscription<void>? _liveSub;
  Timer? _reload;
  bool _wasHidden = false;

  /// نفّذ هنا تحميل بيانات الشاشة من جديد.
  void onRealtimeChange();

  bool get listensLive => false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _followVisibility();
  }

  @override
  void activate() {
    super.activate();
    _followVisibility();
  }

  void _followVisibility() {
    final visible = TickerMode.getValuesNotifier(context);
    if (identical(visible, _visible)) return;
    _visible?.removeListener(_onVisibilityChanged);
    _visible = visible..addListener(_onVisibilityChanged);
    _onVisibilityChanged();
  }

  void _onVisibilityChanged() {
    if (!_visible!.value.enabled) {
      _wasHidden = true;
      _reload?.cancel();
      _liveSub?.cancel();
      _liveSub = null;
      return;
    }
    if (listensLive) {
      _liveSub ??= context.read<AppState>().repo.changes.listen((_) {
        if (mounted) onRealtimeChange();
      });
    }
    if (_wasHidden) {
      _wasHidden = false;
      _reload = Timer(_settle, () {
        if (mounted) onRealtimeChange();
      });
    }
  }

  @override
  void dispose() {
    _visible?.removeListener(_onVisibilityChanged);
    _reload?.cancel();
    _liveSub?.cancel();
    super.dispose();
  }
}
