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

{% assign all_projects = site.projects %}
{% assign auto_projects = all_projects | where_exp: 'project', 'project.order <= 0 or project.order == 9999' | sort: 'order' %}
{% assign curated_projects = all_projects | where_exp: 'project', 'project.order > 0 and project.order != 9999' | sort: 'order' %}
{% assign all_projects = auto_projects | concat: curated_projects %}
{% for group in page.groups %}
{% assign projects = all_projects | where: 'status', group.status %}
<section aria-labelledby="{{ group.status }}-projects">
<h2 id="{{ group.status }}-projects">{{ group.title }}</h2>
{% if projects.size > 0 %}
<ul class="list-unstyled astra-project-list">
  {% for project in projects %}
  <li class="border-bottom">
    {% assign project_acronym = project.acronym | strip %}
    {% assign project_title = project.title | strip %}
    {% assign title_prefix = project_title | slice: 0, project_acronym.size %}
    {% assign title_remainder = project_title | remove_first: project_acronym | strip %}
    <h3><a href="{{ project.url | relative_url }}"><strong>{{ project_acronym | escape }}</strong>{% if title_remainder != '' and title_prefix == project_acronym %} {{ title_remainder | escape }}{% elsif title_remainder != '' %} — {{ project_title | escape }}{% endif %}</a></h3>
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
