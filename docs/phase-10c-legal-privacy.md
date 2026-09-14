# Phase 10C — legal, privacy, accessibility and indexing readiness

Date: 14 September 2026. Branch: `phase-10c-legal-privacy-readiness`.
The uncommitted Phase 10B work was preserved on this branch. No commit, push or
deployment is authorized. This implementation is not formal legal approval.

## Scope and public notices

The four exact approved homepage summaries are keyed by stable research
`content_id` in `_data/home_research.yml`. This is homepage presentation copy,
not a replacement for scientific detail or research-landing descriptions.
All four summaries are normal-flow children of their cards; images, titles,
links and full scientific source text remain unchanged.

New routes: `/legal/`, `/privacy/`, `/accessibility/`. A small scoped layout
uses the existing design and a 48rem reading width. The footer includes three
wrapping links from one shared include, retaining the institutional line and
copyright without restoring theme attribution.

The legal notice distinguishes ASTRA's joint Inria–Valeo editorial identity,
Inria's verified institutional identity/address/telephone, and GitHub Pages
hosting. The repository's origin is the working fork; upstream identifies
`astra-team/astra-team.github.io`. Production is `https://astra-team.github.io/`.
The existing Actions workflow builds Jekyll and uploads a Pages artifact.
Internal repository/security details are not added to the public notice.

**Unresolved institutional field:** the legally responsible publication
director specifically for this ASTRA site could not be verified. The public
notice explicitly says it remains subject to institutional confirmation.
Neither the team leader nor Inria's corporate leadership is silently assigned
that legal role. Inria/ASTRA should approve the notice and exact hosting legal
entity/contact details before treating the legal release blocker as closed.
The rights paragraph respects existing licences and does not assert that
Inria owns every image, publication or linked software package.

## Actual processing and tracker assessment

Inspected: `_config.yml`, `_layouts/default.html`, `_includes/head.html`,
`_includes/scripts/*.html`, `_includes/content/contact.md`, generated HTML,
the public team/news/publication content and fresh browser requests/storage.

- No visitor accounts or contact form are implemented. Email links use the
  visitor's email client; correspondence includes the sender's address/message.
- Static public content still contains personal data: professional names,
  roles, affiliations, portraits, publication authors and news references.
- GitHub Pages serves the site. The provider can receive technical request
  information; ASTRA's direct control over GitHub logs is not assumed.
- Fonts and interface code load automatically from Google Fonts, jsDelivr
  and unpkg; contact maps load OpenStreetMap tiles. This is not described as
  processing that happens only after clicking an external link.
- GA and Panelbear remain disabled. There is no newly introduced tracking,
  consent manager, form, upload or account processing.
- The privacy notice uses the requested narrow statement: “No
  audience-measurement or advertising trackers are currently enabled by ASTRA
  on this website.” It does not claim all providers are cookie-free.
- No consent-requiring analytics/advertising tracker was found in the inspected
  generated pages or fresh browser checks, so no cookie banner was added.
  Fresh local browser checks cannot prove the absence of all provider-side
  logs or erase cookies left by older deployments. Recheck the real deployment
  after separately authorized release.

Christelle Leclerc (`krystel.leclerc@inria.fr`) remains the current team contact.
Personal-data enquiries refer to `dpo@inria.fr` and Inria's institutional
framework, not an invented ASTRA controller assignment. Institutional review
must establish the applicable controller responsibilities/legal bases,
publication and correspondence retention rules, and any provider/transfer
obligations; no unsupported retention period or legal basis is published.

## Accessibility limitations

The notice describes an aim and progressive review, with a usable reporting
contact. It expressly does not assert RGAA or partial compliance. Inria's
broader declaration is linked but its audit/score is not transferred to ASTRA.
Browser containment, readable text, keyboard features and link checks are not
a formal ASTRA accessibility audit. Institutional assessment remains needed
for any required formal declaration and remediation plan.

## Indexing policy

- `/info/` remains publicly reachable with the shared About/Contact body.
  Front matter sets `canonical_path: /about/` and `sitemap: false`; no redirect
  mechanism or old route is removed.
- All HTML canonicals target production root routes, never the fork prefix.
- `ASTRA_BUILD_CONTEXT=production` requires an empty baseurl and leaves HTML
  indexable. `staging` emits `noindex, follow`, including for a root-hosted fork.
  Unknown context values and production/nonempty-baseurl combinations fail
  the build rather than silently emitting unsafe metadata.
- With no explicit context, root is a production-equivalent local baseline
  and a nonempty subpath is staging. The final Pages build explicitly selects
  production only for `astra-team/astra-team.github.io`; every fork is staging.
  A manually published root preview must explicitly use `staging`.
- Root/subpath CI baseline builds deliberately simulate each context. Final
  deployment-artifact checks run the new readiness regression with the real
  build context. Permissions, HAL policy and deployment mechanism are unchanged.
- A native Liquid sitemap overrides the gem's default origin-plus-baseurl
  composition. It includes output collections and public HTML pages, respects
  `sitemap: false`, and excludes 404. News draft exclusion remains with the
  existing news pipeline. Both maps contain only production URLs.
- Production robots allows crawling and advertises the production sitemap.
  Staging robots allows crawling so crawlers can read HTML `noindex`, and
  advertises no sitemap. A `Disallow: /` rule would obstruct that signal.
  Staging is not access-controlled; noindex is a search-engine instruction,
  not a privacy/security boundary.

## Official references

Consulted 14 September 2026:

- Inria institutional legal identity/address:
  https://iww.inria.fr/mentionslegales/
  Only institutional facts were reused. Its WordPress/Automattic/theme/DSI
  and cookie wording is not applicable to this Jekyll/Pages site.
- Inria personal-data framework and DPO:
  https://www.inria.fr/fr/protection-des-donnees-caractere-personnel-rgpd
  Search-indexed official content was available at
  https://www.inria.fr/index.php/fr/protection-des-donnees-caractere-personnel-rgpd
  (updated 15 November 2023). Direct retrieval was blocked by Inria's bot
  protection; no inria.fr contact-form processing was copied to ASTRA.
- Inria accessibility commitment:
  https://www.inria.fr/fr/declaration-accessibilite
  Search-indexed official content at
  https://www.inria.fr/index.php/fr/declaration-accessibilite
  was updated 13 March 2026; direct retrieval was blocked. Its audit pertains
  to inria.fr, not ASTRA.
- CNIL cookie/tracker guidance:
  https://www.cnil.fr/fr/cookies-et-autres-traceurs/que-dit-la-loi
  Used to distinguish consent-requiring tracking from necessary operations;
  absence of an ASTRA banner is not a general compliance certification.
- GitHub hosting: https://pages.github.com/
- GitHub provider processing:
  https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement
  (effective 27 April 2026). Its entire service/account policy is not attributed
  to ASTRA's static site.

## Future control panel — internal only

Before accounts, authentication, editorial identities, uploaded files, audit
logs or analytics are introduced, reassess controller/processor roles, lawful
bases, retention, access controls, security, transfers, rights handling and
cookie/consent needs. Update notices for actual new processing then. None of
this nonexistent account processing is described as current public behavior.

## Preservation and validation

Phase 10C changes are compared against a snapshot of the incoming dirty tree,
not merely HEAD. HAL scripts, the 259-entry bibliography, author mappings,
team classifications, project/output/platform records, news inventory, all
scientific descriptions and every media binary remain byte-for-byte unchanged.
Bibliography SHA-256:
`c5f03fdefae21026eda865f99cb10d167b672d90afc082f42938e9262a01c14a`.

Root and `/astra-team.github.io` production builds pass. All Ruby suites
(Phase 5–10, pre-10 and validation fixtures), Python/HAL tests, bibliography
validation, Jekyll doctor, route/link/asset/security checks and whitespace checks
are run for this pass. There are 36 HTML routes and 34 sitemap URLs in each
artifact. Tests cover exact summaries, footer links, contacts, canonical alias,
draft omission, sitemap equality, staging noindex and production indexability.
Browser checks cover 1440/1024/768/390/320px for homepage, About, Info, all three
notices and existing regression pages, including card containment/stress,
footer height, mobile overflow, typography and analytics requests/cookies.
See the final handoff for measured results and limitations.

Measured results: 43 Ruby tests per build, 9,238 assertions at root and 9,202
under the project subpath, with zero failures/errors/skips. All 13 Python/HAL
tests pass; their deliberate invalid-input cases print expected ERROR lines.
The standalone bibliography validator passes when supplied the bibliography
path (an initial invocation without that required argument was corrected).
The additional root-hosted staging build passes both readiness tests (413
assertions), confirming noindex does not depend solely on a URL prefix.
The Phase 10 browser matrix covers 120 route/viewport combinations across the
two build contexts; existing Phase 8 publication and Phase 9 research browser
suites also pass against the root build. Fresh browser contexts show no GA
requests/cookies and no analytics storage. Observed external request hosts are
Google Fonts, jsDelivr, unpkg and OpenStreetMap, consistent with the notice.
Representative desktop and mobile screenshots were inspected in addition to
automated checks; human visual acceptance is still required.

Phase 10C-only file list (20 files, relative to the incoming Phase 10B state):

- `.github/workflows/jekyll.yml`
- `_data/home_research.yml`
- `_includes/footer.html`
- `_includes/footer_legal_links.html`
- `_includes/head.html`
- `_layouts/about.html`
- `_layouts/legal.html`
- `_pages/accessibility.md`
- `_pages/info.md`
- `_pages/legal.md`
- `_pages/privacy.md`
- `_plugins/indexing_policy.rb`
- `_sass/_astra.scss`
- `robots.txt`
- `sitemap.xml`
- `tests/phase10_browser_test.cjs`
- `tests/phase10_release_test.rb`
- `tests/phase10c_readiness_test.rb`
- `tests/pre_phase10_content_test.rb`
- `docs/phase-10c-legal-privacy.md`

## Remaining release decisions

No new P0 found. Prior observed analytics behavior is disabled in these
artifacts, but the live deployment is not changed by this task. P1 institutional
legal/privacy approval (including the publication director and processing
responsibilities) remains open; public draft notices do not settle those facts.
A formal ASTRA accessibility assessment/declaration remains an institutional
decision. The supported Ruby/Bundler migration is explicitly deferred: this
phase does not change Ruby 3.0.2, Bundler 2.3.5 or the lockfile. Indexing fixes
still require the first authorized workflow/deployment verification. Human
browser and institutional review, not test success alone, gates acceptance.
