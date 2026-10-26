-- ============================================================================
--  بخدمتك — بيانات تجريبية للمشاركة بين كل المستخدمين
--
--  قبل تشغيل هذا الملف أنشئ حسابَي الدخول من:
--    Authentication → Users → Add user
--      • 07700000000@bkhidmatk.app  /  admin123   (Auto Confirm User)
--      • 07701234567@bkhidmatk.app  /  123456     (Auto Confirm User)
--  ثم شغّل هذا الملف من SQL Editor.
-- ============================================================================

-- ------------------------------------------------- 1) ربط الحسابات بالملفات
insert into public.profiles (auth_id, name, phone, role, email, city, address, created_at)
select u.id, 'مدير بخدمتك', '07700000000', 'admin', 'admin@bkhidmatk.iq',
       'بغداد', 'بغداد - الكرادة', now() - interval '120 days'
from auth.users u
where u.email = '07700000000@bkhidmatk.app'
on conflict (phone) do update
  set auth_id = excluded.auth_id,
      name = excluded.name,
      role = excluded.role;

insert into public.profiles (auth_id, name, phone, role, email, city, address, created_at)
select u.id, 'أحمد سعد', '07701234567', 'customer', null,
       'بغداد', 'بغداد - حي الجامعة، شارع 20', now() - interval '60 days'
from auth.users u
where u.email = '07701234567@bkhidmatk.app'
on conflict (phone) do update
  set auth_id = excluded.auth_id,
      name = excluded.name,
      role = excluded.role;

insert into public.profiles (auth_id, name, phone, role, email, city, address, created_at)
select u.id, 'زينب حسن', '07712345678', 'customer', null,
       'البصرة', 'البصرة - العشار', now() - interval '35 days'
from auth.users u
where u.email = '07712345678@bkhidmatk.app'
on conflict (phone) do update
  set auth_id = excluded.auth_id,
      name = excluded.name,
      role = excluded.role;

insert into public.profiles (auth_id, name, phone, role, email, city, address, created_at)
select u.id, 'مهند عبد الرزاق', '07811112222', 'customer', null,
       'أربيل', 'أربيل - عنكاوا', now() - interval '12 days'
from auth.users u
where u.email = '07811112222@bkhidmatk.app'
on conflict (phone) do update
  set auth_id = excluded.auth_id,
      name = excluded.name,
      role = excluded.role;

-- ------------------------------------------------------------- 2) الأقسام
insert into public.categories (name, icon, color, sort_order)
select v.name, v.icon, v.color, v.sort_order
from (values
  ('كهرباء',         'electrical_services', 4294951175::bigint, 0),
  ('تصليح غسالات',   'local_laundry_service', 4278430196::bigint, 1),
  ('صباغة',          'format_paint', 4287349578::bigint, 2),
  ('ديكورات',        'chair_alt', 4293467747::bigint, 3),
  ('سباكة',          'plumbing', 4278238420::bigint, 4),
  ('تكييف',          'ac_unit', 4282339765::bigint, 5),
  ('تنظيف',          'cleaning_services', 4288423856::bigint, 6),
  ('نجارة',          'carpenter', 4286141768::bigint, 7)
) as v(name, icon, color, sort_order)
where not exists (select 1 from public.categories);

-- ------------------------------------------------------------- 3) الفنيون
insert into public.workers (name, phone, specialty, category_id, rating, jobs_done, bio, available)
select v.name, v.phone, v.specialty, c.id, v.rating, v.jobs, v.bio, 1
from (values
  ('أحمد الجبوري',     '07701112233', 'كهربائي منازل', 'كهرباء',       4.9::double precision, 312, 'خبرة 12 سنة في تأسيس وصيانة الكهرباء المنزلية.'),
  ('مصطفى كريم',       '07802223344', 'فني غسالات',    'تصليح غسالات', 4.8::double precision, 205, 'صيانة جميع أنواع الغسالات الأوتوماتيك والنشافات.'),
  ('علي حسين',         '07903334455', 'صباغ محترف',    'صباغة',        4.7::double precision, 148, 'دهانات حديثة وديكورات جدارية بأجود المواد.'),
  ('يوسف العبيدي',     '07714445566', 'فني ديكور',     'ديكورات',      4.9::double precision,  97, 'جبس بورد وأسقف ثانوية وتصاميم عصرية.'),
  ('حيدر الموسوي',     '07825556677', 'سباك',          'سباكة',        4.6::double precision, 263, 'تسليك مجاري وإصلاح تسريبات المياه.'),
  ('سيف الدين عباس',   '07936667788', 'فني تكييف',     'تكييف',        4.8::double precision, 174, 'تركيب وصيانة وشحن مكيفات سبليت ومركزي.'),
  ('نور الهدى سالم',   '07747778899', 'فريق تنظيف',    'تنظيف',        4.9::double precision, 321, 'تنظيف منازل وشركات بعمالة مدربة ومواد آمنة.'),
  ('كرار عبد الله',    '07858889900', 'نجار موبيليا',  'نجارة',        4.7::double precision, 132, 'تصليح وتفصيل أبواب وخزائن ومطابخ.')
) as v(name, phone, specialty, category, rating, jobs, bio)
join public.categories c on c.name = v.category
where not exists (select 1 from public.workers);

-- ------------------------------------------------------------ 4) الخدمات
insert into public.services (category_id, worker_id, title, description, price, duration, rating, active, created_at)
select c.id, w.id, v.title, v.description, v.price, v.minutes, v.rating, 1,
       now() - (v.days_ago || ' days')::interval
from (values
  ('كهرباء', '07701112233', 'تصليح أعطال كهربائية منزلية', 'فحص كامل للتمديدات وإصلاح الأعطال والمفاتيح والمقابس مع ضمان على العمل.', 25000::double precision, 90, 4.9::double precision, 30),
  ('كهرباء', '07701112233', 'تركيب ثريات وإضاءة LED', 'تركيب وتثبيت الثريات وشرائط الإضاءة مع تنظيم الأسلاك بشكل آمن.', 15000::double precision, 60, 4.8::double precision, 25),
  ('تصليح غسالات', '07802223344', 'صيانة غسالة أوتوماتيك', 'فحص وتصليح أعطال الغسالة: تصريف، دوران، لوحة تحكم، مع قطع غيار أصلية.', 30000::double precision, 90, 4.8::double precision, 30),
  ('تصليح غسالات', '07802223344', 'تصليح نشافة ملابس', 'إصلاح أعطال التسخين والدوران وتنظيف مجرى الهواء.', 25000::double precision, 75, 4.7::double precision, 20),
  ('صباغة', '07903334455', 'صبغ غرفة كاملة', 'تحضير الجدران ومعجون ودهان وجهين مع تشطيب نظيف، السعر يشمل المواد.', 150000::double precision, 480, 4.8::double precision, 30),
  ('صباغة', '07903334455', 'دهان واجهة بناية', 'تنظيف الواجهة ودهان مقاوم للعوامل الجوية بضمان 3 سنوات.', 250000::double precision, 600, 4.7::double precision, 15),
  ('ديكورات', '07714445566', 'تركيب جبس بورد وأسقف ثانوية', 'تصميم وتنفيذ أسقف جبس مع إضاءة مخفية وتشطيب احترافي.', 120000::double precision, 300, 4.9::double precision, 30),
  ('ديكورات', '07714445566', 'تركيب ورق جدران', 'توريد وتركيب ورق جدران عالي الجودة لجميع الغرف.', 60000::double precision, 180, 4.6::double precision, 12),
  ('سباكة', '07825556677', 'تسليك مجاري', 'فتح الانسدادات وإزالة الترسبات بأجهزة حديثة دون تكسير.', 35000::double precision, 60, 4.7::double precision, 30),
  ('سباكة', '07825556677', 'إصلاح تسريب مياه', 'كشف التسريبات وإصلاح الأنابيب والخلاطات مع ضمان.', 20000::double precision, 45, 4.8::double precision, 10),
  ('تكييف', '07936667788', 'تنظيف مكيف سبليت', 'غسيل كامل للوحدة الداخلية والخارجية وتعقيم الفلاتر.', 20000::double precision, 60, 4.9::double precision, 30),
  ('تكييف', '07936667788', 'شحن غاز مكيف', 'فحص الضغط وشحن غاز الـ R410 مع كشف التسريبات.', 40000::double precision, 75, 4.8::double precision, 9),
  ('تنظيف', '07747778899', 'تنظيف منزل شامل', 'تنظيف الغرف والمطبخ والحمامات بعمالة مدربة ومواد صديقة للبيئة.', 75000::double precision, 240, 4.9::double precision, 30),
  ('تنظيف', '07747778899', 'غسيل سيارة داخل وخارج', 'غسيل احترافي مع تلميع داخلي وتنظيف المحرك.', 15000::double precision, 90, 4.8::double precision, 8),
  ('نجارة', '07858889900', 'تصليح أبواب وخزائن', 'إصلاح المفصلات والأقفال وتعديل الأبواب الخشبية.', 40000::double precision, 120, 4.7::double precision, 7),
  ('نجارة', '07858889900', 'تفصيل وتركيب مطبخ', 'تصميم وتنفيذ مطبخ حسب المساحة مع خامات مقاومة للرطوبة.', 300000::double precision, 720, 4.6::double precision, 6)
) as v(category, worker_phone, title, description, price, minutes, rating, days_ago)
join public.categories c on c.name = v.category
join public.workers w on w.phone = v.worker_phone
where not exists (select 1 from public.services);

-- ----------------------------------------- 5) الحجوزات والوصولات والمنشورات
do $$
declare
  v_admin bigint;
  v_c1    bigint;
  v_c2    bigint;
  v_b1    bigint;
  v_p1    bigint;
  v_p3    bigint;
begin
  select id into v_admin from public.profiles where phone = '07700000000';
  select id into v_c1    from public.profiles where phone = '07701234567';
  select id into v_c2    from public.profiles where phone = '07712345678';

  if v_admin is null or v_c1 is null then
    raise exception
      'أنشئ أولاً حسابي الدخول التجريبيين (07700000000 و 07701234567) من Authentication ثم أعد تشغيل هذا الملف.';
  end if;

  -- الحجوزات
  if not exists (select 1 from public.bookings) then
    insert into public.bookings
      (customer_id, service_id, worker_id, scheduled_at, slot, address, status, payment_method, total, created_at)
    values
      (v_c1, (select id from public.services where title = 'تصليح أعطال كهربائية منزلية' limit 1),
             (select worker_id from public.services where title = 'تصليح أعطال كهربائية منزلية' limit 1),
             date_trunc('day', now()) + interval '10 hours', '10:00',
             'بغداد - حي الجامعة، شارع 20', 'completed', 'card', 25000, now() - interval '2 days'),
      (v_c1, (select id from public.services where title = 'صيانة غسالة أوتوماتيك' limit 1),
             (select worker_id from public.services where title = 'صيانة غسالة أوتوماتيك' limit 1),
             date_trunc('day', now()) + interval '1 day 12 hours', '12:00',
             'بغداد - حي الجامعة، شارع 20', 'pending', 'cash', 30000, now() - interval '2 days'),
      (v_c1, (select id from public.services where title = 'صبغ غرفة كاملة' limit 1),
             (select worker_id from public.services where title = 'صبغ غرفة كاملة' limit 1),
             date_trunc('day', now()) + interval '4 days 9 hours', '09:00',
             'بغداد - حي الجامعة، شارع 20', 'confirmed', 'cash', 150000, now() - interval '2 days'),
      (v_c1, (select id from public.services where title = 'غسيل سيارة داخل وخارج' limit 1),
             (select worker_id from public.services where title = 'غسيل سيارة داخل وخارج' limit 1),
             date_trunc('day', now()) - interval '3 days' + interval '16 hours', '16:00',
             'بغداد - حي الجامعة، شارع 20', 'completed', 'card', 15000, now() - interval '5 days');

    if v_c2 is not null then
      insert into public.bookings
        (customer_id, service_id, worker_id, scheduled_at, slot, address, status, payment_method, total, created_at)
      values
        (v_c2, (select id from public.services where title = 'تنظيف مكيف سبليت' limit 1),
               (select worker_id from public.services where title = 'تنظيف مكيف سبليت' limit 1),
               date_trunc('day', now()) + interval '2 days 11 hours', '11:00',
               'البصرة - العشار', 'confirmed', 'card', 20000, now() - interval '2 days'),
        (v_c2, (select id from public.services where title = 'تسليك مجاري' limit 1),
               (select worker_id from public.services where title = 'تسليك مجاري' limit 1),
               date_trunc('day', now()) - interval '1 day' + interval '14 hours', '14:00',
               'البصرة - العشار', 'completed', 'cash', 35000, now() - interval '4 days');
    end if;
  end if;

  select id into v_b1 from public.bookings
   where customer_id = v_c1
     and service_id = (select id from public.services where title = 'تصليح أعطال كهربائية منزلية' limit 1)
   order by id limit 1;

  -- الوصولات
  if not exists (select 1 from public.receipts) then
    insert into public.receipts
      (invoice_no, booking_id, user_id, title, amount, method, card_brand, last4, paid, created_at)
    values
      ('BKD-' || extract(year from now())::int || '-00001', v_b1, v_c1, 'وصل دفع خدمة',
       25000, 'card', 'Mastercard', '4821', 1, now()),
      ('BKD-' || extract(year from now())::int || '-00002', null, v_c1, 'وصل دفع خدمة',
       15000, 'card', 'Mastercard', '4821', 1, now() - interval '3 days');

    if v_c2 is not null then
      insert into public.receipts
        (invoice_no, booking_id, user_id, title, amount, method, paid, created_at)
      values
        ('BKD-' || extract(year from now())::int || '-00003', null, v_c2, 'وصل دفع خدمة',
         35000, 'cash', 1, now() - interval '1 day');
    end if;
  end if;

  -- المنشورات
  if not exists (select 1 from public.posts) then
    insert into public.posts
      (customer_id, category_id, title, description, price, media, media_type, location, approved, likes, created_at)
    values
      (v_c1, (select id from public.categories where name = 'كهرباء'),
       'تصليح لوحة كهرباء كاملة في يوم واحد',
       'استبدلت القواطع وتنظيم الأسلاك لبيت في حي الجامعة. الشغل نظيف والمواد أصلية، والفيديو يوضح النتيجة النهائية.',
       45000, 'asset:assets/media/work_electric.jpg', 'image', 'بغداد - حي الجامعة', 1, 34, now() - interval '5 hours');

    if v_c2 is not null then
      insert into public.posts
        (customer_id, category_id, title, description, price, media, media_type, location, approved, likes, created_at)
      values
        (v_c2, (select id from public.categories where name = 'تنظيف'),
         'غسيل سيارة داخل وخارج',
         'خدمة غسيل متنقلة، نجي لعندك بالبصرة. شغل مرتب ومواد تلميع أصلية.',
         15000, 'asset:assets/media/work_car.jpg', 'image', 'البصرة - العشار', 1, 21, now() - interval '20 hours');
    end if;

    insert into public.posts
      (customer_id, category_id, title, description, price, media, media_type, location, approved, likes, created_at)
    values
      (v_c1, (select id from public.categories where name = 'صباغة'),
       'صبغ غرفة نوم بلمسة ديكورية',
       'دهان وجهين مع خط ذهبي على الجدار الرئيسي. المدة يومان فقط.',
       120000, 'asset:assets/media/work_paint.jpg', 'image', 'بغداد - زيونة', 1, 57, now() - interval '2 days');

    if v_c2 is not null then
      insert into public.posts
        (customer_id, category_id, title, description, price, media, media_type, location, approved, likes, created_at)
      values
        (v_c2, (select id from public.categories where name = 'تكييف'),
         'صيانة وشحن مكيف سبليت',
         'تنظيف كامل + شحن غاز + فحص تسريبات. اشتغل المكيف مثل الجديد.',
         30000, 'asset:assets/media/work_ac.jpg', 'image', 'البصرة - الجزائر', 1, 18, now() - interval '3 days');
    end if;
  end if;

  select id into v_p1 from public.posts
   where title = 'تصليح لوحة كهرباء كاملة في يوم واحد' order by id limit 1;
  select id into v_p3 from public.posts
   where title = 'صبغ غرفة نوم بلمسة ديكورية' order by id limit 1;

  -- التعليقات
  if not exists (select 1 from public.comments) then
    if v_p1 is not null then
      insert into public.comments (post_id, user_id, user_name, body, created_at)
      values
        (v_p1, v_c2, 'زينب حسن', 'شغل مرتب ما شاء الله، ممكن رقمك؟', now() - interval '3 hours'),
        (v_p1, v_admin, 'مدير بخدمتك', 'تم توثيق العمل بنجاح ✅ شكراً لمشاركتك.', now() - interval '2 hours');
    end if;
    if v_p3 is not null then
      insert into public.comments (post_id, user_id, user_name, body, created_at)
      values
        (v_p3, v_c2, 'زينب حسن', 'اللون يجنن، أي نوع صبغ استخدمت؟', now() - interval '1 day');
    end if;
  end if;

  -- رسائل الدعم
  if not exists (select 1 from public.messages) then
    insert into public.messages (thread_id, sender_id, sender_role, body, created_at, read)
    values
      (v_c1, v_c1, 'customer', 'مرحباً، حجزت صيانة غسالة أوتوماتيك وبغيت أتأكد من الوقت.', now() - interval '26 hours', 1),
      (v_c1, v_admin, 'admin', 'أهلاً بك أستاذ أحمد 👋 تم استلام حجزك، الفني مصطفى سيتواصل معك قبل الموعد بنصف ساعة.', now() - interval '25 hours', 1),
      (v_c1, v_c1, 'customer', 'ممتاز، شكراً لكم.', now() - interval '24 hours', 1),
      (v_c1, v_admin, 'admin', 'خدمتك تسعدنا دائماً. أي استفسار آخر نحن هنا.', now() - interval '23 hours', 1);

    if v_c2 is not null then
      insert into public.messages (thread_id, sender_id, sender_role, body, created_at, read)
      values
        (v_c2, v_c2, 'customer', 'هل يوجد غسيل سيارات اليوم في العصر؟', now() - interval '4 hours', 0);
    end if;
  end if;
end $$;

-- ------------------------------------------------------------ 6) الإعدادات
insert into public.settings (key, value) values
  ('admin_phone',    '07700000000'),
  ('support_hours',  '9:00 ص - 10:00 م'),
  ('app_commission', '0'),
  ('currency',       'IQD'),
  ('card_test_mode', '1'),
  ('app_version',    '1.0.0')
on conflict (key) do nothing;
