---
layout: page
title: Platforms & Demonstrators
permalink: /platforms/
content_type: platforms_index
groups:
  - group: inria-astra
    title: Inria / ASTRA Experimental Platforms
  - group: valeo
    title: Valeo Partner Demonstrators
---

ASTRA’s research combines simulation with experimental validation on real vehicles and robotic platforms. Through Inria and Valeo, the team has access to a range of research vehicles, autonomous shuttles and industrial demonstrators supporting work in perception, localization, mapping, decision-making, planning and cooperative mobility.

{% for group in page.groups %}
{% assign records = site.data.platforms | where: 'group', group.group %}
<section aria-labelledby="{{ group.group }}-platforms">
<h2 id="{{ group.group }}-platforms">{{ group.title | escape }}</h2>
{% include structured_records.html records=records %}
</section>
{% endfor %}

<section class="astra-experimental-heritage" aria-labelledby="experimental-heritage">
<h2 id="experimental-heritage">Experimental Heritage</h2>
<p>These historical demonstrators provide context for earlier Inria mobility research. They are not presented as ASTRA’s current platform inventory.</p>
<ul class="list-unstyled">
{% for platform in site.data.scientific_heritage.platform_heritage %}
  <li id="{{ platform.id | escape }}" class="astra-research-card">
    <p class="astra-meta"><span class="astra-record-status">{{ platform.type | escape }}</span> · {{ platform.period | escape }}</p>
    <h3 class="h5">{{ platform.title | escape }}</h3>
    <p>{{ platform.summary | escape }}</p>
  </li>
{% endfor %}
</ul>
</section>
