---
layout: page
title: News & Events
permalink: /news/
content_type: news_index
---

{% assign items = site.news | sort: 'date' | reverse %}
{% if items.size > 0 %}
{% for item in items %}
<section>
  <h2><a href="{{ item.url | relative_url }}">{% if item.title %}{{ item.title | escape }}{% else %}{{ item.date | date: '%B %-d, %Y' }}{% endif %}</a></h2>
  {% if item.title %}<p><time datetime="{{ item.date | date_to_xmlschema }}">{{ item.date | date: '%B %-d, %Y' }}</time></p>{% endif %}
  {% if item.inline %}{{ item.content | markdownify }}{% endif %}
</section>
{% endfor %}
{% else %}
Content currently being prepared.
{% endif %}
