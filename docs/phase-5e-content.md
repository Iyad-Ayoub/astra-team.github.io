# Phase 5E multi-year integration

Source: user-approved inventory derived from the 2022–2025 ASTRA reports.
This does not imply independent report or live URL verification.

Projects remain in _projects with unchanged existing routes. Shift2SDV and GAT
add /projects/shift2sdv/ and /projects/gat/. Status is stored as ongoing/completed;
scope as national/european/international; type as research-project,
research-infrastructure or joint-lab. Labels are rendered separately from keys.
Acronym, programme, scope and optional external_url/cordis_url are added.
Order controls presentation within the two status groups; dates retain supplied
month/day precision. Unknown dates, coordinators, partners and URLs are omitted.
SAMBA is now completed (2020-09–2023-01); SIGHT still ends in 2025-06.

Outputs retain all eight previously approved records unchanged. Ten are added:
MonoScene, SceneRF, DREAM, Weather Simulator and six datasets. Existing featured
and additional group keys and section anchors are preserved; datasets/frameworks
are added. Category headings live in the outputs page front matter.

Link provenance:
- Shift2SDV website and CORDIS, TIRREX website: approved Phase 5E instructions.
- Eight existing GitHub repository URLs: unchanged _data/outputs.yml records.
- MonoScene project page: _bibliography/rits-astra.bib, cao:hal-03498508 NOTE.
- DREAM project page: same bibliography, xia:hal-04366806 NOTE.
- SceneRF has a HAL publication URL, not a verified project/repository URL.
  It, Weather Simulator and all six datasets intentionally have no action link.
- GAT, SIGHT and SAMBA have no invented external links.

Platforms remain separate YAML records: four inria-astra and three valeo.
Zoé's original id, title, description, type and status are preserved.
New records use exactly approved descriptions, without new statuses, technical
specifications, images or URLs. Grouping does not assert blanket ASTRA ownership.
No separate records are created for aliases or software/demo/repository variants.

Per-record report years and scientific_contribution are omitted: the approved
inventory does not supply that granularity. source_note is editorial-only.
No images, global design tokens, HAL code or protected content are changed.

Run technical-foundation checks and tests/phase5_content_test.rb with PHASE5_SITE
and PHASE5_BASEURL for each root/subpath artifact. Assertions are updated for the
approved inventory rather than retaining superseded Phase 5C facts.
