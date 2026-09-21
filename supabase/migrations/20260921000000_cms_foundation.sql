-- Phase 13B-1: CMS authentication, authorization, audit, and private-media foundation.
-- This migration intentionally contains no editorial-content tables or publishing logic.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role text not null default 'contributor'
    check (role in ('admin', 'editor', 'contributor')),
  status text not null default 'active'
    check (status in ('active', 'suspended')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.profiles enable row level security;

-- These no-argument helpers cannot be used to inspect or select another user's role.
-- SECURITY DEFINER avoids an RLS recursion cycle when policies consult profiles.
create function public.cms_is_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and status = 'active'
  );
$$;

create function public.cms_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
      and status = 'active'
  );
$$;

create function public.cms_is_editor_or_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role in ('admin', 'editor')
      and status = 'active'
  );
$$;

revoke all on function public.cms_is_active() from public;
revoke all on function public.cms_is_admin() from public;
revoke all on function public.cms_is_editor_or_admin() from public;
grant execute on function public.cms_is_active() to authenticated;
grant execute on function public.cms_is_admin() to authenticated;
grant execute on function public.cms_is_editor_or_admin() to authenticated;

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

-- Profiles are created only by the auth trigger. Users cannot edit their own
-- profile, including role or status. Admins manage active profile records.
create policy "cms active users read own profile"
  on public.profiles for select to authenticated
  using (public.cms_is_active() and id = (select auth.uid()));

create policy "cms admins read all profiles"
  on public.profiles for select to authenticated
  using (public.cms_is_admin());

create policy "cms admins update profiles"
  on public.profiles for update to authenticated
  using (public.cms_is_admin())
  with check (public.cms_is_admin());

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default timezone('utc', now()),
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_role text check (actor_role is null or actor_role in ('admin', 'editor', 'contributor')),
  event_type text not null,
  outcome text not null check (outcome in ('success', 'failure', 'denied')),
  target_type text,
  target_id text,
  target_revision integer,
  request_id uuid,
  metadata jsonb not null default '{}'::jsonb
);

alter table public.audit_events enable row level security;

-- Audit writes are intentionally server-controlled. No authenticated client
-- INSERT policy exists in this foundation migration.
create policy "cms users read own audit events"
  on public.audit_events for select to authenticated
  using (public.cms_is_active() and actor_user_id = (select auth.uid()));

create policy "cms editors read editorial audit events"
  on public.audit_events for select to authenticated
  using (
    public.cms_is_editor_or_admin()
    and target_type in ('news_event', 'media_asset')
  );

create policy "cms admins read all audit events"
  on public.audit_events for select to authenticated
  using (public.cms_is_admin());

-- Private originals for future CMS Media Asset records. The media-record table
-- is intentionally deferred; ownership is therefore scoped to the first path
-- segment (the authenticated user's UUID) until that record exists.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'cms-media-private',
  'cms-media-private',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "cms users read own private media namespace"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'cms-media-private'
    and public.cms_is_active()
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "cms editorial users read private media"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'cms-media-private'
    and public.cms_is_editor_or_admin()
  );

create policy "cms users upload to own private media namespace"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'cms-media-private'
    and public.cms_is_active()
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "cms editorial users upload private media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'cms-media-private'
    and public.cms_is_editor_or_admin()
  );

create policy "cms editorial users update private media"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'cms-media-private'
    and public.cms_is_editor_or_admin()
  )
  with check (
    bucket_id = 'cms-media-private'
    and public.cms_is_editor_or_admin()
  );

create policy "cms editorial users delete private media"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'cms-media-private'
    and public.cms_is_editor_or_admin()
  );
