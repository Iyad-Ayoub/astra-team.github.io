# Phase 2: information architecture and content skeleton

## Content boundaries, not access control

Each editorial content type has a separate source location. These are boundaries
that a future repository policy or CMS can target, not permissions implemented
by Jekyll. No authentication, roles, admin panel, backend or database is added.
Do not grant future editorial tools unrestricted writes to `_data`, `_pages`,
configuration, includes or layouts merely to edit one content type.

- Scientific vision: `_pages/research/vision.md`, a standalone Markdown page.
  Future leadership-level editing can be scoped independently of research axes.
- Research axes: `_research_axes/*.md`, a collection with individual rich pages.
  Keep this as a separately restrictable leadership-level content type.
  The four core axes and cross-cutting section have stable `content_id` values,
  titles, numeric `order` and `axis_group` (`core` or `cross_cutting`).
- Legacy science: `_data/axes.yml` and the existing home introduction in
  `_pages/about.md` remain intact. Include these in future scientific governance;
  ordinary news or team editing must not implicitly permit changing them.
- Projects: `_projects/*.md`, an initially empty output collection. Maintainers
  can later own this path. Required fields: `content_id` matching the filename,
  `title`; body: approved Markdown. URLs are `/projects/<filename>/`.
  No example or fabricated project is published.
- Team: `_data/team.yml`, unchanged structured records and existing rendering.
  Future maintainer scope can include this exact file and approved profile pages
  such as `_pages/fawzi-nashashibi.md`, without including scientific pages.
  Preserve the existing team schema; a later stable-person-ID migration should
  precede cross-content person references rather than using names as foreign keys.
- Outputs/resources: `_data/outputs.yml`, an empty YAML list for short structured
  records. Required `id` (stable lowercase kebab-case) and `title`; optional
  plain-text `summary` and `url` (HTTP(S) or root-relative). Records render on
  `/outputs/` with `#<id>` anchors. No collection is needed for simple links.
- Platforms/demonstrators: `_data/platforms.yml`, a separate empty YAML list with
  the same small record schema, rendering on `/platforms/` with `#<id>` anchors.
  Sharing a display include does not merge editorial ownership or storage.
- News/events: existing `_news/*.md` collection, existing URLs and bodies intact.
  Future communication-editor scope can target only this collection. Preserve
  `date`, `title` and the existing optional `inline` convention. Event announcements
  can use rich Markdown bodies today; dedicated event timing/filter fields are
  deferred until editorial requirements are approved. `date` remains publication
  date, not event start time. `/news/` lists all entries, newest first, including
  currently untitled inline announcements without inventing titles.
- About/contact: `_includes/content/contact.md`, reused by `/about/` and `/info/`.
  This is the existing contact copy and map, not new institutional claims.
- Publications: `_bibliography/rits-astra.bib` and the existing HAL tooling remain
  under their existing workflow. No publication-system changes in this phase.
- Sitewide structure: `_data/navigation.yml`, `_config.yml`, layouts, includes and
  section-index templates remain technical/structural configuration, separate
  from editorial record bodies. New vision and axis titles are sourced from
  their documents for both research navigation and the landing page.

Use explicit path and field allowlists in any future CMS. Content IDs, paths,
permalinks, layout selection, templates and build configuration should not become
arbitrarily editable through a limited content-editor account. Markdown/Liquid is
trusted repository input today; an untrusted-editor integration will need its own
sanitization, approval and enforcement design. This skeleton is not a security boundary.

This choice follows native Jekyll [collections](https://jekyllrb.com/docs/collections/)
for rich detail pages and [data files](https://jekyllrb.com/docs/datafiles/) for
simple records. If a platform or output later warrants rich detail content,
promote only that type into its own collection and preserve its existing index
and stable record anchors. Do not combine everything in one generic collection.

## Navigation and URL tree

```text
Home                                      /
Research                                  /research/
  Scientific Vision                       /research/vision/
  Multimodal Perception & Scene Intelligence
                                          /research/perception/
  Localization, Mapping & Spatial Intelligence
                                          /research/mapping/
  Prediction, Decision-Making, Planning & Control
                                          /research/decision/
  Large-Scale Mobility Systems
                                          /research/cooperative/
  Cross-Cutting & Emerging Research        /research/cross-cutting/
Projects                                  /projects/
Team                                      /team/
Publications                              /publications/
Research Outputs & Resources              /outputs/
Platforms & Demonstrators                 /platforms/
News & Events                             /news/
About / Contact                           /about/
```

The existing Bootstrap collapse and dropdown controls are reused. Navigation
stays collapsed at all viewport widths to accommodate nine long labels without
an overflowing fixed header or a CSS redesign. Research has an overview link and
six document-driven submenu links. Detailed desktop navigation design is deferred.

## Compatibility and content preservation

No existing public route is removed. `/info/` remains a full working compatibility
page, sharing the contact source with `/about/`; no redirect is needed in this
phase. A future canonical/redirect policy for these two pages requires a separate
decision. Do not use the theme's generic home redirect for this purpose.

Preserve `/`, `/research/`, `/team/`, `/team/fawzi-nashashibi.html`, `/publications/`,
`/info/`, `/404.html`, and both existing `/news/<dated-filename>/` detail routes.
The research fragments `#vision`, `#localization`, `#decision` and `#modeling`
continue to resolve, including home-page research links. No claim is made that
the existing four research descriptions map one-to-one to the new hierarchy.
All six new research pages use the neutral preparation message; old descriptions
remain visible, unmodified, below the new landing-page links.

All generated internal links apply `relative_url`; configured permalinks stay
root-relative and must not embed the fork name or a staging host.

## Validation

Run the existing commands in `technical-foundation.md`. Source validation now
includes the new collection directories and record ID/title/URL contracts.
Artifact validation retains all nine legacy routes and requires eleven new
routes. Regression tests additionally cover the new route requirement,
navigation order, separate vision/axis storage and structured-record contracts.
Run root and `/astra-team.github.io` builds in isolated source copies to avoid
changing tracked responsive images. Do not invoke the live HAL update while
checking content preservation.

Deferred: approved scientific descriptions and old-to-new axis mapping; populated
project/output/platform records; event-specific fields and filters; person IDs;
desktop navigation design; `/info/` canonicalization; actual editorial policy,
authentication and enforcement. Empty sections are intentional, not missing data
to fill with examples.

## Phase 2 verification and exact file inventory

Local verification passed on the existing `phase-1-technical-audit` branch:
root and project-subpath production builds; 11 Ruby tests (32 assertions) and
7 offline HAL tests; source YAML/content contracts; artifact internal links,
forbidden paths and credential/removed-host patterns; shell syntax; whitespace.
All 20 routes returned HTTP 200 at both root and `/astra-team.github.io`.
Navigation targets and the seven-link Research submenu were checked on every
route in both builds. Nine intentional skeleton pages contain the neutral message.

Compared with a pre-edit snapshot, 255 protected source files are byte-identical,
including team/legacy-axis data, all news, the 259-entry bibliography, media,
Gemfile.lock, Ruby baseline, Actions workflow and HAL tooling. Existing rendered
page bodies are unchanged except for the additive research landing structure;
all four original scientific descriptions and fragment targets are preserved.

Exact Phase 2 changes (not the accumulated earlier-phase worktree changes):

Modified:

- `_config.yml`
- `_includes/header.html`
- `_layouts/research.html`
- `_pages/info.md`
- `scripts/validate_site.rb`
- `tests/validation_test.rb`

Added:

- `_data/navigation.yml`
- `_data/outputs.yml`
- `_data/platforms.yml`
- `_includes/content/contact.md`
- `_includes/research_links.html`
- `_includes/structured_records.html`
- `_pages/contact.md`
- `_pages/news.md`
- `_pages/outputs.md`
- `_pages/platforms.md`
- `_pages/projects.md`
- `_pages/research/vision.md`
- `_projects/.gitkeep`
- `_research_axes/cooperative.md`
- `_research_axes/cross-cutting.md`
- `_research_axes/decision.md`
- `_research_axes/mapping.md`
- `_research_axes/perception.md`
- `docs/content-model.md`

No files deleted; no branch created, commit, push, deployment or hosted Actions
run. The generated root artifact is `_site/` (ignored by Git). Builds used isolated
source copies following the Sites/environment-setup preservation guidance.
