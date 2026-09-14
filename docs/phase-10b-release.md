# Phase 10B — Release blockers and safe public-site fixes

Historical validation record. For the current runtime and installation commands,
see [Phase 10D](phase-10d-ruby-baseline.md); the Ruby 3.0.2 references below record
the pre-migration baseline, not current setup instructions.

Branch: `phase-10b-release-blockers`. Based on audited main commit
`2f808d3aec2103886047bfe502c6b7e4394619ef`. No commit, push or deployment.

## A. Exact files changed

- `.github/workflows/jekyll.yml` — root/subpath baseline gates and targeted browser CI.
- `_config.yml` — GA off, HTTPS origin, corrected fallback description, empty optional footer attribution.
- `_data/seo.yml` — metadata-only descriptions for section/index pages.
- `_includes/head.html` — central canonical filter.
- `_includes/metadata.html` — escaped page-specific description.
- `_includes/team/member.html` — suppress only three confirmed failed profile actions.
- `_layouts/bib.html` — same suppression after unchanged author matching.
- `_pages/fawzi-nashashibi.md` — shorten biography to approved roster facts; explicit existing .html route.
- `_plugins/publication_presentation.rb` — normalize BibTeX-escaped DOI underscore for its action URL only.
- `_plugins/release_metadata.rb` — canonical/description/profile-action presentation helpers.
- `_sass/_astra.scss` — homepage-only card content flow.
- `tests/phase6_team_test.rb` — require plain names for the three suppressed profile actions.
- `tests/phase8_publications_test.rb` — rebaseline only removed broken author actions; retain BibTeX snapshot.
- `tests/phase9_research_visuals_test.rb` — rebaseline full config pin for the four authorized settings; retain all media/pipeline/scientific-body checks.
- `tests/phase10_release_test.rb` — source, canonical, description, action and artifact regressions.
- `tests/phase10_browser_test.cjs` — targeted browser containment, metadata, network and storage checks.
- `tests/run_ruby.sh` — invoke every Ruby suite with the correct artifact environment variables.
- `docs/phase-10b-release.md` — this implementation/decision record.

## B. GA remediation

`enable_google_analytics: false`; the existing optional configuration/template
capability is retained, but no GA markup or measurement ID is emitted. No consent
manager/banner was added. Static tests reject Google Tag Manager/Analytics host
strings and measurement IDs in all 33 HTML pages. Browser tests record requests
from navigation start through network idle and an additional post-render wait;
they reject GA requests, GA cookies and analytics storage keys.

This removes the observed GA reason for consent; it does not declare the whole
site legally compliant or remove unrelated font/map/CDN resources.

## C. Homepage regression

The approved axis-4 summary is a paragraph after the card's anchor. The shared
card rule made that anchor 100% of its parent height, leaving the summary outside
the card. A homepage-scoped flex column and auto-height anchor keep both siblings
in normal flow; the grid still stretches cards to aligned row heights. Padding
keeps the summary within its card. No absolute positioning, fixed height, clipping
or hidden overflow was added. Approved text and all images are unchanged.

Browser checks cover 1440/1024/768/390/320px, card child bounds, aligned row
bottoms, Cross-Cutting and Latest News gaps, horizontal overflow, and a
temporary in-browser doubled-title/summary stress test. They do not change
repository content.

## D. Canonicals

The former HTTP origin ended in a slash; the standard absolute_url helper also
included the fork deployment baseurl. The production origin is now normalized.
A single central filter uses logical page.url, removes query/fragment/index.html
noise and repeated slashes, and deliberately excludes the staging deployment
prefix. The origin is required to be HTTPS astra-team.github.io.

Representative before → after:

- Root About: `http://astra-team.github.io//about/` → `https://astra-team.github.io/about/`.
- Subpath About: `http://astra-team.github.io//astra-team.github.io/about/` → `https://astra-team.github.io/about/`.
- Subpath axis 4: `http://astra-team.github.io//astra-team.github.io/research/cooperative/` → `https://astra-team.github.io/research/cooperative/`.
- Legacy biography: explicitly canonicalizes to its existing public route `https://astra-team.github.io/team/fawzi-nashashibi.html`.

All 33 generated pages have exactly one production canonical in both builds.
No public route changes. Draft exclusion remains enforced by the existing news
model and tests. Production root sitemap/robots now benefit from the corrected
site.url; a distinct staging indexing/sitemap policy is still pending (see L).

## E. Descriptions

Previously 32 pages inherited `Astra, join research team Inria / Valeo`.
Descriptions now use explicit front matter, then existing project/news summaries,
then metadata-only index descriptions. Research pages without a summary use the
first approved narrative sentence. Axis 4 uses its approved summary verbatim.
No approved body/front matter scientific content is changed.

Descriptions are escaped, whitespace-normalized and at most 220 characters.
When a longer summary has a complete suitable first sentence, that sentence is
used; otherwise truncation is at a word boundary with an ellipsis. No template,
topic-list or navigation extraction is used as scientific prose. All 33
descriptions are nonempty and distinct. The 404 description is retained.

## F. Biography correction — exact replacement

The public body is now rendered from the approved Fawzi roster entry as:

> Fawzi Nashashibi — ASTRA Team Leader<br>
> Senior Researcher / HDR, Inria.

It then provides `All team members`, linked baseurl-safely to `/team/`.
The page title remains `Fawzi Nashashibi`; its subtitle changes from
`Inria team leader` to `ASTRA Team Leader`. The explicit permalink
`/team/fawzi-nashashibi.html` matches the pre-existing generated route.
The description is `Fawzi Nashashibi — ASTRA Team Leader, Senior Researcher / HDR, Inria.`

The old fixed age, since-2010 Astra leadership assertion, old present-tense
positions/committees/teaching/projects and unverified credentials/expert claims
are removed from the visible biography rather than guessed. The floating
portrait markup and six extra H1 headings are removed with that legacy body;
the media binary and current Team portrait remain unchanged. Benazouz's
`Valeo Scientific Leader` role and all Team classifications are untouched.
The complete previous file is retained in the appendix below for exact review;
Git history also preserves it.

## G. Four confirmed external 404 URLs

- `https://mfahes.github.io/` → suppress action; no replacement.
- `https://weihaox.github.io/` → suppress action; no replacement.
- `https://who.rocq.inria.fr/Anne.Verroust/` → suppress action; no replacement.

No verified replacement was established from the approved data. Names,
classification records and original author-matching tables remain unchanged.
The same presentation-only filter applies to Team and bibliography author
links. Exactly six bibliography author actions are removed, and a comparison
against Phase 10A verified every remaining author action unchanged. The distinct
`https://weihaox.github.io/DREAM` destination is unaffected.

- `https://doi.org/10.1007/978-3-031-39991-6%5C_7`
  → `https://doi.org/10.1007/978-3-031-39991-6_7`.

This removes the BibTeX escape character, not part of the identifier. The
corrected DOI was verified to resolve via HTTP 302 to Springer, then to its
chapter route (final 200 after the publisher's cookie-check redirect).
No bibliography bytes or HAL behavior changed. Other unchecked/temporary
external failures were not modified.

## H. Footer license basis

Inspected repository `LICENSE`: MIT, copyright 2022 Maruan Al-Shedivat.
The [astra-vision repository license](https://github.com/astra-vision/astra-vision.github.io/blob/master/LICENSE)
contains the same MIT notice. [Jekyll](https://raw.githubusercontent.com/jekyll/jekyll/master/LICENSE)
and [al-folio](https://raw.githubusercontent.com/alshedivat/al-folio/main/LICENSE)
also use MIT. These require retaining the copyright/permission notice with
distributed software; they do not prescribe a visible web-footer attribution
sentence. The existing LICENSE, source notices and built LICENSE are retained.
No media rights or institutional legal compliance conclusion follows from this.

Only the optional footer_text configuration is emptied; footer markup and
Inria/Valeo links are unchanged. Result in the 2026 build:

> ASTRA — joint Inria–Valeo research team<br>
> © Copyright 2026 Astra team.

The year remains dynamic, not hard-coded.

## I. CI coverage

All existing Ruby suites plus Phase 10B run against root and project-subpath
builds. These versioned-corpus snapshots run BEFORE the existing live HAL
refresh, so a legitimate newly fetched publication does not conflict with the
frozen 259-entry fixture. HAL then runs normally; the final deploy artifact
retains route/security validation and adds the corpus-size-independent
Phase 10B checks.

The browser checks reuse Playwright rather than adding another test framework;
CI pins the verified locally used Playwright 1.63.0 and uses Node 22. They serve
the artifacts temporarily on loopback and run eight representative routes at
five widths for each baseurl. No Node dependency enters the published artifact.
Existing workflow permissions, triggers and HAL exit-code policy are unchanged.
The workflow has not been run on GitHub because this branch is not committed
or pushed.

Snapshot adjustments are scoped evidence updates, not weakened assertions:
the whole config remains pinned after four authorized settings changed;
publication action snapshots reflect only six intentional link removals;
the original bibliography-text/media/scientific-body snapshots remain.

## J. Validation

Clean production builds are made in previously nonexistent destinations from
an isolated copy to avoid image-generation writes into tracked source assets.

- Root and project-subpath production builds: passed.
- Every Ruby suite: 41 tests / 8,345 assertions per build, no failures/errors/skips.
- Python/HAL: 13 tests passed. Error/warning output from injected failure cases
  is expected. No live HAL update was run locally.
- Bibliography validation: passed, 259 entries.
- Jekyll doctor: passed.
- YAML/front matter/content IDs, 33 routes per build, legacy anchors,
  internal links/assets, forbidden files/credential/host patterns: passed.
- Phase 3 stylesheet URL/compiled-selector checks: passed.
- Existing Phase 8 publication keyboard/filter/no-JS browser tests and Phase 9
  uncropped research-image browser tests: passed at their three tested widths.
- git diff --check and preservation checks: passed.

## K. Browser/network/storage

Targeted root/subpath browser coverage: homepage, research landing, axis 4,
Team, About, TIRREX, IEEE IV 2025 news and Publications at all five requested
widths: 80 combinations. Zero GA requests and cookies observed before/after
render; localStorage and sessionStorage were empty in the sampled pages.
Generated HTML exposes no GA measurement ID. Card containment and longer-text
stress checks pass; no horizontal overflow, clipping or section overlap is
accepted by the test.

Screenshots remain review evidence, not human UX acceptance. Their local
location is `/tmp/astra-phase10b-TetyND/screens/`. Public HTTP third-party
fonts/maps/CDNs are still used; no broader privacy claim is made. Fresh-context
checks do not erase old GA cookies a returning visitor may already have.

## L. Remaining Phase 10A P0/P1 and deferred work

- Observed GA P0: remediated in this branch's artifacts; live deployment remains
  unchanged until a separately authorized release.
- P1 legal/privacy ownership, approved public notices and applicable
  accessibility declaration: explicitly deferred.
- P1 supported Ruby/Bundler migration: explicitly deferred; Ruby 3.0.2 and
  Bundler 2.3.5 remain pinned.
- Canonical generation is fixed. The broader Phase 10A indexing finding is
  not fully closed: staging noindex/robots/sitemap policy and /info/
  consolidation still need a deliberate follow-up. In particular the fork's
  default sitemap still uses its deployment prefix with site.url, whereas its
  canonical links now correctly refer to production root routes.
- The scoped homepage, description, stale biography, confirmed broken-action
  and CI-coverage issues are addressed, subject to human review and the first
  actual GitHub Actions run.

Also pending as requested: cookie-consent manager, accounts/control panel,
responsive-image pipeline repair, platform enrichment, Scientific Vision
revision, Jekyll/dependency upgrades and remaining Phase 10A P2/P3 work.
Do not interpret this pass as overall release approval.

Preserved: 259-entry bibliography, HAL scripts/resilience, publication
author-matching data, Team classifications, Projects/Outputs/Platforms data,
News inventory, approved research prose, media bytes and runtime lockfiles.

## Appendix — exact previous biography file removed/replaced

This is historical review material only. docs/ is excluded from the artifact.

```markdown
---
layout: page
title: Fawzi Nashashibi
permalink: team/fawzi-nashashibi
subtitle: Inria team leader

---


<img class="member-img-light" alt="Fawzi Nashashibi" src="{{ 'fawzi-nashashibi.jpg' | prepend: '/assets/img/team/' | size: 200 | relative_url }}" style="width: 220px; float: left; padding-right: 3em;">
**Dr. Fawzi Nashashibi**, 50 years, is a senior researcher and the Program Manager of the Astra Team at INRIA (Paris) since 2010.



# Positions

He has been senior researcher and Program Manager in the robotics centre of the École des Mines de Paris (Mines ParisTech) since 1994 and was an R&D engineer and a project manager at ARMINES since May 2000. He was previously a research engineer at PROMIP (working on mobile robotics perception dedicated to space exploration) and a technical manager at Light Co. where he led the developments of Virtal Reality/Augmented Reality applications.

# Education

Fawzi Nashashibi has a Master’s Degree in Automation, Industrial Engineering and Signal Processing (LAAS/CNRS), a PhD in Robotics from Toulouse University prepared in (LAAS/CNRS) laboratory, and a HDR Diploma (Accreditation to research supervision) from University of Pierre et Marie Curie (Paris 6).

# Research topics

His main research topics are in environment perception and multi-sensor fusion, vehicle positioning and environment 3D modeling with main applications in Intelligent Transport Systems and Robotics.

# Projects and applications

He played key roles in more than 50 European and national French projects such as Carsense, ARCOS, ABV, LOVe, HAVE-it, SPEEDCAM, PICAV, CityMobil… some of which he is coordinating. He is also involved in many collaborations with French and international academics and industrial partners. He is author of numerous publications and patents in the field of ITS and ADAS systems.

His current interest focuses on advanced urban mobility through the design and development of highly Automated Transportation Systems. This includes Highly Automated Unmanned Guided Vehicles (such as Cybercars) as well automated personal vehicles. In this field he is known as an international expert.

# Teaching & training

Since 1994 he is also a lecturer in several universities (Mines ParisTech, Paris 8 Saint-Denis, Leonard de Vinci Univ. – ESILV professor, Telecom Sud Paris, INT Evry, Ecole Centrale d’Electronique,…) in the fields of image and signal processing, 3D perception, 3D infographics, mobile robotics and C++/JAVA programming.

# Memberships

IEEE member, he is also member of the ITS Society and the Robotics & Automation Society.

He is member of the international committee on “Vehicle-Highway Automation” (AHB30).

He is member of the iMobility Forum, GdR ROBOTIQUE, GdR ISIS

He is an Associate Editor and IPC of several IEEE international conferences (ICRA, IROS, IV, ICARCV,…)
```
