# بخدمتك — Bkhidmatk

تطبيق عربي (RTL) لحجز عمال الخدمات المنزلية في العراق: الزبون ينشر عملاً
موثّقاً بالفيديو، يحجز خدمة، يدفع بماستركارد (وضع تجريبي)، ويطبع وصل A5،
وللمدير لوحة تحكم كاملة.

- **Flutter** + Provider + Cairo + Material 3 (فاتح/داكن)
- **الوضع المحلي**: SQLite على الجهاز (بيانات تجريبية جاهزة)
- **الوضع المشترك**: Supabase (Postgres + Auth + Storage + Realtime)

## تشغيل سريع

```bash
flutter pub get
flutter run
```

بدون إعدادات إضافية يعمل التطبيق محلياً:

| الحساب | الهاتف | كلمة المرور |
|---|---|---|
| مدير | `07700000000` | `admin123` |
| زبون | `07701234567` | `123456` |

## تشغيل البيانات المشتركة بين كل المستخدمين

اتبع الخطوات في [`supabase/SETUP.md`](supabase/SETUP.md) (إنشاء مشروع
Supabase، تنفيذ `supabase/schema.sql` ثم `supabase/seed.sql`، وإضافة
`SUPABASE_URL` و`SUPABASE_ANON_KEY` كـ GitHub Secrets أو كـ `--dart-define`).

## بناء APK

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

أو اترك البناء للـ GitHub Actions: ملف `.github/workflows/build-apk.yml`
ينشر النسخة على `releases/latest`.

رابط التحميل الثابت:
<https://github.com/Programaerr/bkhidmatk-app/releases/latest/download/bkhidmatk-1.0.0.apk>

## بنية المشروع

```
lib/
  core/            الألوان، الثيم، أدوات مساعدة
  data/            النماذج + Repository (محلي SQLite وسحابي Supabase)
  state/           AppState: الجلسة، الثيم، اختيار قاعدة البيانات
  ui/
    auth/          الدخول والتسجيل
    customer/      الرئيسية، الخدمات، الحجز، الدفع، الوصولات، الرسائل
    admin/         لوحة التحكم والإدارة
    common/        مستند الوصل (A5 PDF)
    widgets/       مكوّنات مشتركة + تحديث فوري Realtime
supabase/
  schema.sql       الجداول + RLS + Views + RPCs + Storage + Realtime
  seed.sql         بيانات تجريبية مرتبطة بحسابات الدخول
  SETUP.md         دليل الإعداد خطوة بخطوة
```
