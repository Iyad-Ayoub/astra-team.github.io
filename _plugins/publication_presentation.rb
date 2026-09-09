require 'jekyll/scholar'
require 'uri'
require 'cgi'
require 'date'

# A view over Scholar's existing parsed entries; never writes bibliography data.
module AstraPublications
  TYPE_MAP = {
    'article' => 'Journal', 'inproceedings' => 'Conference', 'conference' => 'Conference',
    'unpublished' => 'Preprint', 'preprint' => 'Preprint',
    'phdthesis' => 'Thesis', 'mastersthesis' => 'Thesis', 'thesis' => 'Thesis',
    'techreport' => 'Technical Report', 'book' => 'Book / Chapter',
    'inbook' => 'Book / Chapter', 'incollection' => 'Book / Chapter'
  }.freeze
  TYPES = (TYPE_MAP.values.uniq + ['Other']).freeze

  def self.safe_url(value)
    value = value.to_s.strip
    uri = URI.parse(value)
    value if %w[http https].include?(uri.scheme) && uri.host && !uri.userinfo && !value.match?(/[<>"\s]/)
  rescue URI::InvalidURIError
    nil
  end

  def self.hal_url(entry)
    url = safe_url(entry[:url])
    if url
      host = URI.parse(url).host.downcase
      return url if host.match?(/\A(?:[a-z0-9-]+\.)*(?:hal\.science|archives-ouvertes\.fr)\z/)
    end
    id = entry[:hal_id].to_s.strip
    "https://hal.science/#{id}" if id.match?(/\A(?:hal|halshs|tel)-\d+(?:v\d+)?\z/)
  end

  def self.doi_url(value)
    doi = value.to_s.strip.sub(%r{\Ahttps?://(?:dx\.)?doi\.org/}i, '').sub(/\Adoi:\s*/i, '')
    return unless doi.match?(%r{\A10\.\d{4,9}/\S+\z})
    # Encode path delimiters such as # and ? as DOI content, not URL controls.
    'https://doi.org/' + doi.split('/').map { |part| URI.encode_www_form_component(part).gsub('+', '%20') }.join('/')
  end

  def self.view(entry, display)
    month = entry[:month].to_s.downcase.strip
    number = if month.match?(/\A(?:0?[1-9]|1[0-2])\z/)
               month.to_i
             else
               Date::MONTHNAMES.index { |name| name && [name.downcase, name[0, 3].downcase].include?(month) }
             end
    venue = %w[journal booktitle school institution publisher howpublished].filter_map { |key| display[key] unless display[key].to_s.strip.empty? }.first
    {
      'type' => TYPE_MAP.fetch(entry.type.to_s.downcase, 'Other'),
      'year' => entry[:year].to_s,
      'date' => [number && Date::MONTHNAMES[number], entry[:year].to_s].compact.join(' '),
      'venue' => venue,
      'hal' => hal_url(entry), 'pdf' => safe_url(entry[:pdf]), 'doi' => doi_url(entry[:doi])
    }
  end

  class BibliographyTag < Jekyll::Scholar::BibliographyTag
    def render(context)
      set_context_to(context)
      update_dependency_tree
      items = cited_entries
      groups = items.group_by { |entry| entry[:year].to_s }
      years = groups.keys.sort.reverse
      context['publication_count'] = items.size
      context['publication_years'] = years
      context['publication_types'] = TYPES
      years.map do |year|
        entries = groups.fetch(year)
        label = CGI.escapeHTML(year)
        count = entries.size
        "<section class=\"publication-year\" data-year=\"#{label}\" aria-labelledby=\"publications-#{label}\">" \
          "<h2 id=\"publications-#{label}\">#{label}</h2>" \
          "<p class=\"astra-meta publication-year-count\">#{count} #{count == 1 ? 'publication' : 'publications'}</p>" \
          "#{render_items(entries)}</section>"
      end.join("\n")
    end

    def reference_data(entry, index = nil)
      data = super
      data['publication'] = AstraPublications.view(entry, data['entry'])
      data
    end
  end
end

Liquid::Template.register_tag('astra_bibliography', AstraPublications::BibliographyTag)
