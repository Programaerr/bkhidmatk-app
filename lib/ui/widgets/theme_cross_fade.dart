import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../auth/day_night_switch.dart';

/// تبديل الوضع الليلي داخل التطبيق بتلاشٍ هادئ: تُصوَّر الشاشة قبل التبديل، وتبقى صورتها فوق
/// الألوان الجديدة ثم تخفت ببطء. أزرار التطبيق ترسم ألوان الليل دفعة واحدة، فبدونه كانت
/// الشاشة تقفز من النهار إلى الليل.
class ThemeCrossFade extends StatefulWidget {
  const ThemeCrossFade({super.key, required this.child});

  final Widget child;

  /// يصوّر الشاشة، ثم يبدّل بـ [change]، ثم يُخفي الصورة ببطء. بلا هذا الغلاف يبدّل فقط.
  static Future<void> swap(
    BuildContext context,
    Future<void> Function() change,
  ) {
    final state = context.findAncestorStateOfType<_ThemeCrossFadeState>();
    return state == null ? change() : state._swap(change);
  }

  @override
  State<ThemeCrossFade> createState() => _ThemeCrossFadeState();
}

class _ThemeCrossFadeState extends State<ThemeCrossFade>
    with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final _fade = AnimationController(
    vsync: this,
    duration: kNightSwitchDuration,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) _clear();
    });
  late final _opacity = ReverseAnimation(
    CurvedAnimation(parent: _fade, curve: Curves.easeInOut),
  );
  ui.Image? _shot;

  Future<void> _swap(Future<void> Function() change) async {
    if (MediaQuery.disableAnimationsOf(context)) return change();
    // تُصوَّر بعد إطار مكتمل، فلا يبقى في الشاشة شيء بانتظار الرسم.
    await WidgetsBinding.instance.endOfFrame;
    final box = _boundary.currentContext?.findRenderObject();
    if (!mounted || box is! RenderRepaintBoundary) return change();
    // الصورة تشمل صورة سابقة لم تخفت بعد، فالضغط مرتين متتاليتين لا يقفز.
    final shot = box.toImageSync(pixelRatio: View.of(context).devicePixelRatio);
    _fade.stop();
    setState(() {
      _shot?.dispose();
      _shot = shot;
    });
    _fade.value = 0;
    await change();
    if (!mounted) return;
    // يبدأ الخفوت مع أول إطار بالألوان الجديدة.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && identical(_shot, shot)) _fade.forward(from: 0);
  }

  void _clear() {
    if (!mounted) return;
    setState(() {
      _shot?.dispose();
      _shot = null;
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _shot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shot;
    return RepaintBoundary(
      key: _boundary,
      child: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: shot == null
                ? const SizedBox.shrink()
                : IgnorePointer(
                    child: FadeTransition(
                      opacity: _opacity,
                      child: RawImage(image: shot, fit: BoxFit.fill),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
