---
layout: page
title: Projects
permalink: /projects/
content_type: projects_index
---

{% assign projects = site.projects | sort_natural: 'title' %}
{% if projects.size > 0 %}
<ul>
  {% for project in projects %}
  <li><a href="{{ project.url | relative_url }}">{{ project.title | escape }}</a></li>
  {% endfor %}
</ul>
{% else %}
Content currently being prepared.
{% endif %}
