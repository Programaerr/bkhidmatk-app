-- Jaik: the eighteen sections of the customer home page, for a project that is already running.
-- Run this file once in Supabase SQL Editor. Running it again changes nothing.
-- It deletes nothing, and every service and worker stays linked to its section.

begin;

-- The old sections take their new names, so their services and workers stay with them.
update public.categories as section
set name = v.new_name
from (values
  ('تكييف', 'سبالت'),
  ('صباغة', 'صباغ'),
  ('تنظيف', 'التنظيف'),
  ('تصليح غسالات', 'اجهزة المنزل'),
  ('نجارة', 'نجار')
) as v(old_name, new_name)
where section.name = v.old_name
  and not exists (select 1 from public.categories c where c.name = v.new_name);

-- The eighteen sections in their order. Sections an administrator added stay after them.
with sections(name, icon, color, sort_order) as (values
  ('سبالت', 'ac_unit', 4282339765, 0),
  ('كهرباء', 'electrical_services', 4294902023, 1),
  ('سباكة', 'plumbing', 4278236368, 2),
  ('صباغ', 'format_paint', 4287357184, 3),
  ('التنظيف', 'cleaning_services', 4288394176, 4),
  ('اجهزة المنزل', 'kitchen', 4278453504, 5),
  ('مجاري', 'water_damage', 4284513675, 6),
  ('نجار', 'carpenter', 4285877864, 7),
  ('حداد', 'hardware', 4283723386, 8),
  ('ديكورات', 'chair_alt', 4293209333, 9),
  ('تركيب كامرات', 'videocam', 4284955319, 10),
  ('حدائق', 'yard', 4283215696, 11),
  ('طاقة شمسية', 'solar_power', 4294940672, 12),
  ('عامل', 'engineering', 4288584996, 13),
  ('ابواب و شبابيك', 'window', 4278228616, 14),
  ('نقل الاثاث', 'local_shipping', 4294924066, 15),
  ('شد و تركيب الاثاث', 'handyman', 4288776319, 16),
  ('غسيل سيارات', 'local_car_wash', 4280391411, 17)
), saved as (
  insert into public.categories(name, icon, color, sort_order)
  select name, icon, color, sort_order from sections
  on conflict (name) do update
    set icon = excluded.icon, sort_order = excluded.sort_order
  returning id
)
update public.categories
set sort_order = greatest(sort_order, 18)
where id not in (select id from saved);

commit;
