# Phase 12B — Scientific heritage, timeline and research enrichment

This document records evidence used for the limited historical context added in
Phase 12B. It is an editorial source record, not public page copy.

## Public milestones

| Year / period | Item | Classification | Evidence and decision |
| --- | --- | --- | --- |
| 1993 | Praxitèle programme | `HISTORICAL_EARLY_MOBILITY` | [Inria 1996 activity report](https://radar.inria.fr/rapportsactivite/RA1996/meval/meval.pdf) states that a 1993 industrial consortium involving Inria studied public transport with small, preferably electric urban vehicles managed by telecommunications. The public timeline does not call Praxitèle a team. Confidence: high. |
| 1997 | IMARA project | `HISTORICAL_IMARA` | A [secondary academic thesis](https://citeseerx.ist.psu.edu/document?doi=86b61b28b3384e9961389ae51d47ed1fa7f83dec&repid=rep1&type=pdf) states that IMARA was started in 1997 at Inria Rocquencourt by Michel Parent, following Praxitèle. Inria’s [1997 archive](https://radar.inria.fr/archive/1997) was searched but does not provide an available IMARA report; Inria’s [2002 IMARA report](https://radar.inria.fr/rapportsactivite/RA2002/imara/imara.pdf) independently supports its intelligent-road-transport research objective, but not the founding year. Confidence: medium. |
| 2001–2005 | CyberCars project | `HISTORICAL_IMARA` | The [IMARA 2003 report](https://radar.inria.fr/rapportsactivite/RA2003/imara/imara.pdf) records CyberCars as a four-year European project running 2001–2005. The [IMARA 2004 report](https://radar.inria.fr/rapportsactivite/RA2004/imara/imara.pdf) describes B2, conceived within CyberCars, as capable of fully automatic control and “a true Cybercar.” Confidence: high. |
| 2012 | Cybus urban demonstration | `HISTORICAL_IMARA` | [IMARA 2012 report](https://radar.inria.fr/report/2012/imara/uid76.html) describes Cybus and says it operated in La Rochelle for three months as a free transport service. Confidence: high. |
| 2014–2015 | RITS project-team | `HISTORICAL_RITS` | [RITS 2020 report](https://radar.inria.fr/report/2020/rits/uid0.html) records creation on 17 February 2014 and conversion to project-team on 1 July 2015. Confidence: high. |
| 2022 | ASTRA joint team | `CURRENT_ASTRA` | [Inria’s ASTRA article](https://www.inria.fr/fr/inria-valeo-mobilite-intelligente-vehicules-autonomes) dates the joint team to February 2022; the [2025 ASTRA report](https://radar.inria.fr/report/2025/astra/index.html) identifies the former RITS team as one of its contributing entities. Confidence: high. |

## Terminology and safety decisions

- Praxitèle is described as a programme, not a project-team.
- The public 1997 IMARA milestone uses a secondary academic source because no Inria archive source located in this review states the founding year. Its wording is limited to the source’s claim; the source limitation is not rendered publicly.
- Cybus is rendered as a historical demonstrator and service context; the site does not assert a sensor suite or current availability from these sources.
- “Cybercars” is treated as a historical platform family/service context, not one standardized vehicle.
- No formal IMARA-to-RITS transition date is published: the sources separately establish IMARA’s 2011 transition and RITS’ 2014 creation, but do not establish an exact institutional handover in the evidence used here.
- ASTRA is never described as having performed historic work. It is presented as the current joint Inria–Valeo team building on a broader Inria research heritage.

## Research relationship data

The data in `_data/scientific_heritage.yml` stores bibliography keys only. The
Selected Works renderer reads title, year and venue from `rits-astra.bib` at
build time, avoiding duplicate citation metadata. Related outputs use existing
output IDs only.

| Axis | Bibliography keys | Output IDs |
| --- | --- | --- |
| Perception | `cao:hal-04324930`, `cao:hal-03945327`, `cao:hal-04986162` | `pasco`, `scenerf`, `poda`, `weather-simulator` |
| Localization & mapping | `alsayed:hal-01202038`, `alsayed:hal-01829091` | none published in this phase |
| Decision, planning & control | `essalmi:hal-04758582`, `garrido:hal-03058689`, `garrido:hal-01356691` | none published in this phase |
| Large-scale mobility | `martin:hal-01094376`, `soua:hal-01878153`, `garrido:hal-01356691` | none published in this phase |

## Rejected or deferred claims

- No historic photos were added: provenance and reuse rights were not established in this audit.
- The verified 2011 IMARA leadership transition (Michel Parent’s retirement and Fawzi Nashashibi becoming team leader) remains documented in the prior source review but is deliberately omitted from the public timeline so it remains a scientific and experimental progression.
- No claims about a current Université Laval, TUM, SystemX or other collaboration were added because current activity/classification was not verified for this phase.
- No extra ASTRA milestone was added beyond the verified 2022 creation date.
