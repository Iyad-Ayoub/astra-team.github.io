# Phase 5C populated content

Factual source: user-approved Phase 5C copy based on the ASTRA 2024 Inria
Activity Report, including the explicitly approved June 2025 SIGHT completion.
No independent report lookup or current software-maintenance verification is implied.

Projects remain in the existing collection, with stable content_id and title.
Added fields: summary, status, type, quoted start_date/end_date (month or day
precision as supplied), kickoff_date, coordinator, partners, astra_role and
source_note. Unknown fields are omitted. The shared project_details include
renders metadata and the same summary used on the index, avoiding duplicated copy.
Only SIGHT, TIRREX and SAMBA have detail pages.

Platforms remain separate YAML records. Zoé adds type and status to the existing
id/title/summary model. No image is verified; none is used. The optional industrial
context block is deferred; Cruise4U and Drive4U are not ASTRA platform records.

Outputs remain YAML records with kind, repository and group added to the existing
id/title/summary model. Group is featured or additional, solely for presentation.
Repository URLs are external and are never prefixed with baseurl. No output
maintenance status is inferred. Aliases share one record (PØDA/PIDA and
MaterialTransform/BRDFTransform). No additional collections or routes are needed
except the three project detail URLs.

No project URLs, software licences, images, unknown dates or platform technical
specifications are invented. Existing editorial separation is preserved.

Validation: run the existing technical-foundation checks, plus
`bundle exec ruby tests/phase5_content_test.rb`. For rendered checks, set
PHASE5_SITE to the build destination and PHASE5_BASEURL to the build's baseurl.
Run this for both root and project-subpath artifacts.
