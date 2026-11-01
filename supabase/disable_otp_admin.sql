-- =====================================================================
--  «جايك» — إلغاء OTP وتفعيل الدخول برقم الهاتف + كلمة المرور،
--  ومنح صلاحيات المدير الكاملة لأي رقم موجود في جدول admin_phones.
--
--  نفّذ هذا الملف مرة واحدة في: Supabase → SQL Editor → Run
--  قبل التنفيذ: أزل التعليق عن الخطوة (3) وضع رقمك الحقيقي مكان 07XXXXXXXXX.
-- =====================================================================

begin;

create extension if not exists pgcrypto;

-- 0) تطبيع الرقم العراقي (آمن إذا كانت الدالة موجودة مسبقاً)
create or replace function public.normalize_iraqi_phone(p_phone text)
returns text
language sql
immutable
strict
as $$
  select case
    when regexp_replace(p_phone, '[^0-9+]', '', 'g') like '+964%'
      then '0' || substr(regexp_replace(p_phone, '[^0-9]', '', 'g'), 4)
    when regexp_replace(p_phone, '[^0-9]', '', 'g') like '964%'
      then '0' || substr(regexp_replace(p_phone, '[^0-9]', '', 'g'), 4)
    else regexp_replace(p_phone, '[^0-9]', '', 'g')
  end
$$;

-- 1) جداول الإدارة الأساسية
create table if not exists public.admin_phones (
  phone text primary key check (phone ~ '^07[0-9]{9}$'),
  created_at timestamptz not null default now()
);
alter table public.admin_phones enable row level security;
revoke all on public.admin_phones from public, anon, authenticated;

create table if not exists public.admin_users (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
revoke all on public.admin_users from public, anon, authenticated;

create table if not exists public.settings (
  key text primary key,
  value text not null
);

-- 2) إن كان رقم المدير محفوظاً في إعدادات التطبيق فسيُنسخ تلقائياً
insert into public.admin_phones(phone)
select public.normalize_iraqi_phone(value)
  from public.settings
 where key = 'admin_phone'
   and public.normalize_iraqi_phone(value) ~ '^07[0-9]{9}$'
on conflict (phone) do nothing;

-- 3) رقمك هنا — أزل التعليق واستبدل 07XXXXXXXXX برقمك الحقيقي (11 رقماً يبدأ 07)
-- insert into public.admin_phones(phone)
-- values ('07XXXXXXXXX')
-- on conflict (phone) do nothing;

-- 4) ترقية أي حساب مسجّل يحمل رقماً من أرقام المديرين
update public.app_profiles p
   set role = 'admin'
 where exists (
   select 1 from public.admin_phones a where a.phone = p.phone
 );

create or replace function public.promote_admin_phone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.app_profiles
     set role = 'admin'
   where phone = new.phone;
  return new;
end
$$;

drop trigger if exists on_admin_phone_added_jaik on public.admin_phones;
create trigger on_admin_phone_added_jaik
  after insert on public.admin_phones
  for each row execute function public.promote_admin_phone();

-- 5) is_app_admin يعترف بالمدير سواء رُبط بمعرّف Auth أو كان رقمه في admin_phones
create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.app_profiles p
     where p.auth_user_id = auth.uid()
       and (
         exists (
           select 1 from public.admin_phones a where a.phone = p.phone
         )
         or exists (
           select 1 from public.admin_users a
            where a.auth_user_id = p.auth_user_id
         )
       )
  )
$$;
revoke all on function public.is_app_admin() from public, anon;
grant execute on function public.is_app_admin() to authenticated;

-- 6) الدالة التي يناديها التطبيق بعد كل دخول/تسجيل:
--    إن كان رقم الحساب في admin_phones أو هو نفسه settings.admin_phone
--    يصبح دوره admin فوراً وتفتح لوحة التحكم كاملة.
create or replace function public.claim_admin_phone()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.app_profiles%rowtype;
  admin_phone text;
begin
  if auth.uid() is null then
    return null;
  end if;

  select * into me
    from public.app_profiles
   where auth_user_id = auth.uid();

  if not found then
    return null;
  end if;

  select public.normalize_iraqi_phone(value)
    into admin_phone
    from public.settings
   where key = 'admin_phone'
   limit 1;

  if admin_phone is not null and admin_phone ~ '^07[0-9]{9}$' then
    insert into public.admin_phones(phone)
    values (admin_phone)
    on conflict (phone) do nothing;
  end if;

  if exists (
    select 1 from public.admin_phones a where a.phone = me.phone
  ) then
    update public.app_profiles
       set role = 'admin'
     where id = me.id
       and role <> 'admin';
    return 'admin';
  end if;

  return me.role;
end
$$;
revoke all on function public.claim_admin_phone() from public, anon;
grant execute on function public.claim_admin_phone() to authenticated;

-- 7) اجعل رقم المدير ظاهراً في إعدادات التطبيق أيضاً
insert into public.settings(key, value)
select 'admin_phone', phone
  from public.admin_phones
 order by created_at
 limit 1
on conflict do nothing;

commit;

-- =====================================================================
--  بعد التنفيذ:
--  1. في Supabase افتح: Authentication → Sign In / Providers → Email
--     وتأكد أن مزوّد Email مفعّل، ثم أوقف «Confirm email».
--     (هذا هو إلغاء التأكيد/OTP نهائياً — لا يُرسل بريد ولا SMS.)
--  2. في التطبيق اضغط «إنشاء حساب» برقمك وكلمة مرور جديدة (أول مرة فقط).
--     التطبيق يستخدم بريداً داخلياً مشتقاً من الرقم (07...@jaik.app) لا تراه.
--  3. بعدها «تسجيل الدخول» بالرقم + كلمة المرور — بدون أي رمز SMS،
--     وستفتح لوحة المدير تلقائياً بسبب وجود الرقم في admin_phones.
--
--  تحقق سريع من أن رقمك مسجّل:
--     select * from public.admin_phones;
--  وتحقق من دور حسابك:
--     select phone, role from public.app_profiles order by id;
-- =====================================================================
