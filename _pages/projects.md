---
layout: page
title: Projects
permalink: /projects/
content_type: projects_index
groups:
  - status: ongoing
    title: Current Projects
  - status: completed
    title: Completed Projects
---

{% assign all_projects = site.projects | sort: 'order' %}
{% for group in page.groups %}
{% assign projects = all_projects | where: 'status', group.status %}
<section aria-labelledby="{{ group.status }}-projects">
<h2 id="{{ group.status }}-projects">{{ group.title }}</h2>
{% if projects.size > 0 %}
<ul class="list-unstyled astra-project-list">
  {% for project in projects %}
  <li class="border-bottom">
    {% assign title_parts = project.title | split: ' — ' %}
    <h3><a href="{{ project.url | relative_url }}"><strong>{{ project.acronym | escape }}</strong>{% if title_parts.size > 1 %} — {{ title_parts | shift | join: ' — ' | escape }}{% endif %}</a></h3>
    <p class="astra-meta">{{ project.status | capitalize | escape }}{% if project.start_date %} · {% include project_date.html value=project.start_date %}{% if project.end_date %} – {% include project_date.html value=project.end_date %}{% endif %}{% endif %}</p>
    <p class="astra-meta">{% include project_classification.html project=project %}</p>
    <p>{{ project.summary | escape }}</p>
  </li>
  {% endfor %}
</ul>
{% else %}
Content currently being prepared.
{% endif %}
</section>
{% endfor %}
