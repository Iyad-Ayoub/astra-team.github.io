# Phase 8B — Publications archive presentation

## Existing architecture and boundary

The actual source is `_bibliography/rits-astra.bib` (not a file literally named
`bibliography.bib`). `scripts/publication-update.sh` calls the existing
`scripts/hal-export-to-bib.py` synchronization/normalization/validation path.
Neither script, its resilience semantics, the workflow, nor the bibliography
validator is changed. The corpus has 259 records at this implementation baseline.

Jekyll Scholar 7.3.0 uses BibTeX.rb and the configured latex/smallcaps/superscript
filters. `_pages/publications.md` invokes the bibliography renderer and
`_layouts/bib.html` presents each record. Existing client-side search lives in
`assets/js/bibsearch.js`, loaded by `_includes/bib_search.liquid`.
Author/profile matching uses legacy `_data/team.yml` and `_data/coauthors.yml`,
not the independently governed public team roster. These files remain unchanged.

## Presentation changes

The small `astra_bibliography` tag subclasses Scholar's existing bibliography
tag. It consumes the same `cited_entries`, calls the same record-rendering
utilities and adds a transient presentation hash. It does not import a second
database, re-fetch HAL, rewrite entries or persist derived scientific metadata.

Year groups are computed from parsed years, descending. Within each year,
Scholar's existing year/month ordering is retained without fabricated dates.
Server-rendered group counts and total count come from those same entries,
including with JavaScript disabled. A two-record fixture verifies that count
generation is not hard-coded to the current 259-record corpus.

Public type mappings use the actual BibTeX entry type, not a free-text `TYPE`
field that could overwrite `entry.type` in Scholar's Liquid hash:

- article → Journal
- inproceedings, conference → Conference
- unpublished, preprint → Preprint (the current HAL unpublished/working-paper corpus)
- phdthesis, mastersthesis, thesis → Thesis
- techreport → Technical Report
- book, inbook, incollection → Book / Chapter
- misc and unknown types → Other

No underlying BibTeX types are changed. In particular, misc is not guessed to
be a preprint from its title. Current counts are 61 Journal, 150 Conference,
7 Preprint, 21 Thesis, 9 Technical Report, 3 Book / Chapter and 8 Other.

Rows show type/date, title, authors, venue and available volume/issue/pages.
Venue precedence is journal, booktitle, school, institution, publisher,
howpublished; absent fields are omitted, never inferred from URLs/titles.
Month names are displayed only for recognized source month values. Unknown
months fall back to the year; no day-level dates are manufactured.

## Authors and BibTeX compatibility

The previous author-matching logic and visible mapped links remain intact.
Lists exceeding the existing ten-author limit now use native details/summary
for the remaining names rather than an onclick-only animated span. This avoids
a giant initial row for the 243-author record while keeping all names searchable.
Names in the existing overflow list remain plain text, as before; no profiles
are guessed and no external author searches are performed.

BibTeX uses a collapsed native details/summary control, with a readable,
wrapping monospace block. Native HTML supplies keyboard and expanded/collapsed
accessibility semantics. The exact previously displayed BibTeX text is preserved,
including Scholar's existing skipped fields and `hideCustomBibtex` filtering;
it is not a newly reformatted or manually rewritten export. The bibliography
source itself remains byte-for-byte unchanged. Regression snapshots from a
pre-change production build cover all author-link tuples and all BibTeX blocks.

## Actions

- HAL: use an existing HTTP(S) URL on hal.science/archives-ouvertes.fr (including
  subdomains), or a syntactically valid existing HAL/TEL identifier. No title or
  DOI lookups. The current corpus provides 259 actions.
- PDF: only an explicit existing HTTP(S) PDF field; never relabel a generic
  landing-page URL as PDF. Current corpus: 209 actions.
- DOI: only a valid-looking existing DOI field. DOI URL prefixes are normalized
  and path components are encoded so #/? cannot become URL controls. Current
  corpus: 88 actions.
- BibTeX: available for every rendered record through the existing export.

Unsafe/unsupported URL schemes and credential-bearing URLs are not rendered.
No per-record network calls or external browser APIs are used. The introductory
HAL link is the already present Inria HAL homepage, not an invented ASTRA
collection URL. External destination availability is not asserted by local tests.

## Search, filters and accessibility

Search retains `#bibsearch` and legacy author/search hash URLs. It matches
case-/accent-insensitively across title, all authors, venue, source keywords,
displayed date/year and normalized type. Whitespace-separated query terms must
all match. Native year/type selects combine with search without a reload.
Year options are derived; type options use the seven public categories.

Search text is cached once from existing row DOM. A 120 ms debounce avoids
repeated input work; filtering toggles hidden on existing list items and empty
year groups, rather than reconstructing the corpus. The old highlighting-module
dependency is no longer required by this search; its unrelated source file is
left untouched. Search matching is preserved, but term highlighting is not added.

The total/filtered count is a polite live status; per-year counts update too.
Zero matches show an explicit empty-state message. Labels, focus outlines,
native selects and native disclosure controls support keyboard operation.
Exact citation-key/year anchors scroll to their targets; other fragments remain
search queries. Malformed percent-encoding cannot crash initialization.

With JavaScript disabled the full static archive, counts and disclosures remain
usable; interactive controls stay hidden. Styles are scoped to this archive,
with stacked controls below 768 px, wrapping actions and contained BibTeX.

## Verification and future control panel

Ruby tests: `PHASE8_SITE=<build> PHASE8_BASEURL=<optional-baseurl> bundle exec ruby tests/phase8_publications_test.rb`.
Browser tests: serve the build locally and run `tests/phase8_browser_test.cjs`
with Node and Playwright. `ASTRA_SITE_URL` may include the project subpath;
`PLAYWRIGHT_MODULE` / `CHROMIUM_EXECUTABLE` can use an existing QA installation.
`PHASE8_SCREENSHOTS` optionally names an existing temporary screenshot directory.
No browser dependency or package lock is added to the website.

Publications remain HAL-driven. Ordinary editors should not create or rewrite
HAL records. A future separately authorized control panel may inspect sync state,
trigger synchronization, manage an explicitly approved featured flag, relate
records to projects/outputs, or apply a traceable duplicate/problem overlay.
None of those control-panel features or scientific rankings are implemented.

Intentional gaps: no guessed missing venue/link/date, no external link availability
audit, no automatic coauthor profile discovery, no featured/best-publications
selection. Any future HAL source-schema changes should be reviewed with the
normalization tests rather than manually patching imported entries. The snapshot
integrity tests must be deliberately refreshed after an approved HAL update.
