---
layout: page
title: Research Outputs & Resources
permalink: /outputs/
content_type: outputs_index
groups:
  - group: featured
    id: featured-software
    title: Featured Software & Models
  - group: additional
    id: additional-software
    title: Open-Source Research Software
  - group: datasets
    id: datasets
    title: Datasets
  - group: frameworks
    id: frameworks
    title: Frameworks & Experimental Tools
---

{% for group in page.groups %}
{% assign records = site.data.outputs | where: 'group', group.group %}
<section aria-labelledby="{{ group.id }}">
<h2 id="{{ group.id }}" class="h3">{{ group.title | escape }}</h2>
{% include structured_records.html records=records %}
</section>
{% endfor %}
