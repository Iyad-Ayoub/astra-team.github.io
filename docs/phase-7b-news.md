# Phase 7B — News & Events integration

## Source basis and inventory

The nine new records use the user's approved Phase 7B inventory derived from
2022–2025 ASTRA activity/evaluation material. No private reports or evaluation
text are copied into the site. This implementation does not claim independent
verification of those reports. Public summaries follow the approved copy.

New records (all published):

- ieee-iv-2025: 22–25 June 2025, Cluj-Napoca, Romania.
- matswap-egsr-2025: 2025 only.
- acvss-2025: 2025 only; no inferred host country or exact date.
- pasco-cvpr-2024: 2024 only.
- acvss-nairobi-2024: 14–24 July 2024, Nairobi, Kenya.
- raoul-dr-2024: 2024 only.
- open-source-2024: 2024 only; one roundup, not separate releases.
- open-source-2023: 2023 only; one roundup.
- visapp-2022-best-paper: 2022 only. The existing bibliography entry
  delleva:hal-03498133 corroborates the award/title/authors. Its publication
  month is not treated as the award's exact date.

Two previous records are retained, making 11 stored records: 10 published and
one draft. The public archive contains the nine approved additions plus the
2025 plenary.

- 2025-01-20-plenary: same body and route, schema migrated, descriptive title
  and summary added from its existing text. Displayed in the 2025 archive.
- 2022-07-01-astra-creation: stored as `status: draft` following the final
  editorial correction. Its historical body is unchanged, with a checksum
  regression test. It appears neither in the archive nor on the homepage;
  its former detail route is intentionally not generated. No historical-review
  notice, unfinished wording or editorial warning is rendered publicly.
  Future publication requires a separate approved editorial review.

Nothing was deleted. No unrelated content or publication/HAL data was changed.

## Schema

Canonical content remains Markdown documents in `_news`, with YAML front matter.
The Markdown document body is the `body` field for future editors; it is not a
second YAML copy. Rich detail pages justify this existing Jekyll collection.

Required for each record: `content_id` (stable unique ID), `slug` (stable unique
route segment), `title`, `status`, `type`, `event_date`, `date_precision`, `summary`.
Use quoted strings for event dates. Routes are `/news/<slug>/`.

Allowed status: draft, published. Allowed type: award, event, project,
open-source, team, collaboration, demo.

Optional fields: `end_date` (quoted exact date), `location`, `image`, `image_alt`,
`image_credit`, `external_url`, `related_project`, `related_output`, `featured`,
`homepage`, `author`, `last_updated_by`, `published_at`, `display_order`, `source`,
`source_year`. Optional editorial values are omitted when unknown; no author or
publication timestamp was invented. `legacy: true` marks the preserved creation
announcement, not a new public type/status.

`related_project` references a project content_id; `related_output` an output ID.
The renderer resolves links from existing records, not duplicate definitions.
Roundup body links point to `/outputs/`. PaSCo links to `/outputs/#pasco`.
MatSwap has no existing output record, so its relationship stays absent.

Source/editorial metadata is never rendered by the news templates. Drafts are
removed from the collection at post_read, before page generation and sitemap
processing; they must not appear at a directly guessed route either. Production
builds must use clean destinations (as CI does), not incremental publishing of
previous artifacts. This is publication filtering, not authorization: repository
readers can still see source files. Never store secrets/private reports there.

## Dates and homepage

`event_date` deliberately avoids Jekyll's automatic `date` coercion/file-date
fallback. It accepts YYYY, YYYY-MM or YYYY-MM-DD, with matching `date_precision`
year, month or day. The two old `date` values remain for compatibility, but are
not used by news rendering or sorting. `end_date` is supported for day ranges.

Public labels show only known precision; year-only labels have no fabricated
HTML datetime. Derived `news_year` and `news_date_label` are build-only values.
No invented January 1 date or synthetic date is stored. Sorting uses descending
year/month/day components, treating absent components as zero for ordering only.
Thus dated items precede year-only items within a year; ties use ascending
`display_order`, then content_id. This is deterministic, not a claim that
year-only events happened before dated events. Both listings explain this.

Homepage selects the first three published, non-legacy, `homepage: true` records
in that order. `featured` is an editorial flag, not a date override. The initial
eligible set is IEEE IV, MatSwap, ACVSS (all 2025). ACVSS is enabled to supply the
third recent item, as approved. Older items and the plenary are archive-only.
Homepage summaries are excerpts of at most 26 words; detail/archive preserve
full approved summaries. View all news points to `/news/` using relative_url.

## Images and intentional gaps

All 11 records initially omit images. No image assets are changed/downloaded.
Cards omit the entire figure when absent; optional figures use contain-sized,
aspect-preserving images, alt text and visible credit when supplied.

Inspected candidates:

- `assets/img/publication_preview/2023-pasco.gif`: PaSCo research preview, not
  evidence of the 2024 award event; not reused as award photography.
- `assets/img/astra-2023.jpg`, `assets/img/astra-2025.jpeg`,
  `assets/img/astra-2025_crop.jpg`: team images without verified association to
  these particular news events; not reused.
- Existing team portraits (including Ivan Lopes and Raoul de Charette) are not
  used to imply event attendance or image authorization for this archive.

Only two external URLs are used: the explicitly approved
https://ieee-iv.org/2025/ and the existing verified PaSCo repository
https://github.com/astra-vision/PaSCo from `_data/outputs.yml`.
No guessed links for MatSwap, ACVSS, VISAPP, promotion or conference paper.
Exact dates, image credits, authors and unpublished editorial timestamps remain
blank where unknown. No MatSwap output record was created.

## Future control panel and compatibility

Future contributor → editor → published review can use status and editorial
fields without changing public routes or the content store. No users, roles,
authentication, API or control panel is implemented. News remains independently
governable from research, projects and team.

Stable IDs/slugs should survive title changes. Changing a published slug later
requires explicit route compatibility handling. The small local Jekyll plugin
must run in the existing Actions build; GitHub Pages safe-mode compilation alone
is not supported. No workflow changes are needed for that existing build path.

Validation: run `tests/phase7_news_test.rb` with `PHASE7_SITE` and optional
`PHASE7_BASEURL` after each production build, alongside all existing gates.
The tests also build an isolated tiny fixture site to exercise draft exclusion,
month precision, and optional image rendering without changing public content.
