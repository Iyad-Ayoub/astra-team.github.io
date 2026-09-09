---
layout: page
permalink: /publications/
title: Publications
description: 
nav: true
nav_order: 3
---
<!-- _pages/publications.md -->
<div class="publications astra-publications">

<p>ASTRA publications are synchronized from <a href="https://inria.hal.science">HAL</a>. Recent records may appear after HAL indexing and synchronization.</p>


{% capture publication_archive %}{% astra_bibliography -f rits-astra %}{% endcapture %}
<p id="publication-count" role="status" aria-live="polite" aria-atomic="true" data-total="{{ publication_count }}">{{ publication_count }} publications</p>
{% include bib_search.liquid %}
<p id="publication-empty" hidden>No publications match the current search and filters.</p>

{{ publication_archive }}

</div>
