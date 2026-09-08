---
layout: page
title: Research Outputs & Resources
permalink: /outputs/
content_type: outputs_index
---

{% assign featured = site.data.outputs | where: 'group', 'featured' %}
{% assign additional = site.data.outputs | where: 'group', 'additional' %}
<section aria-labelledby="featured-software">
<h2 id="featured-software" class="h3">Featured research software</h2>
{% include structured_records.html records=featured %}
</section>
<section aria-labelledby="additional-software">
<h2 id="additional-software" class="h3">Additional research software</h2>
<p class="astra-meta">This grouping reflects mobility relevance, not scientific quality.</p>
{% include structured_records.html records=additional %}
</section>
