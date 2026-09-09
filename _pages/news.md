---
layout: page
title: News & Events
permalink: /news/
content_type: news_index
---

<div class="astra-news-archive">
<p>News, events and selected scientific highlights from the ASTRA research team, including awards, conferences, project milestones, open-source releases and team achievements.</p>
<p class="astra-meta">Items with known dates appear first within each year; year-only highlights follow without implying an exact event order.</p>
{% assign years = site.news_archive | group_by: 'news_year' %}
{% for year in years %}
<section aria-labelledby="news-year-{{ year.name }}">
  <h2 id="news-year-{{ year.name }}">{{ year.name }}</h2>
  <ul class="astra-news-list">{% for item in year.items %}{% include news/row.html item=item %}{% endfor %}</ul>
</section>
{% endfor %}
{% if site.news_legacy.size > 0 %}
<section aria-labelledby="news-legacy">
  <h2 id="news-legacy">Earlier team announcements</h2>
  <p class="astra-meta">Preserved from the previous website; historical details await editorial review.</p>
  <ul class="astra-news-list">{% for item in site.news_legacy %}{% include news/row.html item=item %}{% endfor %}</ul>
</section>
{% endif %}
</div>
