import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../auth/auth_route.dart';
import '../auth/push_key.dart';
import '../widgets/realtime_refresh.dart';
import '../widgets/ui.dart';
import 'home_keys.dart';

/// مقاسات التصميم المعتمد بالبكسل (إطار عرضه 391).
abstract final class _Design {
  static const titleCenter = 61.5;
  static const titleHeight = 32.0;
  static const titleSize = 18.0;

  static const searchLeft = 67.2;
  static const searchWidth = 260.3;
  static const searchTop = 145.4;
  static const searchHeight = 51.5;
  static const searchRadius = 11.4;
  static const searchMargin = 12.0;
  static const searchIconSize = 21.0;
  static const searchIconGap = 8.0;
  static const searchTextSize = 13.0;
  static const clearWidth = 30.0;
  static const clearIconSize = 18.0;

  // الأزرار الخمسة الأولى كما في التصميم، والأطول منها بقدر اسمها.
  static const choiceTop = 227.1;
  static const choiceMinWidth = 56.7;
  static const choiceHeight = 25.7;
  static const choiceRadius = 10.7;
  static const choiceRight = 15.7;
  static const choiceGap = 18.1;
  static const choiceTextSize = 11.0;
  static const choicePadding = 10.0;
  static const choiceTouchMargin = 6.0;
  static const choiceScroll = Duration(milliseconds: 250);

  // عرض الزر يُقرَّب إلى هذا الحد، فتتشارك الأزرار المتقاربة صورة واحدة.
  static const choiceWidthStep = 8.0;

  static const gridTop = 277.0;
  static const gridLefts = [203.1, 14.8];
  static const pageBottom = 24.0;

  static const messageSize = 13.0;
}

/// كتابة واحدة لما يتبدل من الحروف، فيجد «احمد» صاحب اسم «أحمد».
String _searchable(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ئ', 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp('[ً-ْـ]'), '');

/// يفتح تبويب الفنيين على نوع شغل معين، ولو كان هو نفسه آخر ما فُتح.
class TechniciansChoice extends ChangeNotifier {
  String? section;

  void choose(String name) {
    section = name;
    notifyListeners();
  }
}

/// تبويب الفنيين: البحث عن حرفي أو الاختيار حسب نوع الشغل، وتحتهما مجموعة الحرفيين.
class TechniciansTab extends StatefulWidget {
  const TechniciansTab({super.key, this.loadedSections, this.loadedWorkers, this.choice});

  /// نوع الشغل المضغوط عليه في الصفحة الرئيسية.
  final TechniciansChoice? choice;

  /// ما جلبته الصفحة الرئيسية، فيفتح التبويب منه فوراً دون انتظار السيرفر.
  final List<Category>? Function()? loadedSections;
  final List<Worker>? Function()? loadedWorkers;

  @override
  State<TechniciansTab> createState() => _TechniciansTabState();
}

class _TechniciansTabState extends State<TechniciansTab> with RealtimeRefresh<TechniciansTab> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _choicesScroll = ScrollController();
  final _choiceKeys = <String?, GlobalKey>{};
  List<Category> _sections = customerSections(const []);
  List<Worker>? _workers;
  String? _chosen;
  bool _failed = false;

  @override
  void onRealtimeChange() => _load();

  @override
  void initState() {
    super.initState();
    final sections = widget.loadedSections?.call();
    final workers = widget.loadedWorkers?.call();
    if (sections != null && workers != null) {
      _sections = sections;
      _workers = workers;
    } else {
      _load();
    }
    widget.choice?.addListener(_onChosenOutside);
    _chosen = widget.choice?.section;
    _showChosen(animate: false);
  }

  @override
  void dispose() {
    widget.choice?.removeListener(_onChosenOutside);
    _choicesScroll.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // البحث القديم لا يخفي حرفيي النوع الذي ضُغط عليه.
  void _onChosenOutside() {
    _search.clear();
    setState(() => _chosen = widget.choice!.section);
    _showChosen(animate: false);
  }

  void _choose(String? name) {
    setState(() => _chosen = name);
    _showChosen(animate: true);
  }

  /// يحرّك شريط الاختيارات حتى يظهر الزر المختار في وسطه.
  void _showChosen({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chip = _choiceKeys[_chosen]?.currentContext?.findRenderObject();
      if (chip == null || !_choicesScroll.hasClients) return;
      _choicesScroll.position.ensureVisible(
        chip,
        alignment: .5,
        duration: animate ? _Design.choiceScroll : Duration.zero,
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _load() async {
    final repo = context.read<AppState>().repo;
    try {
      final results = await Future.wait([
        repo.listCategories(),
        repo.listWorkers(onlyAvailable: true),
      ]);
      if (!mounted) return;
      setState(() {
        _sections = customerSections(results[0] as List<Category>);
        _workers = results[1] as List<Worker>;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  List<Worker>? get _shown {
    final workers = _workers;
    if (workers == null) return null;
    final names = {for (final section in _sections) section.id: section.name};
    final chosenId = _sections
        .where((section) => section.name == _chosen)
        .map((section) => section.id)
        .firstOrNull;
    final query = _searchable(_search.text);
    return [
      for (final worker in workers)
        if ((_chosen == null || worker.categoryId == chosenId) &&
            (query.isEmpty ||
                _searchable('${worker.name} ${worker.specialty} ${names[worker.categoryId] ?? ''}')
                    .contains(query)))
          worker,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // شريط الحالة فوق الجهة الصفراء دائماً، نهاراً وليلاً.
      value: appSystemBars(night: false),
      child: ColoredBox(
        color: night ? homeNightGround : homeCream,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final unit = homeUnit(width);
            final left = (width - homeDesignWidth * unit) / 2;
            final top = homePageTop(safeTop, unit);
            final hillBottom = homeHillBottom(top, unit);
            return Stack(
              children: [
                Positioned.fill(
                  child: RefreshIndicator(
                    edgeOffset: hillBottom,
                    onRefresh: _load,
                    child: _page(unit, left, top, night),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: hillBottom,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      HomeHill(width: width, unit: unit, top: top),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: top + (_Design.titleCenter - _Design.titleHeight / 2) * unit,
                        height: _Design.titleHeight * unit,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'كل الفنيين',
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: _Design.titleSize * unit,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: homeLabel,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _page(double unit, double left, double top, bool night) {
    final chromeInset = PushKey.faceInset * unit * homeKeyChrome;
    final chromeDepth = PushKey.depth * homeKeyChrome;
    final choicesTop = _Design.choiceTop - _Design.choiceTouchMargin;
    final choicesHeight =
        _Design.choiceHeight + chromeDepth + _Design.choiceTouchMargin * 2;
    final choices = [null, for (final section in _sections) section.name];
    final shown = _shown;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.zero,
      children: [
        SizedBox(height: top + _Design.searchTop * unit),
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: left + _Design.searchLeft * unit - chromeInset),
            child: _searchKey(unit, night),
          ),
        ),
        SizedBox(
          height: (choicesTop - _Design.searchTop - _Design.searchHeight - chromeDepth) * unit,
        ),
        SizedBox(
          height: choicesHeight * unit,
          // كلها مبنية، حتى يتحرك الشريط إلى الزر المختار ولو كان بعيداً.
          child: SingleChildScrollView(
            controller: _choicesScroll,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: left + _Design.choiceRight * unit - chromeInset,
            ),
            child: Row(
              children: [
                for (final (i, name) in choices.indexed) ...[
                  if (i > 0) SizedBox(width: _Design.choiceGap * unit - chromeInset * 2),
                  _ChoiceKey(
                    key: _choiceKeys.putIfAbsent(name, GlobalKey.new),
                    label: name ?? 'الكل',
                    selected: name == _chosen,
                    unit: unit,
                    onPressed: () => _choose(name),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: (_Design.gridTop - choicesTop - choicesHeight) * unit),
        if (_failed && _workers == null)
          _Message(
            text: 'تعذّر جلب الفنيين. اسحب الصفحة إلى الأسفل لإعادة المحاولة.',
            unit: unit,
            night: night,
          )
        else if (shown != null && shown.isEmpty)
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'لا يوجد فنيون مطابقون',
            subtitle: 'جرّب كلمة بحث أخرى أو اختر نوع شغل مختلفاً.',
          )
        else
          Center(
            child: CraftsmanGrid(unit: unit, workers: shown, lefts: _Design.gridLefts),
          ),
        SizedBox(height: _Design.pageBottom * unit),
      ],
    );
  }

  Widget _searchKey(double unit, bool night) {
    final chrome = unit * homeKeyChrome;
    final ink = night ? homeNightInk : homeInk;
    final faceHeight = _Design.searchHeight * unit;
    final textStyle = TextStyle(
      fontFamily: 'Cairo',
      fontSize: _Design.searchTextSize * unit,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: ink,
    );
    return SizedBox(
      width: _Design.searchWidth * unit + PushKey.faceInset * 2 * chrome,
      height: faceHeight + PushKey.depth * chrome,
      child: PushKey(
        unit: chrome,
        faceHeight: faceHeight,
        faceRadius: _Design.searchRadius,
        night: night ? kAlwaysCompleteAnimation : kAlwaysDismissedAnimation,
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: _Design.searchMargin * unit),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _searchFocus.requestFocus,
                child: Icon(
                  Icons.search_rounded,
                  size: _Design.searchIconSize * unit,
                  color: ink,
                ),
              ),
              SizedBox(width: _Design.searchIconGap * unit),
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  maxLines: 1,
                  style: textStyle,
                  cursorColor: ink,
                  // بلا إطار خانات التطبيق، فالزر نفسه هو الخانة.
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'ابحث عن حرفي',
                    hintStyle: textStyle.copyWith(color: ink.withValues(alpha: .55)),
                  ),
                ),
              ),
              if (_search.text.isNotEmpty)
                Semantics(
                  button: true,
                  label: 'مسح البحث',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(_search.clear),
                    child: SizedBox(
                      width: _Design.clearWidth * unit,
                      height: double.infinity,
                      child: Icon(
                        Icons.close_rounded,
                        size: _Design.clearIconSize * unit,
                        color: ink,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(width: _Design.searchMargin * unit),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر اختيار نوع الشغل: أبيض، والمختار منها بلون أزرار الحرفيين.
class _ChoiceKey extends StatelessWidget {
  const _ChoiceKey({
    super.key,
    required this.label,
    required this.selected,
    required this.unit,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final double unit;
  final VoidCallback onPressed;

  double _faceWidth(BuildContext context, TextStyle style) {
    final text = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.rtl,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final needed = text.width + _Design.choicePadding * 2 * unit;
    text.dispose();
    final step = _Design.choiceWidthStep * unit;
    return math.max(_Design.choiceMinWidth * unit, (needed / step).ceil() * step);
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final chrome = unit * homeKeyChrome;
    final faceHeight = _Design.choiceHeight * unit;
    final style = TextStyle(
      fontFamily: 'Cairo',
      fontSize: _Design.choiceTextSize * unit,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: night && !selected ? homeNightInk : homeInk,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: _Design.choiceTouchMargin * unit),
          child: SizedBox(
            width: _faceWidth(context, style) + PushKey.faceInset * 2 * chrome,
            height: faceHeight + PushKey.depth * chrome,
            child: PushKey(
              unit: chrome,
              faceHeight: faceHeight,
              faceRadius: _Design.choiceRadius,
              lemon: selected,
              night: night ? kAlwaysCompleteAnimation : kAlwaysDismissedAnimation,
              child: ExcludeSemantics(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, maxLines: 1, style: style),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.unit, required this.night});

  final String text;
  final double unit;
  final bool night;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _Design.searchLeft * unit),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: _Design.messageSize * unit,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: night ? homeNightInk : homeLabel,
        ),
      ),
    );
  }
}
