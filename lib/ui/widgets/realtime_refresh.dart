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

  // الرجوع إلى تبويب حُمّل قبل قليل لا يعيد تحميله: بياناته ما زالت حديثة، وإعادة جلبها
  // وبنائها مع كل تبديل كانت تثقل السيرفر وتقطّع الحركة. الرجوع من صفحة فُتحت فوقه
  // يعيد التحميل دائماً، فما تغيّر فيها يظهر فوراً.
  static const _fresh = Duration(seconds: 30);

  ValueListenable<TickerModeData>? _visible;
  StreamSubscription<void>? _liveSub;
  Timer? _reload;
  bool _wasHidden = false;
  bool _hiddenByPage = false;
  DateTime _loadedAt = DateTime.now();

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
      if (!_wasHidden) {
        // صفحة فُتحت فوقها تخفيها ويبقى الرجوع ممكناً؛ تبديل التبويب يخفيها بلا صفحة فوقها.
        // البحث عن الـ Navigator لا يربط الصفحة به، فلا تُعاد بناءً مع كل فتح وإغلاق.
        _hiddenByPage = Navigator.maybeOf(context)?.canPop() ?? false;
      }
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
      final stale = DateTime.now().difference(_loadedAt) >= _fresh;
      if (!_hiddenByPage && !stale) return;
      _reload = Timer(_settle, () {
        if (!mounted) return;
        _loadedAt = DateTime.now();
        onRealtimeChange();
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
