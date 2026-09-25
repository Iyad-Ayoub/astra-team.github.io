# ASTRA CMS GitHub authentication broker

This Cloudflare Worker is a stateless OAuth broker for the GitHub App
`ASTRA-INRIA-Website-CMS`. It stores no CMS content, drafts, media, users,
roles, or audit records. GitHub remains the persistent CMS backend.

## Tracked configuration

`wrangler.toml` contains only the public GitHub App client ID. The Worker uses
one required Cloudflare secret named `GITHUB_APP_CLIENT_SECRET`. Do not put a
secret value in this repository, `.env`, `.dev.vars.example`, `wrangler.toml`,
GitHub Actions, or any static Pages asset.

The Worker accepts only these CMS callback URLs:

- `http://127.0.0.1:4000/admin/auth/callback/`
- `http://localhost:4000/admin/auth/callback/`
- `https://iyad-ayoub.github.io/astra-team.github.io/admin/auth/callback/`

Its CORS policy permits only the corresponding local origins and
`https://iyad-ayoub.github.io`; it never permits wildcard origins.

## Install and local development

From the repository root:

```sh
npm install --prefix auth-broker
npx --prefix auth-broker wrangler secret put GITHUB_APP_CLIENT_SECRET --local
npx --prefix auth-broker wrangler dev
```

Install Wrangler globally only if preferred:

```sh
npm install --global wrangler
```

The local secret command prompts for the value and writes only untracked Worker
configuration. Never create or commit an example file containing a secret value.
`wrangler dev` is useful for local endpoint testing. A real browser OAuth test
must use an HTTPS Worker endpoint because the broker's cross-site transaction
cookie is `Secure; SameSite=None`; use a deployed preview/production Worker URL
with one of the approved local Pages callback URLs.

## Cloudflare deployment

Authenticate Wrangler, set the Worker secret interactively, and deploy:

```sh
npx --prefix auth-broker wrangler login
npx --prefix auth-broker wrangler secret put GITHUB_APP_CLIENT_SECRET
npx --prefix auth-broker wrangler deploy
```

Wrangler prints the Worker URL after deployment, for example:

```text
https://astra-cms-auth-broker.<account-subdomain>.workers.dev
```

Set the repository variable `GITHUB_AUTH_BROKER_URL` to that exact HTTPS URL,
without a trailing slash. `GITHUB_APP_CLIENT_ID` is already the public App ID
configured in `wrangler.toml`; set the matching repository variable if the
Pages build needs to emit it.

## Endpoints

- `GET /authorize` validates the callback and return path, then generates the
  OAuth state, PKCE verifier, and S256 challenge inside the Worker before
  redirecting to GitHub.
- `GET /oauth/callback` validates the encrypted short-lived transaction cookie
  and exchanges the GitHub code server-side using the stored PKCE verifier. It
  clears that cookie and redirects to Pages with only an opaque, one-minute
  ticket containing the short-lived session result.
- `POST /v2/session/exchange` and `/v2/session/restore` are the credential-safe
  contract used by the current admin app. They return safe identity metadata
  and an opaque session handle; GitHub credentials remain in the Worker.
- `POST /v2/github` accepts named CMS operations only (drafts, media, lifecycle
  preparation, pull requests, and checks). It is not a generic GitHub proxy.
- The unversioned `/session/exchange` and `/session/restore` routes are
  temporary legacy compatibility endpoints. **TEMPORARY — remove immediately after the new frontend is deployed and manually verified.** They exist only for the already-deployed frontend and
  retain its token response contract. They must not be expanded or used by the
  v2 frontend.

The Worker never logs authorization codes, tokens, client secrets, or request
bodies. It clears the transaction cookie after the exchange attempt.

## Compatibility rollout

Deploy this Worker with both the legacy session routes and the `/v2` routes
available. The already-deployed frontend continues using the legacy token
contract. Then deploy the frontend that uses `/v2/session/*` and `/v2/github`,
verify login, drafts, media, publication preparation, and unpublish flows, and
only afterward remove the legacy token-returning routes in a separate cleanup.

## Session restoration and expiry

Cross-site Worker cookies can be blocked by browser privacy controls. For durable
CMS login, bind a Cloudflare KV namespace named `CMS_SESSIONS` to this Worker.
The browser retains only an opaque, origin-bound session handle and safe identity
metadata. KV retains only a sealed access token and its expiry. The v2 session
does not retain or rotate GitHub refresh tokens; when the access token expires,
the CMS session is invalidated and the user must sign in again. Create the
namespace, add its ID as the `CMS_SESSIONS` binding in the Worker settings or
`wrangler.toml`, then deploy. Do not store GitHub credentials in browser storage.

Legacy plaintext KV records are rejected and require one-time reauthentication
after deployment. If another browser tab signs in, the admin listens for the
opaque handle change and restores the session without discarding the current
News form. When reauthentication is unavoidable, that form is kept only in
ephemeral `sessionStorage`.
