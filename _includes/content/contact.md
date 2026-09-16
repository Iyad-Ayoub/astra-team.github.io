<!-- pages/info.md -->

## About ASTRA

{% include content/about-astra.md %}

## Scientific Heritage

ASTRA builds on a longer Inria research heritage in intelligent transportation systems, automated vehicles and autonomous mobility. Earlier programmes and project-teams developed experimental automated vehicles, urban-transport concepts, vehicle guidance and mobility-system research. ASTRA continues this scientific trajectory today as a joint Inria–Valeo research team with its own current research programme.

<section class="astra-heritage" aria-labelledby="scientific-heritage">
  <ol class="astra-heritage-timeline">
  {% for milestone in site.data.scientific_heritage.timeline %}
    <li class="astra-heritage-milestone{% if milestone.classification == 'CURRENT_ASTRA' %} astra-heritage-current{% endif %}">
      <p class="astra-heritage-year">{{ milestone.year | escape }}</p>
      <h3>{{ milestone.title | escape }}</h3>
      <p>{{ milestone.summary | escape }}</p>
      {% if milestone.classification != 'CURRENT_ASTRA' %}<span class="astra-historical-label">Historical</span>{% endif %}
    </li>
  {% endfor %}
  </ol>
</section>

ASTRA today brings this heritage into a current programme across multimodal perception, localization and mapping, decision-making and control, and large-scale mobility systems.

## Contact

For general requests, please contact our team assistant: [Christelle Leclerc](mailto:krystel.leclerc@inria.fr).

For scientific inquiries, please contact Inria team leader: [Fawzi Nashashibi](mailto:fawzi.nashashibi@inria.fr)

<ul class="fa-ul">
 <li>
        <i class="fa-li fas fa-map-marker fa-1x" aria-hidden="true"></i>
        <span id="person-address">48 rue Barrault, Paris, 75013</span>
      </li>
    <li>
      <i class="fa-li fas fa-compass fa-1x" aria-hidden="true"></i>
      <span>We're located at the ground floor of building C.</span>
    </li>
</ul>


{% leaflet_map {"zoom" : 11 } %}
    {% leaflet_marker { "latitude" : 48.826460766243315,
                       "longitude" : 2.3463726313050013,
                       "popupContent" : "Inria"} %}
{% endleaflet_map %}
