import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../auth/auth_route.dart';
import '../auth/day_night_switch.dart';
import '../auth/push_key.dart';
import '../auth/truck_scene.dart';
import '../widgets/quick_route.dart';
import '../widgets/theme_cross_fade.dart';
import '../widgets/ui.dart';
import 'home_keys.dart';
import 'messages_screen.dart';
import 'receipts_screen.dart';

/// مقاسات التصميم المعتمد بالبكسل (إطار عرضه 391).
abstract final class _Design {
  static const keyWidth = 279.9;
  static const keyRadius = 11.1;

  // البطاقة: الصورة في يمينها وزر التعديل في يسارها، والمعلومات مقابل الصورة.
  // البطاقة بقدر الصورة: فوق وجهها وتحت حلقتها الهامش نفسه الذي فوقها في التصميم.
  static const cardHeight = photoTop * 2 + photoSize + PushKey.depth * homeKeyChrome;
  static const cardRadius = 11.5;
  static const photoSize = 52.7;
  static const photoMargin = 14.0;
  static const photoTop = 12.1;
  static const editSize = 34.2;
  static const editMargin = 20.5;
  static const editIconSize = 17.0;

  // بين الصورة والمعلومات ما بين دائرة الملف الشخصي والاسم في الصفحة الرئيسية.
  static const infoGap = 10.0;
  static const nameSize = 16.0;
  static const phoneSize = 12.5;
  static const citySize = 12.0;
  static const cityIconSize = 13.0;

  static const menuHeight = 73.1;
  static const nightHeight = 47.2;
  static const languageHeight = 51.9;
  static const logoutHeight = 39.0;

  // الفراغات كما في التصميم: من أسفل الجهة الزرقاء أو من قاعدة الزر إلى وجه الذي بعده.
  static const cardGap = 54.4;
  static const groupGap = 21.6;
  static const rowGap = 7.8;

  // عنوان «الإعدادات» فوق الوضع الليلي واللغة، أقرب إليهما مما فوقه.
  static const settingsTitleSize = 15.0;
  static const settingsTitleGap = 9.0;
  static const logoutGap = 50.3;

  // التصميم أطول مما فوق شريط التنقل، فتضيق الفراغات لا الأزرار حتى يظهر زر الخروج كله.
  // وإذا ضاقت إلى هذا الحد تتحرك الصفحة.
  static const barMargin = 12.0;
  static const minSpacing = .35;

  // ما داخل الأزرار.
  static const keyMargin = 14.0;
  static const menuBadgeSize = 38.0;
  static const menuIconSize = 20.0;
  static const smallBadgeSize = 30.0;
  static const smallIconSize = 17.0;
  static const badgeGap = 10.0;
  static const titleSize = 14.0;
  static const subtitleSize = 10.5;
  static const arrowSize = 22.0;
  static const switchHeight = 22.0;
  static const pillHeight = 26.0;
  static const pillPadding = 10.0;
  static const pillRadius = 8.0;
  static const pillTextSize = 11.0;
  static const logoutTextSize = 13.0;
  static const logoutIconSize = 18.0;
  static const logoutIconGap = 6.0;
}

TextStyle _text(double unit, double size, FontWeight weight, Color color) => TextStyle(
      fontFamily: 'Cairo',
      fontSize: size * unit,
      height: 1.3,
      fontWeight: weight,
      color: color,
    );

class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.onOpenBookings,
    this.workerMode = false,
    this.onOpenAdminDashboard,
  });

  final VoidCallback onOpenBookings;
  final VoidCallback? onOpenAdminDashboard;

  /// وضع الموظف بالتوضيف: يُخفى كل ما لا يخصه (حجوزات ووصولات).
  final bool workerMode;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _fold = HeaderFold();

  /// مكان مفتاح الليل، ليبقى حياً فوق خفوت الشاشة.
  final _nightSwitch = LayerLink();

  @override
  void dispose() {
    _fold.dispose();
    super.dispose();
  }

  Future<void> _editProfile() async {
    final state = context.read<AppState>();
    final user = state.user!;
    final name = TextEditingController(text: user.name);
    final address = TextEditingController(text: user.address ?? '');
    String city = user.city ?? 'بغداد';

    final saved = await showAppSheet<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SheetHeader(title: tr('تعديل الملف الشخصي', 'Edit profile')),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: tr('الاسم', 'Name'),
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showAppSheet<String>(
                      context,
                      builder: (ctx) => ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 440),
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                              child: SheetHeader(title: tr('المحافظة', 'Province')),
                            ),
                            Expanded(
                              child: ListView(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                children: [
                                  for (final c in iraqCities)
                                    ListTile(
                                      title: Text(cityLabel(c)),
                                      onTap: () => Navigator.pop(ctx, c),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (picked != null) setSheetState(() => city = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.location_city_rounded, size: 20),
                      suffixIcon: Icon(Icons.expand_more_rounded, size: 20),
                    ),
                    child: Text(cityLabel(city)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: address,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: tr('العنوان', 'Address'),
                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: tr('حفظ التغييرات', 'Save changes'),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      await state.updateProfile(user.copyWith(
        name: name.text.trim().isEmpty ? user.name : name.text.trim(),
        city: city,
        address: address.text.trim(),
      ));
      if (mounted) AppSnack.show(context, tr('تم تحديث بياناتك', 'Your details were updated'));
    }
  }

  Future<void> _logout() async {
    final ok = await confirmAction(context,
        title: tr('تسجيل الخروج', 'Log out'),
        message: tr('هل تريد تسجيل الخروج من حسابك؟', 'Do you want to log out of your account?'),
        confirmLabel: tr('خروج', 'Log out'),
        danger: true);
    if (ok && mounted) await context.read<AppState>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final night = Theme.of(context).brightness == Brightness.dark;
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    final barRoom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // شريط الحالة فوق الجهة الزرقاء دائماً، نهاراً وليلاً، فأيقوناته بيضاء.
      value: appSystemBars(night: true),
      child: ColoredBox(
        color: night ? homeNightGround : homeCream,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final unit = homeUnit(width);
            final top = homePageTop(safeTop, unit);
            final hillBottom = homeHillBottom(top, unit);
            final rows = _rows(state, unit, night);
            final base = PushKey.depth * homeKeyChrome;
            final keys = rows.fold(0.0, (sum, row) => sum + row.height + base);
            final gaps = rows.fold(0.0, (sum, row) => sum + row.gap);
            final room =
                (constraints.maxHeight - barRoom - hillBottom) / unit - _Design.barMargin;
            final spacing = ((room - keys) / gaps).clamp(_Design.minSpacing, 1.0);
            return Stack(
              children: [
                Positioned.fill(
                  child: _fold.track(
                    child: ListView(
                      // يبقى آخر زر فوق شريط التنقل الزجاجي.
                      padding: EdgeInsets.only(top: hillBottom, bottom: barRoom),
                      children: [
                        for (final row in rows) ...[
                          SizedBox(height: row.gap * spacing * unit),
                          Center(child: row.key),
                        ],
                        SizedBox(height: _Design.barMargin * unit),
                      ],
                    ),
                  ),
                ),
                FoldingHeader(
                  fold: _fold,
                  unit: unit,
                  safeTop: safeTop,
                  top: top,
                  builder: (context, metrics) =>
                      HomeHeader(width: width, metrics: metrics, title: tr('الملف الشخصي', 'Profile')),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// أزرار الصفحة بالترتيب، مع الفراغ قبل كل منها وارتفاع وجهه.
  List<({double gap, double height, Widget key})> _rows(AppState state, double unit, bool night) {
    final menu = [
      if (!widget.workerMode)
        _MenuKey(
          unit: unit,
          icon: Icons.event_note_rounded,
          title: tr('حجوزاتي', 'My bookings'),
          subtitle: tr('كل حجوزاتك وحالتها', 'All your bookings and their status'),
          onPressed: widget.onOpenBookings,
        ),
      if (!widget.workerMode)
        _MenuKey(
          unit: unit,
          icon: Icons.receipt_long_rounded,
          title: tr('وصولاتي', 'My receipts'),
          subtitle: tr('وصولات الدفع القابلة للطباعة', 'Printable payment receipts'),
          onPressed: () => Navigator.push(
            context,
            QuickRoute(builder: (_) => const ReceiptsScreen()),
          ),
        ),
      if (!widget.workerMode && widget.onOpenAdminDashboard != null)
        _MenuKey(
          unit: unit,
          icon: Icons.space_dashboard_rounded,
          title: tr('لوحة التحكم', 'Dashboard'),
          subtitle: tr('إدارة التطبيق والحجوزات', 'Manage the app and bookings'),
          onPressed: widget.onOpenAdminDashboard!,
        ),
      _MenuKey(
        unit: unit,
        icon: Icons.support_agent_rounded,
        title: tr('الرسائل والدعم', 'Messages & support'),
        subtitle: tr('تواصل مع إدارة جايك', 'Contact the Jaik team'),
        onPressed: () => Navigator.push(
          context,
          QuickRoute(builder: (_) => const MessagesScreen()),
        ),
      ),
    ];
    final dark = state.themeMode == ThemeMode.dark;
    final ink = night ? homeNightInk : homeInk;
    return [
      (gap: _Design.cardGap, height: _Design.cardHeight, key: _card(state.user!, unit, night)),
      for (final (i, key) in menu.indexed)
        (gap: i == 0 ? _Design.groupGap : _Design.rowGap, height: _Design.menuHeight, key: key),
      // عنوان في الوسط يعرّف أن ما تحته إعدادات (طلب المستخدم). ليس زراً، فلا تُحسب له قاعدة.
      (
        gap: _Design.groupGap,
        height: _Design.settingsTitleSize * 1.3 - PushKey.depth * homeKeyChrome,
        key: Semantics(
          header: true,
          child: Text(
            tr('الإعدادات', 'Settings'),
            textAlign: TextAlign.center,
            style: _text(unit, _Design.settingsTitleSize, FontWeight.w800, ink),
          ),
        ),
      ),
      (
        gap: _Design.settingsTitleGap,
        height: _Design.nightHeight,
        key: _WideKey(
          unit: unit,
          faceHeight: _Design.nightHeight,
          label: tr('الوضع الليلي', 'Night mode'),
          pressable: false,
          toggled: dark,
          // الشاشة تتحول إلى الليل بتلاشٍ بطيء، والمفتاح ينقلب بسرعته فوقها (طلب المستخدم).
          onPressed: () => ThemeCrossFade.swap(
            context,
            () => state.setTheme(!dark),
            live: (
              link: _nightSwitch,
              size: Size(_Design.switchHeight * 2 * unit, _Design.switchHeight * unit),
              builder: (context) => DayNightSwitch(
                night: context.watch<AppState>().themeMode == ThemeMode.dark,
              ),
            ),
          ),
          child: Row(
            children: [
              _Badge(
                unit: unit,
                size: _Design.smallBadgeSize,
                icon: dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                iconSize: _Design.smallIconSize,
              ),
              SizedBox(width: _Design.badgeGap * unit),
              Expanded(
                child: Text(
                  tr('الوضع الليلي', 'Night mode'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(unit, _Design.titleSize, FontWeight.w800, ink),
                ),
              ),
              SizedBox(
                width: _Design.switchHeight * 2 * unit,
                height: _Design.switchHeight * unit,
                child: CompositedTransformTarget(
                  link: _nightSwitch,
                  child: DayNightSwitch(night: dark),
                ),
              ),
            ],
          ),
        ),
      ),
      (
        gap: _Design.groupGap,
        height: _Design.languageHeight,
        key: _WideKey(
          unit: unit,
          faceHeight: _Design.languageHeight,
          label: tr('اللغة', 'Language'),
          pressable: false,
          value: state.english ? 'English' : 'عربي',
          onPressed: () => state.setEnglish(!state.english),
          child: Row(
            children: [
              _Badge(
                unit: unit,
                size: _Design.smallBadgeSize,
                icon: Icons.public,
                iconSize: _Design.smallIconSize,
              ),
              SizedBox(width: _Design.badgeGap * unit),
              Expanded(
                child: Text(
                  tr('اللغة', 'Language'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(unit, _Design.titleSize, FontWeight.w800, ink),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _LanguagePill(unit: unit, english: state.english),
                ),
              ),
            ],
          ),
        ),
      ),
      (
        gap: _Design.logoutGap,
        height: _Design.logoutHeight,
        key: _WideKey(
          unit: unit,
          faceHeight: _Design.logoutHeight,
          label: tr('تسجيل الخروج', 'Log out'),
          red: true,
          onPressed: _logout,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout_rounded, size: _Design.logoutIconSize * unit, color: Colors.white),
                  SizedBox(width: _Design.logoutIconGap * unit),
                  Text(
                    tr('تسجيل الخروج', 'Log out'),
                    style: _text(unit, _Design.logoutTextSize, FontWeight.w800, Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// بطاقة الحساب بلون التطبيق: الصورة وزر التعديل، والاسم والرقم والمحافظة.
  Widget _card(AppUser user, double unit, bool night) {
    final chrome = unit * homeKeyChrome;
    final inset = PushKey.faceInset * chrome;
    final ink = night ? homeNightInk : homeInk;
    final photoCenter = (_Design.photoTop + _Design.photoSize / 2) * unit;
    // المعلومات بين حلقة زر التعديل وحلقة الصورة، بعيدة عن كل منهما.
    final infoLeft = inset * 2 + (_Design.editMargin + _Design.editSize + _Design.infoGap) * unit;
    final infoRight = inset * 2 + (_Design.photoMargin + _Design.photoSize + _Design.infoGap) * unit;
    final infoWidth = _Design.keyWidth * unit + inset * 2 - infoLeft - infoRight;
    return SizedBox(
      width: _Design.keyWidth * unit + inset * 2,
      height: _Design.cardHeight * unit + PushKey.depth * chrome,
      child: Stack(
        children: [
          // البطاقة نفسها لا تُضغط، بل زر التعديل فيها.
          Positioned.fill(
            child: IgnorePointer(
              child: PushKey(
                unit: chrome,
                faceHeight: _Design.cardHeight * unit,
                faceRadius: _Design.cardRadius,
                lemon: true,
                night: night ? kAlwaysCompleteAnimation : kAlwaysDismissedAnimation,
                child: const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            right: _Design.photoMargin * unit,
            top: _Design.photoTop * unit,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: PushKeyCircle(
                  diameter: _Design.photoSize * unit,
                  unit: chrome,
                  onColour: true,
                  label: user.name,
                  onPressed: null,
                  child: PersonFace(
                    name: user.name,
                    imagePath: user.avatarPath,
                    size: _Design.photoSize * unit,
                    color: ink,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: _Design.editMargin * unit,
            top: photoCenter - _Design.editSize / 2 * unit,
            child: PushKeyCircle(
              diameter: _Design.editSize * unit,
              unit: chrome,
              onColour: true,
              label: tr('تعديل الملف الشخصي', 'Edit profile'),
              onPressed: _editProfile,
              child: Icon(Icons.edit_outlined, size: _Design.editIconSize * unit, color: ink),
            ),
          ),
          // المعلومات في وسط الصورة كلها، بوجهها وحلقتها، مثل الاسم في الصفحة الرئيسية.
          Positioned(
            left: infoLeft,
            width: infoWidth,
            top: _Design.photoTop * unit,
            height: _Design.photoSize * unit + PushKey.depth * chrome,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                width: infoWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الاسم الطويل يصغر حتى يظهر كله، ولا يُقطع.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        user.name,
                        maxLines: 1,
                        style: _text(unit, _Design.nameSize, FontWeight.w800, AppColors.onGold),
                      ),
                    ),
                    Text(
                      user.phone,
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                      style: _text(unit, _Design.phoneSize, FontWeight.w700, AppColors.onGold),
                    ),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: _Design.cityIconSize * unit, color: AppColors.onGold),
                        SizedBox(width: 3 * unit),
                        Flexible(
                          child: Text(
                            user.city == null ? tr('العراق', 'Iraq') : cityLabel(user.city!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _text(unit, _Design.citySize, FontWeight.w600, AppColors.onGold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// زر بعرض البطاقة من نظام أزرار التطبيق، وما فيه يبدأ بهامش من طرفيه.
class _WideKey extends StatelessWidget {
  const _WideKey({
    required this.unit,
    required this.faceHeight,
    required this.label,
    required this.onPressed,
    required this.child,
    this.red = false,
    this.toggled,
    this.value,
    this.pressable = true,
  });

  final double unit;
  final double faceHeight;
  final String label;
  final VoidCallback onPressed;
  final Widget child;
  final bool red;
  final bool? toggled;
  final String? value;

  /// ينخفض حين يُلمس، إلا مفتاحَي الوضع الليلي واللغة (طلب المستخدم).
  final bool pressable;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final chrome = unit * homeKeyChrome;
    return Semantics(
      button: true,
      label: label,
      toggled: toggled,
      value: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: _Design.keyWidth * unit + PushKey.faceInset * 2 * chrome,
          height: faceHeight * unit + PushKey.depth * chrome,
          child: PushKey(
            unit: chrome,
            faceHeight: faceHeight * unit,
            faceRadius: _Design.keyRadius,
            red: red,
            pressable: pressable,
            night: night ? kAlwaysCompleteAnimation : kAlwaysDismissedAnimation,
            child: ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: _Design.keyMargin * unit),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// زر أبيض لصفحة أخرى: أيقونة في دائرة زرقاء، واسم وشرح، وسهم.
class _MenuKey extends StatelessWidget {
  const _MenuKey({
    required this.unit,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final double unit;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final ink = night ? homeNightInk : homeInk;
    return _WideKey(
      unit: unit,
      faceHeight: _Design.menuHeight,
      label: title,
      onPressed: onPressed,
      child: Row(
        children: [
          _Badge(
            unit: unit,
            size: _Design.menuBadgeSize,
            icon: icon,
            iconSize: _Design.menuIconSize,
          ),
          SizedBox(width: _Design.badgeGap * unit),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(unit, _Design.titleSize, FontWeight.w800, ink),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(unit, _Design.subtitleSize, FontWeight.w600, ink.withValues(alpha: .6)),
                ),
              ],
            ),
          ),
          // يتجه السهم إلى اليسار في العربية، مثل سهم «عرض الكل».
          Icon(Icons.chevron_right_rounded, size: _Design.arrowSize * unit, color: ink),
        ],
      ),
    );
  }
}

/// أيقونة بيضاء في دائرة بلون الجهة العليا.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.unit,
    required this.size,
    required this.icon,
    required this.iconSize,
  });

  final double unit;
  final double size;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * unit,
      height: size * unit,
      decoration: const BoxDecoration(
        color: TruckSceneMetrics.hillColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: iconSize * unit, color: AppColors.onGold),
    );
  }
}

/// اللغتان، والمختارة منهما بلون الجهة الزرقاء.
class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.unit, required this.english});

  final double unit;
  final bool english;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final ink = night ? homeNightInk : homeInk;
    final radius = BorderRadius.circular(_Design.pillRadius * unit);
    Widget option(String text, bool chosen) => Container(
          height: _Design.pillHeight * unit,
          padding: EdgeInsets.symmetric(horizontal: _Design.pillPadding * unit),
          alignment: Alignment.center,
          decoration: chosen
              ? BoxDecoration(color: TruckSceneMetrics.hillColor, borderRadius: radius)
              : null,
          child: Text(
            text,
            style: _text(
              unit,
              _Design.pillTextSize,
              FontWeight.w800,
              chosen ? AppColors.onGold : ink.withValues(alpha: .6),
            ),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(color: ink.withValues(alpha: .06), borderRadius: radius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option('عربي', !english), option('English', english)],
      ),
    );
  }
}
