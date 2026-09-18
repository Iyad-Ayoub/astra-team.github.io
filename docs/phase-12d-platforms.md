# Phase 12D-A platform evidence and classification

`_data/platforms.yml` is the platform registry for `/platforms/`. Each record
has a stable `id`, a human-readable `name`, `platform_type`, `relationship`,
`temporal_status`, `evidence_status`, neutral summary, ownership context, and
an `evidence_as_of` date or year.

`temporal_status` records what the attached evidence proves:

- `current` requires direct current-period evidence.
- `reported_inventory` means a dated inventory listed the platform without
  establishing present availability.
- `historical` identifies a documented earlier demonstrator or platform family.
- `status_unverified` preserves a documented record whose present availability
  is not established.

Every record contains at least one source object with title, HTTPS URL,
publisher, year, source type and a concise statement of what the source
supports. Evidence date is distinct from factual status: a 2023 inventory is
not evidence of 2026 availability.

`media` is intentionally an empty array in Phase 12D-A. A future approved media
object must include the local image path, meaningful alt text, credit, source
URL, source type, year/context and usage/provenance status. No external image is
hotlinked or copied without that record and verified permission.

Cybus and Cybercars are rendered only as Historical Experimental Heritage on
`/platforms/`; their Phase 12B Scientific Heritage evidence remains in
`_data/scientific_heritage.yml`. Their earlier page fragment identifiers remain
as aliases, while the canonical stable platform IDs are `cybus` and `cybercars`.
