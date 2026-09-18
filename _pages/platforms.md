---
layout: page
title: Platforms & Demonstrators
permalink: /platforms/
content_type: platforms_index
---

ASTRA develops and evaluates autonomous-driving technologies using experimental vehicles, research platforms, and demonstrators developed within Inria and in collaboration with Valeo.

{% assign current_records = site.data.platforms | where: 'temporal_status', 'current' %}
{% assign unverified_inria_records = site.data.platforms | where: 'temporal_status', 'status_unverified' %}
{% assign partner_records = site.data.platforms | where: 'relationship', 'valeo_partner' %}
{% assign historical_records = site.data.platforms | where: 'relationship', 'inria_historical_heritage' %}

<section aria-labelledby="current-astra-inria-platforms">
<h2 id="current-astra-inria-platforms">Current ASTRA / Inria Platforms</h2>
<p>ASTRA’s current experimental platform includes the Renault Zoé autonomous research vehicle used for perception, localization, and autonomous-driving experiments.</p>
{% include platform_records.html records=current_records %}
</section>

<section aria-labelledby="documented-inria-inventory">
<h2 id="documented-inria-inventory">Other Inria Research Platforms</h2>
<p>ASTRA has also used other Inria experimental vehicles in its autonomous-driving research activities.</p>
{% include platform_records.html records=unverified_inria_records %}
</section>

<section aria-labelledby="valeo-partner-demonstrators">
<h2 id="valeo-partner-demonstrators">Valeo / Partner Demonstrators</h2>
<p>ASTRA’s collaboration with Valeo also connects the team with several automated-driving demonstrators and autonomous mobility platforms.</p>
{% include platform_records.html records=partner_records %}
</section>

<section class="astra-experimental-heritage" aria-labelledby="experimental-heritage">
<h2 id="experimental-heritage">Experimental Heritage</h2>
<p>ASTRA builds on a long history of Inria research in autonomous vehicles and intelligent transportation systems.</p>
{% include platform_records.html records=historical_records %}
</section>
