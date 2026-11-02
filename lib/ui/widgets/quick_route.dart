import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// انتقال الصفحة المعتاد نفسه، لكنه أسرع، ولا تضيع خطواته إذا تأخر إطار.
class QuickRoute<T> extends MaterialPageRoute<T> {
  QuickRoute({required super.builder});

  static const _duration = Duration(milliseconds: 200);

  @override
  Duration get transitionDuration => _duration;

  @override
  Duration get reverseTransitionDuration => _duration;

  @override
  AnimationController createAnimationController() => AnimationController(
        duration: transitionDuration,
        reverseDuration: reverseTransitionDuration,
        debugLabel: debugLabel,
        vsync: _SteadyStartVsync(navigator!),
      );
}

/// أول إطارين في الصفحة يتأخران لأنها تُبنى وتُرسم فيهما أول مرة. يُحسب كل منهما
/// خطوة واحدة، فتبدأ الحركة من أولها بدل أن تقفز فوق ما فاتها.
class _SteadyStartVsync implements TickerProvider {
  const _SteadyStartVsync(this._parent);

  final TickerProvider _parent;

  static const _oneFrame = Duration(microseconds: 16667);
  static const _late = Duration(milliseconds: 25);
  static const _forgivenFrames = 2;

  @override
  Ticker createTicker(TickerCallback onTick) {
    var last = Duration.zero;
    var skipped = Duration.zero;
    var forgiven = 0;
    return _parent.createTicker((elapsed) {
      // الحركة بدأت من جديد، مثل الرجوع بعد الدخول.
      if (elapsed < last) {
        skipped = Duration.zero;
        forgiven = 0;
      } else if (elapsed - last > _late && forgiven < _forgivenFrames) {
        skipped += elapsed - last - _oneFrame;
        forgiven++;
      }
      last = elapsed;
      onTick(elapsed - skipped);
    });
  }
}
