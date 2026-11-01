import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_route.dart';
import 'craftsman_screen.dart';
import 'push_key.dart';
import 'register_screen.dart';
import 'thinking_scene.dart';

const _cream = Color(0xFFFFFEE2);
const _nightGround = Colors.black;

/// مقاسات التصميم المعتمد بالبكسل (إطار 391×715).
abstract final class _Design {
  static const width = 391.0;
  static const height = 715.0;
  static const hillBottom = 414.3;

  // زر الرجوع في الزاوية نفسها التي فيها زر الليل والنهار في الشاشة الأولى.
  static const barCenter = 34.6;
  static const barGap = 24.0;
  static const barHeight = 27.25;
  static const backMargin = 19.9;
  static const backTouchHeight = 56.0;

  static const keyWidth = 121.4;
  static const keyGap = 24.8;
}

/// من ينشئ حساباً جديداً يختار هنا: زبون أو حرفي.
class AccountTypeScreen extends StatelessWidget {
  const AccountTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safeArea = MediaQuery.viewPaddingOf(context);
    final fit = math.min(size.width / _Design.width, size.height / _Design.height);
    final unit = pushKeyUnit(context);
    final night = Theme.of(context).brightness == Brightness.dark;
    final ground = night ? _nightGround : _cream;
    final hillBottom = size.height * _Design.hillBottom / _Design.height;

    // الفراغ فوق الزرين مثل الفراغ تحتهما. شريط التنقل بلون الصفحة، فيمتد الفراغ السفلي إلى أيقوناته.
    const navIconsGap = 14.0;
    final keysHeight = PushKeyButton.outerHeight * unit;
    final freeSpace = size.height - safeArea.bottom - hillBottom - keysHeight;
    final keysTop = hillBottom + math.max(freeSpace + navIconsGap, 0.0) / 2;
    final keysWidth = (_Design.keyWidth * 2 + _Design.keyGap) * unit;

    // زر الرجوع يبقى في زاوية الشاشة وتحت شريط الحالة في كل الهواتف.
    final barCenter = math.max(
      size.height * _Design.barCenter / _Design.height,
      safeArea.top + _Design.barGap + _Design.barHeight / 2 * unit,
    );

    // الشاشات القصيرة تعرض الباقي بالسحب، والأطول لا تتحرك.
    final pageHeight = math.max(size.height, keysTop + keysHeight + 12 + safeArea.bottom);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: ground,
        systemNavigationBarIconBrightness: night ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: ground,
        body: SingleChildScrollView(
          child: SizedBox(
            height: pageHeight,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: hillBottom,
                  child: ThinkingScene(scale: fit),
                ),
                PositionedDirectional(
                  start: 0,
                  width: (_Design.backMargin + PushKeyBack.width) * unit,
                  top: barCenter - _Design.backTouchHeight / 2,
                  height: _Design.backTouchHeight,
                  child: const PushKeyBack(),
                ),
                Positioned(
                  left: (size.width - keysWidth) / 2,
                  width: keysWidth,
                  top: keysTop,
                  child: Row(
                    children: [
                      Expanded(
                        child: PushKeyButton(
                          label: 'زبون',
                          onPressed: () =>
                              openAuthPage(context, const RegisterScreen(), night: night),
                        ),
                      ),
                      SizedBox(width: _Design.keyGap * unit),
                      Expanded(
                        child: PushKeyButton(
                          label: 'حرفي',
                          onPressed: () =>
                              openAuthPage(context, const CraftsmanScreen(), night: night),
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
    );
  }
}
