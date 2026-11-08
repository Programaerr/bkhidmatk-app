import 'package:flutter/widgets.dart';

/// لغة التطبيق كله: العربية أو الإنجليزية. يغيّرها زر اللغة عبر `AppState.setEnglish`.
bool appEnglish = false;

/// النص بلغة التطبيق الآن: [ar] بالعربية، و[en] بالإنجليزية.
///
/// الصفحات تبقى من اليمين إلى اليسار في اللغتين، فلا يتغير مكان شيء (طلب المستخدم). لذلك يُحاط
/// النص الإنجليزي بعلامتي اتجاه لا تُرى، فتبقى علامات الترقيم والأرقام في مكانها من الجملة.
String tr(String ar, String en) => appEnglish ? '\u202A$en\u202C' : ar;

/// النص بلا علامات الاتجاه، مثل الحرف الأول من اسم.
String withoutDirectionMarks(String text) =>
    text.replaceAll(RegExp('[\u200E\u200F\u202A-\u202E\u2066-\u2069]'), '');

/// يعيد بناء كل ما في الشاشة بعد تغيير اللغة، حتى الصفحات المحفوظة خلف غيرها، فلا يبقى فيها
/// نص باللغة السابقة. حالة كل صفحة تبقى كما هي.
void rebuildForLanguage() {
  void mark(Element element) {
    element.markNeedsBuild();
    element.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
}
