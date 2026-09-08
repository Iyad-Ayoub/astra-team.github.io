---
layout: page
title: Projects
permalink: /projects/
content_type: projects_index
---

{% assign projects = site.projects | sort_natural: 'title' %}
{% if projects.size > 0 %}
<ul class="list-unstyled astra-project-list">
  {% for project in projects %}
  <li class="border-bottom">
    {% assign title_parts = project.title | split: ' — ' %}
    <h2><a href="{{ project.url | relative_url }}"><strong>{{ title_parts | first | escape }}</strong>{% if title_parts.size > 1 %} — {{ title_parts | shift | join: ' — ' | escape }}{% endif %}</a></h2>
    <p class="astra-meta">{{ project.status | escape }}{% if project.start_date %} · {% include project_date.html value=project.start_date %}{% if project.end_date %} – {% include project_date.html value=project.end_date %}{% endif %}{% endif %}</p>
    <p>{{ project.summary | escape }}</p>
  </li>
  {% endfor %}
</ul>
{% else %}
Content currently being prepared.
{% endif %}
