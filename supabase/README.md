# ASTRA CMS Supabase foundation

Phase 13B establishes the authentication, authorization, audit, private
media-storage foundation, and the first static ASTRA CMS control-panel shell.
It does not add content tables, publishing/export code, a GitHub App, or public
website content changes.

## Local setup

1. Install the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
   and Docker, then authenticate the CLI against the intended local or hosted
   project.
2. Copy `.env.example` to an untracked local environment file and provide only
   `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` to a future browser client.
3. Apply migrations with the Supabase CLI against a disposable local project
   first, then through the approved hosted-project migration procedure:

   ```sh
   supabase start
   supabase db reset
   ```

   For a linked hosted project, use the team's approved review process and:

   ```sh
   supabase db push
   ```

Do not use `db push` against production without reviewing the migration and
confirming the target project.

## Required Auth settings

- Disable public sign-up. Accounts are created by an Admin-controlled invitation
  process.
- Require email confirmation before CMS access.
- Require TOTP MFA for Admins in the future control panel and for
  security-sensitive server actions.
- Keep the Supabase Auth Site URL and permitted redirect URLs restricted to the
  control-panel origins.

The `on_auth_user_created` trigger creates a `public.profiles` row with the
database-enforced default role `contributor`. It reads only `display_name` from
user metadata. Role and status never come from client-controlled metadata.
Admin-controlled server operations may promote a user or suspend an account.

For first-time setup, invite the designated institutional administrator, let
them complete email verification, then promote that profile through the
protected Supabase administrative procedure or SQL Editor. Do not expose a
browser path for initial role bootstrap; record the promotion in the audit
process once audit writes are added in the server layer.

## Roles and RLS

Roles are fixed: `admin`, `editor`, and `contributor`. Account status is either
`active` or `suspended`. `profiles` and `audit_events` have RLS enabled.

The project has automatic Data API privileges for new tables disabled. Migration
`20260921000001_cms_authenticated_grants.sql` explicitly grants authenticated
users `SELECT, UPDATE` on `profiles` and `SELECT` on `audit_events`; it revokes
all client insert/delete access and audit updates. These grants do not bypass
RLS: normal users still cannot update any profile, and only the existing Admin
RLS policy permits profile updates.

- Active users can read only their profile.
- Users receive no direct profile update policy, so they cannot self-promote or
  reactivate themselves.
- Active Admins can read and update profiles.
- Audit records are append-only to normal authenticated users: no client insert,
  update, or delete policy exists.
- Contributors can read their own audit events; Editors and Admins can read
  editorial events; Admins can read all events.
- A suspended user fails the helper checks used by all CMS policies.

The no-argument role helpers use `SECURITY DEFINER` only to avoid RLS recursion.
They lock `search_path`, look up only the current authenticated user, and are
executable only by `authenticated` users.

## Private media bucket

`cms-media-private` is private, accepts only JPEG, PNG, and WebP, and has a
10 MB maximum object size. Until the Media Asset table exists, a Contributor is
limited to an object namespace beginning with their authenticated UUID. Editors
and Admins can read, upload, update, and delete across the bucket. Contributors
cannot update or delete objects after upload; ownership, lifecycle, checksum,
and reference-aware cleanup are deferred to the Media Asset implementation.

## Secrets

The publishable key may be present in a browser client only with RLS enabled.
Supabase secret/service credentials and GitHub publishing credentials are
server-side secrets. They must never be committed, embedded in the public
Jekyll site, placed in `.env.example`, or exposed to browser code.

## Phase 13B-2 control-panel shell

The static control panel is available at `/admin/`, with invitation and
password-reset callbacks at `/admin/auth/callback/`. It uses the browser-safe
Supabase URL and publishable key only. At build time,
`_plugins/cms_admin_config.rb` emits those values into
`/assets/js/admin/config.js`; it never reads or emits a privileged credential.

For a local preview, provide the values only to the build process:

```sh
SUPABASE_URL='https://<project-ref>.supabase.co' \
SUPABASE_PUBLISHABLE_KEY='<publishable-key>' \
scripts/preview-local.sh
```

For the production GitHub Pages build, configure these two **repository
variables**:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

The main Pages build fails if either variable is absent. Do not add a Supabase
secret/service key or GitHub credential as a repository variable or workflow
environment value.

In Supabase Dashboard **Authentication → URL Configuration**, set the Site URL
to `https://iyad-ayoub.github.io/astra-team.github.io/admin/` and add these Redirect URLs:

```text
http://127.0.0.1:4000/admin/auth/callback/
http://localhost:4000/admin/auth/callback/
https://iyad-ayoub.github.io/astra-team.github.io/admin/auth/callback/
```

The callback establishes the invitation or password-reset session, asks the
user to set a password, then reads `profiles` through RLS. Missing, suspended,
or RLS-denied profiles are signed out and denied access. The role displayed in
the dashboard comes only from the RLS-protected `profiles` row. The shell has
no sign-up or role/status-editing capability.

## Deferred to Phase 13B-3+

- News/Event and Media Asset tables and their content workflow
- Content/media checksum and lifecycle logic
- Markdown sanitization and Jekyll export validation
- GitHub App, exporter, PR creation, CI/deployment status, and rollback UI
- Project, team, platform, output, and publication CMS support
