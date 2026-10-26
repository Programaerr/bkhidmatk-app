# ربط «بخدمتك» بقاعدة بيانات مشتركة (Supabase)

هذه الخطوات تُنفَّذ **مرة واحدة**، وبعدها كل المستخدمين يرون نفس المنشورات
والحجوزات والرسائل مباشرة (تحديث فوري Realtime).

الوقت المتوقع: 10–15 دقيقة. كل شيء على الخطة المجانية.

---

## 1) إنشاء المشروع

1. ادخل إلى <https://supabase.com> وأنشئ حساباً (بالبريد أو GitHub).
2. اضغط **New project**.
3. اختر اسماً مثل `bkhidmatk`، وكلمة مرور قوية لقاعدة البيانات (احفظها).
4. **Region**: اختر `Frankfurt (eu-central-1)` أو `Bahrain` — الأقرب للعراق.
5. انتظر دقيقة حتى يجهز المشروع.

---

## 2) إنشاء الجداول

1. من القائمة اليمنى: **SQL Editor** → **New query**.
2. افتح الملف `supabase/schema.sql` من هذا المستودع، وانسخ **كامل** محتواه.
3. الصقه في المحرر واضغط **Run**.
4. يجب أن تظهر رسالة `Success. No rows returned`.

هذا الملف ينشئ الجداول والعروض (Views) وصلاحيات الحماية (RLS) ودوال الحجز
والإعجاب ومخزن الوسائط (Storage bucket باسم `media`).

---

## 3) إيقاف تأكيد البريد

التطبيق يسجل الدخول برقم الهاتف عبر بريد صناعي `<الرقم>@bkhidmatk.app`،
لذلك يجب ألا يطلب Supabase تأكيد البريد:

1. **Authentication** → **Sign In / Providers** → **Email**.
2. أوقف خيار **Confirm email** (اجعله OFF).
3. تأكد أن **Enable email provider** مفعّل.
4. احفظ (Save).

> لا حاجة لأي إعدادات SMS، ولا يتم إرسال أي رسالة للمستخدم.

---

## 4) إنشاء حسابي الدخول التجريبيين

1. **Authentication** → **Users** → **Add user** → **Create new user**.
2. أنشئ الحسابين التاليين بالضبط:

| البريد | كلمة المرور | الدور |
|---|---|---|
| `07700000000@bkhidmatk.app` | `admin123` | مدير |
| `07701234567@bkhidmatk.app` | `123456` | زبون |

مهم: فعّل **Auto Confirm User** عند إنشاء كل حساب (وإلا لن يستطيع الدخول).

اختياري (حسابات زبائن إضافية للتجربة):
`07712345678@bkhidmatk.app` و `07811112222@bkhidmatk.app` بكلمة مرور `123456`.

---

## 5) إدخال البيانات التجريبية

1. ارجع إلى **SQL Editor** → **New query**.
2. انسخ كامل محتوى الملف `supabase/seed.sql` والصقه ثم **Run**.

سيتم ربط الحسابين بملفات شخصية، وإضافة 8 أقسام و8 فنيين و16 خدمة وحجوزات
ووصولات ومنشورات وتعليقات ورسائل دعم.

> إذا ظهر خطأ «أنشئ أولاً حسابي الدخول التجريبيين» فراجع الخطوة 4.

---

## 6) جلب المفاتيح

من **Project Settings** (أيقونة الترس) → **API**:

- **Project URL**: مثل `https://abcdefgh.supabase.co`
- **anon public key**: يبدأ بـ `eyJ...` (طويل)

هذان المفتاحان عامّان بطبيعتهما، والحماية الحقيقية تأتي من سياسات RLS
الموجودة في `schema.sql` — لا تشارك مفتاح `service_role` أبداً.

---

## 7) بناء نسخة APK متصلة بالسحابة

### الطريقة أ — GitHub Secrets (موصى بها)

في مستودع GitHub: **Settings** → **Secrets and variables** → **Actions** →
**New repository secret**، وأضف:

| الاسم | القيمة |
|---|---|
| `SUPABASE_URL` | رابط المشروع |
| `SUPABASE_ANON_KEY` | مفتاح anon |

ثم أي دفعة (push) إلى `main` تبني نسخة APK جديدة تلقائياً، وتنشرها على رابط
التحميل الثابت:

```
https://github.com/Programaerr/bkhidmatk-app/releases/latest/download/bkhidmatk-1.0.0.apk
```

### الطريقة ب — بناء محلي

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

### بدون مفاتيح

إذا لم تُمرَّر المفاتيح، يعمل التطبيق بالوضع المحلي التجريبي (SQLite على
الجهاز فقط) ولا يشارك البيانات مع أحد.

---

## ملاحظات أمنية وتشغيلية

- كلمة مرور قاعدة البيانات ومفتاح `service_role` سريان تماماً — لا يوضعان في
  التطبيق ولا في المستودع.
- حذف مستخدم من **Authentication** يحذف ملفه وبياناته المرتبطة (Cascade).
- لإعادة إنشاء البيانات التجريبية فقط (دون المساس بالحسابات):

  ```sql
  truncate public.comments, public.posts, public.bookings, public.receipts,
           public.messages, public.cards, public.services, public.workers,
           public.categories restart identity cascade;
  ```

  ثم أعد تشغيل `seed.sql`. (لا تنفّذ هذا الأمر على بيانات حقيقية.)

- يمكن إعادة تشغيل `schema.sql` في أي وقت؛ فهو آمن ولا يحذف البيانات.
