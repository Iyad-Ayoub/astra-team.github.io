-- Phase 13B-3 / 13C-1: News/Event drafts only. Publishing is intentionally deferred.

create table public.cms_news (
  id uuid primary key default gen_random_uuid(),
  title text not null check (
    char_length(btrim(title)) between 1 and 180
    and title not like '%{{%'
    and title not like '%{%'
    and title !~* '<[[:space:]]*script([[:space:]>])'
    and title !~* '[[:space:]]on[a-z]+[[:space:]]*='
  ),
  type text not null check (type in ('news', 'event', 'award', 'project', 'open-source', 'team', 'collaboration', 'demo')),
  summary text not null check (
    char_length(btrim(summary)) between 1 and 600
    and summary not like '%{{%'
    and summary not like '%{%'
    and summary !~* '<[[:space:]]*script([[:space:]>])'
    and summary !~* '[[:space:]]on[a-z]+[[:space:]]*='
  ),
  body text not null check (
    char_length(btrim(body)) between 1 and 30000
    and body not like '%{{%'
    and body not like '%{%'
    and body !~* '<[[:space:]]*script([[:space:]>])'
    and body !~* '[[:space:]]on[a-z]+[[:space:]]*='
  ),
  content_date date not null,
  event_date date,
  end_date date,
  location text check (location is null or char_length(location) <= 160),
  external_url text check (external_url is null or external_url ~ '^https?://[^[:space:]<>]+$'),
  related_project_id uuid,
  related_output_id uuid,
  featured boolean not null default false,
  homepage boolean not null default false,
  media_asset_id uuid,
  status text not null default 'draft' check (status in ('draft', 'in_review')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  reviewed_by uuid references auth.users(id) on delete set null,
  published_at timestamptz,
  revision integer not null default 1 check (revision >= 1),
  export_reference text,
  check (type <> 'event' or event_date is not null),
  check (end_date is null or event_date is null or end_date >= event_date)
);

alter table public.cms_news enable row level security;

-- Do not accept client-controlled system fields. New records always begin as
-- the authenticated user's draft; immutable/system fields survive edits.
create function public.cms_news_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'authenticated user required';
  end if;
  new.created_by = (select auth.uid());
  new.status = 'draft';
  new.reviewed_by = null;
  new.published_at = null;
  new.revision = 1;
  new.export_reference = null;
  new.created_at = timezone('utc', now());
  new.updated_at = new.created_at;
  return new;
end;
$$;

create function public.cms_news_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.id = old.id;
  new.created_by = old.created_by;
  new.created_at = old.created_at;
  new.reviewed_by = old.reviewed_by;
  new.published_at = old.published_at;
  new.export_reference = old.export_reference;
  new.updated_at = timezone('utc', now());
  new.revision = old.revision + 1;
  if new.status not in ('draft', 'in_review') then
    raise exception 'unsupported CMS news status';
  end if;
  return new;
end;
$$;

-- Only the trigger can write audit rows. Its event vocabulary is fixed and
-- derived from the row transition rather than supplied by a browser client.
create function public.cms_audit_news_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_name text;
  current_role text;
begin
  if tg_op = 'INSERT' then
    event_name = 'news_created';
  elsif old.status = 'draft' and new.status = 'in_review' then
    event_name = 'news_submitted_for_review';
  else
    event_name = 'news_updated';
  end if;

  select role into current_role
  from public.profiles
  where id = (select auth.uid());

  insert into public.audit_events (
    actor_user_id, actor_role, event_type, outcome, target_type, target_id,
    target_revision, metadata
  ) values (
    (select auth.uid()), current_role, event_name, 'success', 'news_event',
    new.id::text, new.revision, jsonb_build_object('status', new.status)
  );
  return new;
end;
$$;

revoke all on function public.cms_news_before_insert() from public;
revoke all on function public.cms_news_before_update() from public;
revoke all on function public.cms_audit_news_change() from public;

create trigger cms_news_before_insert
  before insert on public.cms_news
  for each row execute procedure public.cms_news_before_insert();

create trigger cms_news_before_update
  before update on public.cms_news
  for each row execute procedure public.cms_news_before_update();

create trigger cms_news_audit_change
  after insert or update on public.cms_news
  for each row execute procedure public.cms_audit_news_change();

create policy "cms users read own news drafts"
  on public.cms_news for select to authenticated
  using (public.cms_is_active() and created_by = (select auth.uid()));

create policy "cms editorial users read all news drafts"
  on public.cms_news for select to authenticated
  using (public.cms_is_editor_or_admin());

create policy "cms users create own news drafts"
  on public.cms_news for insert to authenticated
  with check (public.cms_is_active() and created_by = (select auth.uid()) and status = 'draft');

create policy "cms users update own news drafts"
  on public.cms_news for update to authenticated
  using (public.cms_is_active() and created_by = (select auth.uid()) and status = 'draft')
  with check (
    public.cms_is_active()
    and created_by = (select auth.uid())
    and status in ('draft', 'in_review')
  );

create policy "cms editorial users update all news drafts"
  on public.cms_news for update to authenticated
  using (public.cms_is_editor_or_admin())
  with check (public.cms_is_editor_or_admin() and status in ('draft', 'in_review'));

-- Explicit grants are needed because automatic Data API privileges are off.
revoke all on public.cms_news from anon;
revoke all on public.cms_news from authenticated;
grant select on public.cms_news to authenticated;
grant insert (title, type, summary, body, content_date, event_date, end_date,
              location, external_url, related_project_id, related_output_id,
              featured, homepage, media_asset_id) on public.cms_news to authenticated;
grant update (title, type, summary, body, content_date, event_date, end_date,
              location, external_url, related_project_id, related_output_id,
              featured, homepage, media_asset_id, status) on public.cms_news to authenticated;
