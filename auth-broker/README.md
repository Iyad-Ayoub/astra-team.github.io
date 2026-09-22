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

- `GET /authorize` validates the fixed client ID, PKCE challenge, state, and
  callback allowlist, then redirects to GitHub.
- `GET /oauth/callback` validates the encrypted short-lived transaction cookie
  and redirects to Pages with only an opaque ticket and state.
- `POST /session/exchange` validates CORS, ticket, state, transaction cookie,
  callback, and PKCE verifier; it exchanges the GitHub code server-side and
  returns a short-lived GitHub user token plus expiry.

The Worker never logs authorization codes, tokens, client secrets, or request
bodies. It clears the transaction cookie after the exchange attempt.
