# جايك — Jaik

تطبيق عربي (RTL) لحجز عمال الخدمات المنزلية في العراق: الزبون ينشر عملاً
موثّقاً بالفيديو، يحجز خدمة، يدفع بماستركارد (وضع تجريبي)، ويطبع وصل A5،
وللمدير لوحة تحكم كاملة.

- **Flutter** + Provider + Cairo + Material 3 (فاتح/داكن)
- **قاعدة البيانات والمصادقة**: Supabase، مع تسجيل الدخول برقم الهاتف وكلمة المرور

## تشغيل سريع

```bash
flutter pub get
```

في VS Code شغّل إعداد **Flutter: Supabase (كلمة المرور)** من قائمة Run and
Debug. يقرأ الإعداد `SUPABASE_URL` و`SUPABASE_PUBLISHABLE_KEY` من `.env`
ويُمرّرهما للتطبيق دون تضمين مفتاح `service_role`.

لإنشاء الجداول والسياسات على مشروع جديد، نفّذ `supabase/setup.sql` في SQL
Editor في Supabase. سجّل حساب المدير من التطبيق برقم الهاتف وكلمة المرور،
وأوقف **Confirm email** في إعدادات Email ضمن Supabase Auth. إذا لم يكن الحساب
مديراً بعد، نفّذ `supabase/disable_otp_admin.sql` مرة واحدة بعد إنشاء الحساب.
بعدها سجّل الدخول من صفحة تسجيل الدخول بالرقم وكلمة المرور؛ لا يستخدم التطبيق
رمز OTP.

## بناء APK

```bash
flutter build apk --release
```

أو اترك البناء للـ GitHub Actions: ملف `.github/workflows/build-apk.yml`
ينشر النسخة على `releases/latest`.

رابط التحميل الثابت:
<https://github.com/Programaerr/bkhidmatk-app/releases/latest/download/jaik-1.0.0.apk>

## التشغيل داخل Docker (Dev Container)

المشروع جاهز للنقل إلى أي جهاز: كل الأدوات (Flutter 3.47.8 + JDK 17 +
Android SDK 36 + NDK) موجودة داخل صورة Docker معرّفة في ملف `Dockerfile`،
فلا ي depend على أي شيء مثبّت على الحاسب.

**خطوات الاستخدام في VS Code:**

1. ثبّت [Docker Desktop](https://www.docker.com/products/docker-desktop/) وأشغّله.
2. في VS Code ثبّت إضافة **Dev Containers** (`ms-vscode-remote.remote-containers`).
3. افتح مجلد المشروع ثم `Ctrl+Shift+P` ← **Dev Containers: Reopen in Container**.
4. أول مرة تُبنى الصورة (تنزيل Flutter + Android SDK ≈ 4–6 جيجا، مرة واحدة فقط).
5. بعدها تعمل الأوامر كالمعتاد داخل التيرمنال المدمج (Ctrl+`):

```bash
flutter pub get      # يُنفَّذ تلقائياً بعد فتح الحاوية
flutter test         # الاختبارات
flutter build apk --release
```

الملف الناتج `build/app/outputs/flutter-apk/app-release.apk` يظهر مباشرة داخل
`build/` على جهازك (المجلد مُربط بالحاوية).

**بدون VS Code (سطر أوامر):**

```bash
docker build -t jaik-dev .
docker run -it --rm -v "%cd%:/workspace" -w /workspace jaik-dev bash
```

ملاحظات:

- الحاويتان `jaik-pub-cache` و`jaik-gradle-cache` تحفظان التنزيلات بين
  الجلسات فلا تعيد `pub get` وبناء Gradle من الصفر.
- على جهاز جديد: اعمل `git clone` ثم افتح المجلد في VS Code و«Reopen in
  Container» فقط — لا شيء آخر.
- بناء APK للاستثمار المحلي (ملف `gradle-wrapper.properties` و`mirrors.gradle`)
  لا يُرفع إلى Git عمداً؛ الحاوية تستخدم الإعدادات الرسمية من المستودع.

## بنية المشروع

```
lib/
  core/            الألوان، الثيم، أدوات مساعدة
  data/            النماذج + قاعدة بيانات SQLite المحلية
  state/           AppState: الجلسة والثيم
  ui/
    auth/          الدخول والتسجيل
    customer/      الرئيسية، الخدمات، الحجز، الدفع، الوصولات، الرسائل
    admin/         لوحة التحكم والإدارة
    common/        مستند الوصل (A5 PDF)
    widgets/       مكوّنات مشتركة
```
