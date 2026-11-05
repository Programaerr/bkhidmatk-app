-- السعر بالاتفاق: لا سعر للخدمة، والمدير يحدده لكل حجز بعد الاتفاق مع الزبون،
-- فيُضاف إلى وصل الزبون ليدفعه لاحقاً.
--
-- شغّل هذا الملف في Supabase (SQL Editor) بعد setup.sql و booking_requests.sql و booking_edits.sql.
-- يمكن تشغيله أكثر من مرة. لا جداول جديدة: bookings.total هو السعر المتفق عليه (0 = لم يُحدد بعد)،
-- وجدول receipts هو الوصل الذي ينشئه المدير عند تحديد السعر (paid = false حتى يُدفع).

-- 1) الخدمة بلا سعر إلزامي ----------------------------------------------------------------
alter table public.services alter column price set default 0;

-- 2) الحجز الجديد يبدأ بلا سعر ---------------------------------------------------------------
create or replace function public.prepare_booking()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  service_category bigint;
  service_active boolean;
begin
  select s.category_id, s.active
    into service_category, service_active
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
  new.total := 0;
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

-- 3) تحديد السعر (المدير فقط) --------------------------------------------------------------
-- يضع السعر على الحجز، وينشئ وصله إن لم يكن له وصل، أو يحدّث مبلغه ما دام لم يُدفع.
-- الوصل المدفوع لا يتغير مبلغه.
create or replace function public.set_booking_price(p_booking_id bigint, p_amount numeric)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  booking_row public.bookings%rowtype;
  receipt_row public.receipts%rowtype;
  has_receipt boolean;
  service_title text;
begin
  if not public.is_app_admin() then
    raise exception 'Only administrators can set prices'
      using errcode = '42501';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'The price must be greater than zero';
  end if;
  select * into booking_row from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if booking_row.status = 'cancelled' then
    raise exception 'A cancelled booking has no price';
  end if;

  select * into receipt_row from public.receipts
   where booking_id = p_booking_id order by id limit 1 for update;
  has_receipt := found;
  if has_receipt and receipt_row.paid then
    raise exception 'The receipt is already paid';
  end if;

  update public.bookings set total = p_amount where id = p_booking_id;

  if has_receipt then
    update public.receipts set amount = p_amount where id = receipt_row.id;
  else
    insert into public.receipts(invoice_no, booking_id, user_id, title, amount, method, paid)
    values (
      'BKD-' || extract(year from now())::int || '-' || lpad(p_booking_id::text, 5, '0'),
      p_booking_id, booking_row.customer_id, 'وصل دفع خدمة', p_amount, 'cash', false
    );
  end if;

  select s.title into service_title from public.services s where s.id = booking_row.service_id;
  perform public.notify_profile(booking_row.customer_id, 'تم الاتفاق على سعر حجزك',
    format('سعر حجز «%s» رقم #%s هو %s د.ع، وأُضيف إلى وصلك لتدفعه لاحقاً.',
           service_title, p_booking_id, to_char(p_amount, 'FM999G999G999')));
end
$$;

-- 4) الصلاحيات ----------------------------------------------------------------------
revoke all on function public.prepare_booking() from public, anon;
revoke all on function public.set_booking_price(bigint, numeric) from public, anon;
grant execute on function public.set_booking_price(bigint, numeric) to authenticated;
