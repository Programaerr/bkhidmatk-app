-- تعديل الإدارة للحجز + موافقة الزبون عليه قبل إرسال الحرفي.
--
-- شغّل هذا الملف في Supabase (SQL Editor) بعد setup.sql و booking_requests.sql. يمكن تشغيله أكثر من مرة.
--
-- الجديد في جدول bookings:
--   customer_ack     : حال موافقة الزبون على تعديل الإدارة: none (لم يُعدَّل) | pending | approved | declined
--   admin_edited_at  : متى عدّلت الإدارة الحجز آخر مرة
--   edit_summary     : ما الذي تغيّر (الموعد، الوقت، العنوان، الملاحظات)
--   admin_note       : رسالة الإدارة للزبون مع التعديل (العمود موجود من booking_requests.sql)

-- 1) الأعمدة ------------------------------------------------------------------------
alter table public.bookings
  add column if not exists customer_ack text not null default 'none',
  add column if not exists admin_edited_at timestamptz,
  add column if not exists edit_summary text;

alter table public.bookings drop constraint if exists bookings_customer_ack_check;
alter table public.bookings add constraint bookings_customer_ack_check
  check (customer_ack in ('none', 'pending', 'approved', 'declined'));

-- 2) الإدخال: الزبون لا يضع قيم التعديل بنفسه -------------------------------------------
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
  new.customer_ack := 'none';
  new.admin_edited_at := null;
  new.edit_summary := null;
  return new;
end
$$;

-- 3) تعديل الحجز (المدير فقط) ----------------------------------------------------------
-- يغيّر الموعد والوقت والعنوان والملاحظات، ويسجّل ما تغيّر ووقت التعديل، ويطلب موافقة الزبون.
-- إن تغيّر الموعد أو الوقت يعود رد الحرفي إلى «بانتظار» ليؤكد من جديد.
create or replace function public.admin_update_booking(
  p_booking_id bigint,
  p_scheduled_at timestamptz,
  p_slot text,
  p_address text,
  p_notes text,
  p_admin_note text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_row public.bookings%rowtype;
  summary text := '';
  schedule_changed boolean;
  service_title text;
  tz text := 'Asia/Baghdad';
begin
  if not public.is_app_admin() then
    raise exception 'Only administrators can edit bookings'
      using errcode = '42501';
  end if;
  select * into old_row from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if old_row.status in ('completed', 'cancelled') then
    raise exception 'A finished booking cannot be edited';
  end if;
  if nullif(trim(p_address), '') is null or nullif(trim(p_slot), '') is null then
    raise exception 'Address and time are required';
  end if;

  schedule_changed :=
    (p_scheduled_at at time zone tz)::date <> (old_row.scheduled_at at time zone tz)::date
    or p_slot <> old_row.slot;

  if (p_scheduled_at at time zone tz)::date <> (old_row.scheduled_at at time zone tz)::date then
    summary := summary || format('الموعد: %s ← %s. ',
      to_char(old_row.scheduled_at at time zone tz, 'YYYY/MM/DD'),
      to_char(p_scheduled_at at time zone tz, 'YYYY/MM/DD'));
  end if;
  if p_slot <> old_row.slot then
    summary := summary || format('الوقت: %s ← %s. ', old_row.slot, p_slot);
  end if;
  if trim(p_address) <> old_row.address then
    summary := summary || 'العنوان تغيّر. ';
  end if;
  if coalesce(trim(p_notes), '') <> coalesce(old_row.notes, '') then
    summary := summary || 'الملاحظات تغيّرت. ';
  end if;
  if summary = '' and coalesce(trim(p_admin_note), '') = coalesce(old_row.admin_note, '') then
    return; -- لا شيء تغيّر
  end if;

  update public.bookings
     set scheduled_at = p_scheduled_at,
         slot = trim(p_slot),
         address = trim(p_address),
         notes = nullif(trim(p_notes), ''),
         admin_note = nullif(trim(p_admin_note), ''),
         admin_edited_at = now(),
         edit_summary = nullif(trim(summary), ''),
         customer_ack = 'pending',
         worker_response = case
           when schedule_changed and worker_id is not null then 'pending'
           else worker_response
         end,
         worker_responded_at = case
           when schedule_changed and worker_id is not null then null
           else worker_responded_at
         end
   where id = p_booking_id;

  select s.title into service_title
    from public.services s where s.id = old_row.service_id;
  perform public.notify_profile(old_row.customer_id, 'عدّلت الإدارة حجزك',
    format('تم تعديل حجز «%s» رقم #%s. %s افتح الحجز ووافق على التعديل.',
           service_title, p_booking_id, trim(summary)));
  if old_row.worker_id is not null then
    perform public.notify_profile(public.worker_profile_id(old_row.worker_id), 'تعديل على حجز باسمك',
      format('عدّلت الإدارة الحجز #%s «%s». %s', p_booking_id, service_title, trim(summary)));
  end if;
end
$$;

-- 4) الزبون يوافق على التعديل أو يرفضه ---------------------------------------------------
create or replace function public.customer_respond_booking_edit(p_booking_id bigint, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  booking_row public.bookings%rowtype;
  service_title text;
begin
  select * into booking_row from public.bookings
   where id = p_booking_id
     and customer_id = public.current_app_profile_id()
   for update;
  if not found then raise exception 'Booking not found'; end if;
  if booking_row.customer_ack <> 'pending' then
    raise exception 'There is no edit waiting for your answer';
  end if;

  update public.bookings
     set customer_ack = case when p_approve then 'approved' else 'declined' end
   where id = p_booking_id;

  select s.title into service_title from public.services s where s.id = booking_row.service_id;
  perform public.notify_admins(
    case when p_approve then 'الزبون وافق على التعديل' else 'الزبون رفض التعديل' end,
    format('الحجز #%s «%s»: %s', p_booking_id, service_title,
           case when p_approve then 'وافق الزبون ويمكنك إرسال الحرفي.'
                else 'رفض الزبون التعديل، تواصل معه أو عدّل الحجز من جديد.' end)
  );
end
$$;

-- 5) تغيير الحالة: لا يُرسَل الحرفي والتعديل بانتظار موافقة الزبون ----------------------------
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

  if p_status = 'dispatched' then
    if booking_row.worker_id is null then
      raise exception 'Assign a craftsman before sending him';
    end if;
    if booking_row.customer_ack = 'pending' then
      raise exception 'The customer has not approved the edit yet';
    end if;
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

-- 6) الصلاحيات ----------------------------------------------------------------------
revoke all on function public.prepare_booking() from public, anon;
revoke all on function public.admin_update_booking(bigint, timestamptz, text, text, text, text)
  from public, anon;
grant execute on function public.admin_update_booking(bigint, timestamptz, text, text, text, text)
  to authenticated;
revoke all on function public.customer_respond_booking_edit(bigint, boolean) from public, anon;
grant execute on function public.customer_respond_booking_edit(bigint, boolean) to authenticated;
revoke all on function public.update_booking_status(bigint, text) from public, anon;
grant execute on function public.update_booking_status(bigint, text) to authenticated;
