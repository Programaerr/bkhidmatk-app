# جايك — Jaik

تطبيق عربي (RTL) لحجز عمال الخدمات المنزلية في العراق: الزبون ينشر عملاً
موثّقاً بالفيديو، يحجز خدمة، يدفع بماستركارد (وضع تجريبي)، ويطبع وصل A5،
وللمدير لوحة تحكم كاملة.

- **Flutter** + Provider + Cairo + Material 3 (فاتح/داكن)
- **مصادقة الهاتف والإشعارات** عبر Supabase؛ بيانات الخدمات والحجوزات الحالية ما زالت محلية في SQLite.

## تشغيل سريع

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

أكمل إعداد Supabase أدناه قبل استخدام تسجيل الهاتف والإشعارات. يلزم تفعيل تسجيل الهاتف ومزوّد SMS. من دون المتغيرين أعلاه يعمل التطبيق في الوضع المحلي فقط.

## Supabase: تسجيل الهاتف والإشعارات

1. افتح **Supabase → SQL Editor**، والصق الملف [`supabase/setup.sql`](./supabase/setup.sql) ونفّذه.
2. فعّل **Phone** في إعدادات Authentication واضبط مزوّد SMS في Supabase. لا يحتاج هذا التكامل إلى Firebase.
3. أنشئ حساب المدير من التطبيق برقم الهاتف وتحقق من رمز SMS، ثم رقِّ الحساب مرة واحدة من SQL Editor:

   ```sql
   update public.app_profiles set role = 'admin' where phone = '07700000000';
   ```

   استبدل الرقم برقم المدير الفعلي ثم سجّل الخروج والدخول مجدداً. لا تمنح التطبيق صلاحية ترقية الحسابات.
4. شغّل التطبيق باستخدام **Project URL** و **anon/public key** من إعدادات المشروع:

   ```powershell
   flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
   ```

   لا تستخدم `service_role` داخل تطبيق الهاتف أو تشاركه؛ صلاحياته تتجاوز سياسات قاعدة البيانات.

لبناء نسخة GitHub Actions مرتبطة بالمشروع، أضف `SUPABASE_URL` و`SUPABASE_PUBLISHABLE_KEY` إلى **Repository secrets**. من دونها تُبنى النسخة في الوضع المحلي فقط.

بعدها يعمل تسجيل الدخول والتسجيل برمز الهاتف، وتُرسل الإدارة إشعارات داخل التطبيق للزبائن أو الحرفيين أو رقم مسجل. يستطيع المستخدم قراءتها من «حسابي ← إشعارات جايك». الإشعارات محفوظة في Supabase ولا تُرسل SMS أو إشعارات نظام الهاتف.

**مهم:** بقية بيانات التطبيق الحالية (مثل الخدمات والحجوزات والمحادثات والوصولات) ما زالت تستخدم SQLite المحلية. ملف SQL هذا يربط الحسابات والتوظيف والإشعارات فقط؛ لا يجعل بقية البيانات متزامنة بين الأجهزة.

## نظام النقاط

كل نجمة تقييم على حجز مكتمل = 10 نقاط تُضاف مباشرة إلى رصيد الزبون
وتظهر في «حسابي».

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
