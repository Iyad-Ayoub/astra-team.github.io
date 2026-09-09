---
layout: page
title: Team
permalink: /team/
nav: true
nav_order: 2
groups:
  - category: leadership
    title: Scientific Leadership
  - category: permanent
    title: Permanent Researchers
  - category: industrial
    title: Associate / Industrial Research Members
  - category: associates
    title: Associated Researchers & Engineers
  - category: phd
    title: PhD Students
  - category: administration
    title: Administrative Support
---

<div class="astra-team">
{% assign current = site.data.team_roster | where: 'status', 'current' | sort: 'display_order' %}
{% for group in page.groups %}
{% assign members = current | where: 'category', group.category %}
{% if members.size > 0 %}
<section aria-labelledby="team-{{ group.category }}" class="astra-team-section{% if group.category == 'leadership' %} astra-team-leadership{% endif %}">
<h2 id="team-{{ group.category }}">{{ group.title | escape }}</h2>
<ul class="astra-people">
{% for member in members %}{% include team/member.html member=member %}{% endfor %}
</ul>
</section>
{% endif %}
{% endfor %}

{% assign alumni = site.data.team_roster | where: 'status', 'alumni' | sort: 'display_order' %}
{% if alumni.size > 0 %}
<section class="astra-team-section astra-team-alumni" aria-labelledby="team-alumni">
<h2 id="team-alumni">Alumni &amp; Former Members</h2>
<ul class="astra-people">
{% for member in alumni %}{% include team/member.html member=member %}{% endfor %}
</ul>
</section>
{% endif %}
</div>
