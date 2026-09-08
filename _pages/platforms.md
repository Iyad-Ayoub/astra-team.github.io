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
