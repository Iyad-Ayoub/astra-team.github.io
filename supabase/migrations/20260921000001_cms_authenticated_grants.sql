-- Phase 13B-2: explicit Data API grants for RLS-protected CMS tables.
-- The project disables automatic privileges for new exposed tables. Grants let
-- authenticated requests reach these tables; existing RLS policies still
-- decide which rows and updates are permitted.

revoke insert, delete on public.profiles from authenticated;
revoke insert, update, delete on public.audit_events from authenticated;

grant select, update on public.profiles to authenticated;
grant select on public.audit_events to authenticated;
