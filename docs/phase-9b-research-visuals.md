# Phase 9B — Controlled research illustrations

Only three established Phase 9A P1 illustrations are integrated. The original scientific Markdown bodies remain byte-for-byte unchanged; optional front matter selects a reusable `research_visual` layout, which inserts a semantic figure after the introduction's first rendered paragraph. The page title and scientific text remain primary. No responsive-image filters are invoked by the new include.

## Selected sources and editorial metadata

- `assets/img/research/axis_astra-vision.png` → `/research/perception/` (591×480).
  Evidence: `_data/axes.yml` explicitly associates this exact file with Robust Visual Scene Understanding and three-dimensional/multimodal environment understanding; the existing homepage maps this legacy axis to Perception. Alt: “Color-coded three-dimensional representation of a road scene.” Caption: “Three-dimensional scene representation illustrating perception research.”
- `assets/img/research/axis_localization.jpg` → `/research/mapping/` (672×397).
  Evidence: `_data/axes.yml` explicitly associates this exact file with Localization and Mapping and heterogeneous sensor/map representations; the homepage maps it to Mapping. Alt: “Colored point-cloud representation of a street and its surroundings.” Caption: “Spatial representation illustrating localization and mapping research.” The file contains PNG data despite its historical `.jpg` suffix; neither name nor bytes are changed.
- `assets/img/research/axis_decision.jpg` → `/research/decision/` (659×536).
  Evidence: `_data/axes.yml` explicitly associates this exact file with Decision Making and Vehicle Control, including trajectory prediction and motion planning; the homepage maps it to Decision. Alt: “Road scene with highlighted vehicles and overlaid paths.” Caption: “Road-scene illustration accompanying decision-making and motion-planning research.”

Captions indicate illustrative context, not a specific algorithm, performance result, ownership or representation of the entire axis. No credit is invented: the audit found no asset-specific creator/source/authorization record for these three figures. Repository association is not proof of ownership. Provenance confirmation remains deferred. Optional `image_credit` is supported by the include but intentionally unset.

## Excluded candidates and pages

`assets/img/research/axis_modeling.jpg` remains excluded from new placements. Its legacy Large-Scale Mobility Systems text explicitly mentions infrastructure cooperation, V2X, traffic and fleet modelling, so the broad thematic relationship is established. However, neither that text nor the audit establishes what this aerial roundabout photograph specifically demonstrates. Do not caption it as connected vehicles, coordination or a cooperative experiment. Cooperative remains image-free pending a sufficiently specific approved interpretation.

Cross-Cutting has no verified P1 illustration. It remains image-free, as do Scientific Vision and the Research landing page. No project, platform, output, news or other legacy publication preview is substituted. Homepage, team and all other pages retain their existing image inventory.

## Presentation and future replacement

Front matter provides `image`, `image_alt`, `image_caption`, `image_width`, `image_height` and optional `image_credit`. Replacement requires verified association, descriptive alt and correct intrinsic dimensions. No collection/model redesign or media database is introduced.

Figures use a 38rem maximum container width, natural image width capped at 100%, automatic height and existing spacing/type tokens. No crop, forced aspect ratio, clickable image or extra heading. On narrow screens images fit the available content width. Semantic `figure`/`figcaption` associates the caption; all original scientific explanations remain readable without the visual.

## Pipeline boundary and validation

Both existing responsive-image plugins, their configuration, `_includes/figure.html`, source images and tracked `_responsive` derivatives are intentionally untouched. The Phase 9A nominal-1400/actual-800 issue is deferred. Production builds run in an isolated copy to contain plugin side effects.

`tests/phase9_research_visuals_test.rb` freezes scientific body hashes, pipeline-file hashes and all existing image/cache bytes; checks the exact three source mappings, meaningful alt and captions, intrinsic dimensions, non-cropping rules, placement after the introduction, one figure per allowed page, no figures elsewhere and root/subpath asset existence. Run it with `PHASE9_SITE` and optional `PHASE9_BASEURL` against each build. Preserve and run all Phase 5–8 and HAL validations. Browser review covers the three changed pages and `/research/` at 1440, 390 and 320px. Human scientific and visual acceptance remains required.

## Validation results — 9 September 2026

- Ruby 3.0.2 / Bundler 2.3.5: `bundle check` passed with the existing lockfile.
- Isolated root and `/astra-team.github.io` production builds passed. Jekyll doctor passed. Existing minifier informational messages remain unchanged.
- All six Ruby test files passed independently against each build: 35 tests, 4,299 assertions, no failures/errors/skips per build. This includes Phases 5, 6, 7, 8, 9 and the existing validation suite. A trial loading all suites into one Ruby process exposed existing Phase 7 fixture/filter state interference; use the established separate-process test commands. No previous tests were altered.
- Python/HAL: 13 tests passed, including simulated invalid/remote-failure cases (their expected error messages are not test failures). Bibliography validation passed with 259 entries; bibliography bytes unchanged.
- Source validation and all 33 generated routes, internal links/assets, stylesheet checks, forbidden files and credential patterns passed at both base URLs.
- Phase 9 Chromium checks passed for Perception, Mapping, Decision, Research landing, Cooperative and Cross-Cutting at 1440/390/320px (18 combinations). Screenshots of every newly illustrated page and the landing page were inspected at all three widths; no cropping, stretching, upscaling, oversized full-width banner, unreadable caption or horizontal overflow observed. Existing heading spacing remains unchanged. Cooperative/Cross-Cutting remain image-free.
- Existing Phase 8 browser search/filter/actions/responsiveness and no-JavaScript checks passed at all three widths.
- All tracked image and `_responsive` bytes match the pre-change snapshot. Plugin/configuration, approved prose, team data, other page sources and bibliography remain unchanged. `git diff --check` passed.

No commit, push or deployment. Stop for human review; automated checks and assistant screenshot inspection do not constitute human visual/scientific acceptance.
