# جايك — Jaik

تطبيق عربي (RTL) لحجز عمال الخدمات المنزلية في العراق: الزبون ينشر عملاً
موثّقاً بالفيديو، يحجز خدمة، يدفع بماستركارد (وضع تجريبي)، ويطبع وصل A5،
وللمدير لوحة تحكم كاملة.

- **Flutter** + Provider + Cairo + Material 3 (فاتح/داكن)
- **Supabase** للمصادقة والبيانات والإشعارات والوسائط؛ SQLite متاحة فقط كخيار تجريبي عند عدم إعداد Supabase.

## تشغيل سريع

ضع `SUPABASE_URL` و`SUPABASE_PUBLISHABLE_KEY` في `.env` بجذر المشروع.
إعداد VS Code **Flutter: Supabase (كلمة المرور)** يقرأهما تلقائياً؛ لا تضع
مفتاح `service_role` في `.env` أو داخل التطبيق.

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

أكمل إعداد Supabase أدناه قبل تشغيل التطبيق سحابياً. يستخدم الدخول السحابي رقم الهاتف وكلمة المرور، ولا يرسل OTP. من دون المتغيرين أعلاه لن يتصل التطبيق بقاعدة البيانات.

## إعداد Supabase

1. افتح **Supabase → SQL Editor**، والصق الملف [`supabase/setup.sql`](./supabase/setup.sql) ونفّذه. ينشئ الجداول والعلاقات والفهارس وسياسات RLS ودوال العمليات وStorage وبيانات الكتالوج.
2. في **Authentication → Sign In / Providers → Email** تأكد أن مزوّد **Email** مفعّل، ثم أوقف **Confirm email**. يستخدم الدخول كلمة مرور وبريداً داخلياً مشتقاً من رقم الهاتف (`07...@jaik.app`) ولا يرسل OTP.
3. شغّل التطبيق باستخدام **Project URL** و **Publishable key** (أو المفتاح العام القديم `anon`) من إعدادات المشروع:

   ```powershell
   flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
   ```

   في VS Code اختر **Flutter: Supabase (كلمة المرور)**، وأنشئ حساباً بالرقم `07717506711` وكلمة مرور تختارها. يستخدم التطبيق البريد الداخلي `07717506711@jaik.app` لحساب Supabase؛ لا ترسل OTP.
4. بعد نجاح التسجيل، نفّذ [`supabase/disable_otp_admin.sql`](./supabase/disable_otp_admin.sql) في SQL Editor، ثم سجّل الخروج والدخول مجدداً. يربط السكربت المدير بمعرّف حساب Auth الذي أنشأته ويتحقق من رقم الهاتف في بيانات الحساب؛ وجود الرقم في `admin_phones` وحده لا يمنح صلاحية. لا تستخدم `service_role` داخل التطبيق أو تشاركه؛ صلاحياته تتجاوز سياسات قاعدة البيانات.

   ### المعاينة المحلية دون قاعدة بيانات

   للمعاينة فقط، اختر **Flutter: Local preview (بدون قاعدة بيانات)**، أو نفّذ:

   ```powershell
   flutter run -d chrome --dart-define=DEV_ADMIN_PREVIEW=true
   ```

   هذا الوضع لا يتصل بـ Supabase ولا يحفظ تغييرات الريلز بعد إعادة التشغيل؛
   لا تستخدمه لإدارة البيانات الحقيقية.

لبناء نسخة GitHub Actions مرتبطة بالمشروع، أضف `SUPABASE_URL` و`SUPABASE_PUBLISHABLE_KEY` إلى **Repository secrets**. من دونها تُبنى النسخة في الوضع المحلي فقط.

بعدها تُحفظ الحسابات والخدمات والحجوزات والمنشورات والتعليقات والأعمال والمحادثات والبطاقات والوصولات والإعدادات والإشعارات والوسائط في Supabase. تُرسل الإدارة إشعارات داخل التطبيق للزبائن أو الحرفيين أو رقم مسجل؛ ويقرأها المستخدم من «حسابي ← إشعارات جايك». لا تُرسل هذه الإشعارات SMS أو إشعارات نظام الهاتف.

تقبل الريلز روابط ملفات الفيديو المباشرة وروابط المشاركة العامة من منصات مثل
YouTube وTikTok وInstagram وVimeo وFacebook وDailymotion، وتعرض الرابط داخل
التطبيق متى سمحت المنصة بالتضمين. الروابط الخاصة أو التي تتطلب تسجيل دخول أو
تمنع العرض داخل التطبيقات قد لا تعمل أو قد تتطلب ضغط زر التشغيل.

**مهم:** لا تنتقل البيانات القديمة المحفوظة في SQLite تلقائياً؛ ابدأ بقاعدة Supabase جديدة أو انقل البيانات القديمة يدوياً بعد مراجعتها. الدفع بالبطاقة في التطبيق تجريبي ولا يخصم أموالاً؛ لا تعتمد على حالة الدفع أو إحصاءات الإيراد كإثبات مالي حقيقي قبل ربط مزوّد دفع موثوق.

## بناء APK

```bash
flutter build apk --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
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
