-- الدخول كضيف: من يدخل بلا حساب يتصفح الأقسام والحرفيين والخدمات فقط.
-- الأعمال والرسائل والحجوزات والحسابات تبقى لأصحاب الحسابات كما هي.
-- شغّل هذا الملف مرة واحدة في Supabase ← SQL Editor بعد setup.sql.

grant select on public.categories, public.services to anon;
grant select (id, name, specialty, category_id, rating, jobs_done, bio, avatar, available, city)
  on public.workers to anon;

drop policy if exists "categories_read_guest" on public.categories;
create policy "categories_read_guest" on public.categories
  for select to anon using (true);

drop policy if exists "workers_read_guest" on public.workers;
create policy "workers_read_guest" on public.workers
  for select to anon using (true);

drop policy if exists "services_read_guest" on public.services;
create policy "services_read_guest" on public.services
  for select to anon using (active);
