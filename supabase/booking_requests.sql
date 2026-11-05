-- طلبات الحجز: الزبون -> الإدارة + الحرفي -> موافقة الإدارة -> إرسال الحرفي -> التنفيذ.
--
-- شغّل هذا الملف في Supabase (SQL Editor) بعد setup.sql، ويمكن تشغيله أكثر من مرة.
--
-- لا حاجة إلى جدول منفصل للطلبات: جدول bookings نفسه هو الطلب، وكل ما يلزم هو
--   * أعمدة جديدة في bookings (رد الحرفي، وقت الموافقة، وقت الإرسال، ملاحظة الإدارة)،
--   * حالة جديدة dispatched «تم إرسال الحرفي»،
--   * دوال تضبط من يستطيع تغيير ماذا، وتُرسل إشعاراً لكل طرف (جدول app_notifications).
--
-- ربط الحرفي بحسابه: رقم الحرفي في جدول workers (يضيفه المدير من «الخدمات > الفنيون»)
-- يجب أن يطابق رقم حسابه المسجّل بالتطبيق (الحساب الذي صار «حرفي» بالتوظيف).

-- 1) أعمدة الطلب وحالاته ------------------------------------------------------------
alter table public.bookings
  add column if not exists worker_response text not null default 'pending',
  add column if not exists worker_responded_at timestamptz,
  add column if not exists confirmed_at timestamptz,
  add column if not exists dispatched_at timestamptz,
  add column if not exists admin_note text;

alter table public.bookings drop constraint if exists bookings_status_check;
alter table public.bookings add constraint bookings_status_check
  check (status in ('pending', 'confirmed', 'dispatched', 'in_progress', 'completed', 'cancelled'));

alter table public.bookings drop constraint if exists bookings_worker_response_check;
alter table public.bookings add constraint bookings_worker_response_check
  check (worker_response in ('pending', 'accepted', 'declined'));

create index if not exists bookings_worker_status_idx
  on public.bookings(worker_id, status);
create index if not exists bookings_status_created_idx
  on public.bookings(status, created_at desc);

-- 2) من هو الحرفي الذي سجّل دخوله؟ (مطابقة الرقم) ------------------------------------
create or replace function public.current_worker_id()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select w.id
    from public.workers w
    join public.app_profiles p
      on public.normalize_iraqi_phone(w.phone) = p.phone
   where p.auth_user_id = auth.uid()
     and p.role = 'worker'
   limit 1
$$;

-- 3) إشعار لحساب واحد (داخلي، لا تستدعيه التطبيقات) ----------------------------------
create or replace function public.notify_profile(
  p_recipient bigint,
  p_title text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_recipient is null or auth.uid() is null then return; end if;
  insert into public.app_notifications(recipient_id, sender_auth_id, title, body)
  values (p_recipient, auth.uid(), left(p_title, 120), left(p_body, 2000));
end
$$;

-- حساب الحرفي المرتبط بصف workers.
create or replace function public.worker_profile_id(p_worker_id bigint)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
    from public.workers w
    join public.app_profiles p
      on public.normalize_iraqi_phone(w.phone) = p.phone
   where w.id = p_worker_id
     and p.role = 'worker'
   limit 1
$$;

-- إشعار لكل المدراء.
create or replace function public.notify_admins(p_title text, p_body text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  admin_profile bigint;
begin
  for admin_profile in
    select p.id
      from public.app_profiles p
      join public.admin_users a on a.auth_user_id = p.auth_user_id
  loop
    perform public.notify_profile(admin_profile, p_title, p_body);
  end loop;
end
$$;

-- 4) إنشاء الطلب: تثبيت قيمه، ثم إشعار الإدارة والحرفي ---------------------------------
create or replace function public.prepare_booking()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  service_price numeric(12,2);
  service_category bigint;
  service_active boolean;
begin
  select s.price, s.category_id, s.active
    into service_price, service_category, service_active
    from public.services s
   where s.id = new.service_id;
  if not found or not service_active then
    raise exception 'Service not found or unavailable';
  end if;
  if new.worker_id is not null and not exists (
    select 1 from public.workers w
     where w.id = new.worker_id
       and w.category_id = service_category
       and w.available
  ) then
    raise exception 'Worker is unavailable for this service';
  end if;
  new.total := service_price;
  new.status := 'pending';
  new.rating := null;
  new.review := null;
  new.worker_response := 'pending';
  new.worker_responded_at := null;
  new.confirmed_at := null;
  new.dispatched_at := null;
  new.admin_note := null;
  return new;
end
$$;

create or replace function public.notify_new_booking()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  customer_name text;
  service_title text;
  worker_profile bigint;
begin
  select p.name into customer_name
    from public.app_profiles p where p.id = new.customer_id;
  select s.title into service_title
    from public.services s where s.id = new.service_id;

  perform public.notify_admins(
    'طلب حجز جديد',
    format('الزبون %s طلب «%s» رقم الحجز #%s وينتظر موافقتك.',
           coalesce(customer_name, ''), coalesce(service_title, ''), new.id)
  );

  if new.worker_id is not null then
    worker_profile := public.worker_profile_id(new.worker_id);
    perform public.notify_profile(
      worker_profile,
      'طلب حجز جديد باسمك',
      format('الزبون %s طلب «%s» في %s. بانتظار موافقة الإدارة.',
             coalesce(customer_name, ''), coalesce(service_title, ''),
             to_char(new.scheduled_at at time zone 'Asia/Baghdad', 'YYYY/MM/DD'))
    );
  end if;
  return new;
end
$$;

drop trigger if exists prepare_booking_before_insert on public.bookings;
create trigger prepare_booking_before_insert
  before insert on public.bookings
  for each row execute function public.prepare_booking();

drop trigger if exists notify_new_booking_after_insert on public.bookings;
create trigger notify_new_booking_after_insert
  after insert on public.bookings
  for each row execute function public.notify_new_booking();

-- 5) تغيير حالة الحجز ----------------------------------------------------------------
-- المدير: أي حالة (الموافقة confirmed، الإرسال dispatched، التنفيذ، الإكمال، الإلغاء).
-- الزبون: يلغي حجزه هو فقط، وما دام بانتظار الموافقة أو موافَقاً عليه.
create or replace function public.update_booking_status(p_booking_id bigint, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  booking_row public.bookings%rowtype;
  is_admin boolean := public.is_app_admin();
  service_title text;
  worker_profile bigint;
begin
  if p_status not in ('pending', 'confirmed', 'dispatched', 'in_progress', 'completed', 'cancelled') then
    raise exception 'Invalid booking status';
  end if;
  select * into booking_row from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;

  if not is_admin then
    if booking_row.customer_id is distinct from public.current_app_profile_id()
       or p_status <> 'cancelled'
       or booking_row.status not in ('pending', 'confirmed') then
      raise exception 'Only administrators can update bookings'
        using errcode = '42501';
    end if;
  end if;

  if p_status = 'dispatched' and booking_row.worker_id is null then
    raise exception 'Assign a craftsman before sending him';
  end if;

  update public.bookings
     set status = p_status,
         confirmed_at = case when p_status = 'confirmed' then now() else confirmed_at end,
         dispatched_at = case when p_status = 'dispatched' then now() else dispatched_at end
   where id = p_booking_id;

  if p_status = 'completed' and booking_row.status <> 'completed'
     and booking_row.worker_id is not null then
    update public.workers set jobs_done = jobs_done + 1 where id = booking_row.worker_id;
  end if;

  if p_status <> booking_row.status then
    select s.title into service_title
      from public.services s where s.id = booking_row.service_id;
    worker_profile := public.worker_profile_id(booking_row.worker_id);

    if p_status = 'confirmed' then
      perform public.notify_profile(booking_row.customer_id, 'تمت الموافقة على حجزك',
        format('وافقت الإدارة على حجز «%s» رقم #%s، وسنرسل الحرفي إليك في الموعد.', service_title, p_booking_id));
      perform public.notify_profile(worker_profile, 'حجز موافَق عليه',
        format('وافقت الإدارة على الحجز #%s «%s»، وسنتواصل معك لإرسالك.', p_booking_id, service_title));
    elsif p_status = 'dispatched' then
      perform public.notify_profile(booking_row.customer_id, 'الحرفي في الطريق إليك',
        format('تم إرسال الحرفي لتنفيذ «%s» رقم #%s.', service_title, p_booking_id));
      perform public.notify_profile(worker_profile, 'تم إرسالك إلى الزبون',
        format('اذهب الآن لتنفيذ الحجز #%s «%s». ستجد العنوان ورقم الزبون في طلباتك.', p_booking_id, service_title));
    elsif p_status = 'cancelled' then
      if is_admin then
        perform public.notify_profile(booking_row.customer_id, 'أُلغي حجزك',
          format('أُلغي حجز «%s» رقم #%s.', service_title, p_booking_id));
      else
        perform public.notify_admins('ألغى الزبون حجزه',
          format('أُلغي الحجز #%s «%s» من الزبون.', p_booking_id, service_title));
      end if;
      perform public.notify_profile(worker_profile, 'أُلغي الحجز',
        format('أُلغي الحجز #%s «%s».', p_booking_id, service_title));
    elsif p_status = 'completed' then
      perform public.notify_profile(booking_row.customer_id, 'اكتمل حجزك',
        format('اكتمل حجز «%s». يمكنك الآن تقييم الحرفي.', service_title));
    end if;
  end if;
end
$$;

-- 6) تعيين حرفي (أو تغييره): يعود رده إلى «بانتظار» ويُخطَر الحرفي الجديد ---------------
create or replace function public.assign_booking_worker(p_booking_id bigint, p_worker_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  booking_row public.bookings%rowtype;
  service_title text;
begin
  if not public.is_app_admin() then
    raise exception 'Only administrators can assign craftsmen'
      using errcode = '42501';
  end if;
  select * into booking_row from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;

  update public.bookings
     set worker_id = p_worker_id,
         worker_response = 'pending',
         worker_responded_at = null
   where id = p_booking_id;

  if p_worker_id is not null then
    select s.title into service_title
      from public.services s where s.id = booking_row.service_id;
    perform public.notify_profile(
      public.worker_profile_id(p_worker_id),
      'حجز جديد باسمك',
      format('عيّنتك الإدارة على الحجز #%s «%s». أكّد قبولك من طلباتك.', p_booking_id, service_title)
    );
  end if;
end
$$;

-- 7) الحرفي: طلباته، وبياناتها بقدر ما تسمح به الإدارة ---------------------------------
-- العنوان ورقم الزبون لا يظهران له إلا بعد أن ترسله الإدارة (dispatched فما بعد).
create or replace function public.worker_bookings()
returns table (
  id bigint,
  worker_id bigint,
  status text,
  worker_response text,
  scheduled_at timestamptz,
  slot text,
  notes text,
  total numeric,
  created_at timestamptz,
  dispatched_at timestamptz,
  service_title text,
  customer_name text,
  customer_phone text,
  address text
)
language sql
stable
security definer
set search_path = ''
as $$
  select b.id, b.worker_id, b.status, b.worker_response, b.scheduled_at, b.slot,
         b.notes, b.total, b.created_at, b.dispatched_at,
         s.title, c.name,
         case when b.status in ('dispatched', 'in_progress', 'completed') then c.phone end,
         case when b.status in ('dispatched', 'in_progress', 'completed') then b.address else '' end
    from public.bookings b
    join public.services s on s.id = b.service_id
    join public.app_profiles c on c.id = b.customer_id
   where b.worker_id = public.current_worker_id()
   order by b.created_at desc
$$;

-- الحرفي يؤكد أو يعتذر، ما دام الحجز لم يُرسَل بعد.
create or replace function public.worker_respond_booking(p_booking_id bigint, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  my_worker bigint := public.current_worker_id();
  booking_row public.bookings%rowtype;
  worker_name text;
  service_title text;
begin
  if my_worker is null then
    raise exception 'This account is not linked to a craftsman'
      using errcode = '42501';
  end if;
  select * into booking_row from public.bookings
   where id = p_booking_id and worker_id = my_worker for update;
  if not found then raise exception 'Booking not found'; end if;
  if booking_row.status not in ('pending', 'confirmed') then
    raise exception 'This booking can no longer be answered';
  end if;

  update public.bookings
     set worker_response = case when p_accept then 'accepted' else 'declined' end,
         worker_responded_at = now()
   where id = p_booking_id;

  select w.name into worker_name from public.workers w where w.id = my_worker;
  select s.title into service_title from public.services s where s.id = booking_row.service_id;
  perform public.notify_admins(
    case when p_accept then 'الحرفي وافق على الحجز' else 'الحرفي اعتذر عن الحجز' end,
    format('%s %s الحجز #%s «%s».', worker_name,
           case when p_accept then 'أكّد' else 'اعتذر عن' end, p_booking_id, service_title)
  );
end
$$;

-- 8) الصلاحيات ----------------------------------------------------------------------
revoke all on function public.current_worker_id() from public, anon;
grant execute on function public.current_worker_id() to authenticated;
revoke all on function public.notify_profile(bigint, text, text) from public, anon, authenticated;
revoke all on function public.worker_profile_id(bigint) from public, anon, authenticated;
revoke all on function public.notify_admins(text, text) from public, anon, authenticated;
revoke all on function public.prepare_booking() from public, anon;
revoke all on function public.notify_new_booking() from public, anon;
revoke all on function public.update_booking_status(bigint, text) from public, anon;
grant execute on function public.update_booking_status(bigint, text) to authenticated;
revoke all on function public.assign_booking_worker(bigint, bigint) from public, anon;
grant execute on function public.assign_booking_worker(bigint, bigint) to authenticated;
revoke all on function public.worker_bookings() from public, anon;
grant execute on function public.worker_bookings() to authenticated;
revoke all on function public.worker_respond_booking(bigint, boolean) from public, anon;
grant execute on function public.worker_respond_booking(bigint, boolean) to authenticated;

-- الحرفي لا يقرأ جدول bookings مباشرة (فيه عناوين الزبائن)، بل عبر worker_bookings() فقط.
-- سياسات bookings في setup.sql تبقى كما هي: الزبون يقرأ حجوزاته، والمدير كل شيء.
