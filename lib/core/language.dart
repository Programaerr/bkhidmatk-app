import 'package:flutter/widgets.dart';

/// لغة التطبيق كله: العربية أو الإنجليزية. يغيّرها زر اللغة عبر `AppState.setEnglish`.
bool appEnglish = false;

/// النص بلغة التطبيق الآن: [ar] بالعربية، و[en] بالإنجليزية.
String tr(String ar, String en) => appEnglish ? en : ar;

/// اتجاه الكتابة بلغة التطبيق: من اليمين بالعربية، ومن اليسار بالإنجليزية.
TextDirection get appTextDirection =>
    appEnglish ? TextDirection.ltr : TextDirection.rtl;

/// يعيد بناء كل ما في الشاشة بعد تغيير اللغة، حتى الصفحات المحفوظة خلف غيرها، فلا يبقى فيها
/// نص باللغة السابقة. حالة كل صفحة تبقى كما هي.
void rebuildForLanguage() {
  void mark(Element element) {
    element.markNeedsBuild();
    element.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
}
