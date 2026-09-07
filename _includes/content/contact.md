<!-- pages/info.md -->

## About ASTRA

{% include content/about-astra.md %}

## Contact

For general requests, please contact our team assistant: [Martial Le-Henaff](mailto:martial.le-henaff@inria.fr)

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
