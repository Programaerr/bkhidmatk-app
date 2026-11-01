-- Run only after setup.sql and after creating the administrator's Auth user
-- in Supabase Dashboard -> Authentication -> Users with a password.
-- Phone alone is not proof of identity, so admin access is bound to the Auth ID.

do $$
declare
  admin_phone text := '07XXXXXXXXX';
  admin_auth_id uuid;
begin
  if admin_phone !~ '^07[0-9]{9}$' then
    raise exception 'Replace admin_phone with a valid Iraqi phone number first';
  end if;

  select u.id
    into admin_auth_id
    from auth.users u
   where public.normalize_iraqi_phone(u.phone) = admin_phone;

  if admin_auth_id is null then
    raise exception
      'Create the administrator account in Supabase Auth first, then rerun this script';
  end if;

  insert into public.admin_phones(phone)
  values (admin_phone)
  on conflict (phone) do nothing;

  insert into public.admin_users(auth_user_id)
  values (admin_auth_id)
  on conflict (auth_user_id) do nothing;
end
$$;
