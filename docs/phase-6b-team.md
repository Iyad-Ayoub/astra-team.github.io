# Phase 6B team reconciliation

Canonical public roster: _data/team_roster.yml. Current membership and names
follow the user-approved 2025 roster and explicit Phase 6B corrections.
There are 25 current members (2 leadership, 4 permanent researchers,
8 industrial research members, 3 associated researchers/engineers,
7 PhD students, 1 administrative assistant) and 28 alumni.
The final correction makes Christelle Leclerc the sole current Team Assistant.
Abigaïl Palma is a Former Administrative Assistant and Martial Le-Henaff
is a Former Team Assistant. No departure dates or employers are added.
Iyad Abuhadrous is displayed as R&D Engineer (user-confirmed Inria position),
alongside Itheri Yahiaoui and Paul Roger-Dauvergne in the combined
Associated Researchers & Engineers section.
No employer, departure date or profile link is added for Martial; his existing
legacy photo association is preserved in data but not shown in the alumni list.

The 20 requested alumni are included. Six additional people already explicitly
marked alumni in the repository are retained: Anne Mathurin, Souhaiel Ben Salem,
Tan Khiem Huynh, Clément Weinreich, Matteo Marengo and Weihao Xia.

Three previously displayed entries are not classified by the approved roster:
Yasser Benigmim, Soumava Paul and Jonathan Seele.
Their legacy records are preserved, but they are not published as current or
newly labelled alumni. ASTRA confirmation is needed for any future inclusion.

## Compatibility and editorial boundary

_data/team.yml is deliberately unchanged: _layouts/bib.html uses its firstname,
lastname and url fields to match publication authors. It is a frozen legacy
compatibility source, NOT the public current roster. This avoids changing
publication links, removing historical records or touching the HAL pipeline.
A future author-ID migration can remove this duplication under separate scope.
Team editors should edit only team_roster.yml, not the legacy author mapping.

Stable id, name, status, category and role define each public record.
Optional affiliation, additional_role, profile_url, photo, current_position
and display_order are used where supported. Public rendering does not depend on
source_years/last_verified or other editorial metadata. Unknown dates, biographies,
interests, affiliations and source-year granularity are not invented.
Future editorial policy can target this single YAML file; no authentication or
control panel is implemented. Repository templates and ID changes still require
technical review; this content boundary is not authorization enforcement.

Names use the approved display forms while retaining clear existing associations:
Fernando Garrido <- Fernando Garrido Carpio;
Tiago Rocha Goncalves <- Tiago Goncalves Rocha;
Tuan Hung Vu <- Tuan-Hung Vu;
Anne Verroust-Blondet <- Anne-Verroust Blondet;
Nelson De Moura <- Nelson de Moura.
Antionios Tragoudaras follows the supplied spelling without silent correction.

## Photos, links and historical fields

Only person-to-photo and profile links already associated in the legacy records
are reused. Current members without a verified photo render text-only. Alumni
photo references remain stored, but the compact alumni list does not show portraits.
Clotilde Monnet's legacy photo path is retained as historical metadata; the file
is absent and is never rendered. No media files are added, renamed or changed.

Legacy departure dates remain in the unchanged compatibility source; none are
displayed or newly asserted. Karim Essalmi and Noël Nadal have no completion dates.
Existing alumni position text is labelled "Recorded position", not independently
reverified current employment. Legacy HTML is converted to plain text and escaped.
Tiago's old alumni_now value is not treated as alumni evidence.

Run tests/phase6_team_test.rb alongside existing Phase 5/source/artifact checks.
Set PHASE6_SITE and PHASE6_BASEURL for rendered checks at root and project subpath.
