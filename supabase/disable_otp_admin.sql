-- Run after supabase/setup.sql and after creating this account in Supabase Auth.
-- Phone authentication is not used: the app signs in with phone + password via
-- the internal email alias 07717506711@jaik.app.

begin;

do $$
declare
  admin_phone constant text := '07717506711';
  admin_auth_id uuid;
begin
  if admin_phone !~ '^07[0-9]{9}$' then
    raise exception 'admin_phone must be a valid Iraqi mobile number';
  end if;

  select u.id
    into admin_auth_id
    from auth.users u
   where lower(u.email) = lower(admin_phone || '@jaik.app');

  if admin_auth_id is null then
    raise exception
      'Create the administrator in Supabase Authentication -> Users first, '
      'using email % and a password, then rerun this script',
      admin_phone || '@jaik.app';
  end if;

  if not exists (
    select 1 from public.app_profiles p
     where p.auth_user_id = admin_auth_id
  ) then
    raise exception
      'No app profile exists for this Auth user. Run supabase/setup.sql first.';
  end if;

  insert into public.admin_phones(phone)
  values (admin_phone)
  on conflict (phone) do nothing;

  insert into public.admin_users(auth_user_id)
  values (admin_auth_id)
  on conflict (auth_user_id) do nothing;

  insert into public.settings(key, value)
  values ('admin_phone', admin_phone)
  on conflict (key) do update set value = excluded.value;
end
$$;

commit;
