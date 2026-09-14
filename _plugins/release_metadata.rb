require 'uri'
require 'nokogiri'

# Presentation-only policy. Do not change historical author mappings or roster data.
module AstraRelease
  BROKEN_PROFILES = %w[https://mfahes.github.io/ https://weihaox.github.io/
                       https://who.rocq.inria.fr/Anne.Verroust/].freeze

  def self.description(item)
    data = item.data
    explicit = [data['description'], data['summary'], item.site.data.fetch('seo', {})[item.url]].find { |v| !v.to_s.strip.empty? }
    # Research bodies are approved prose. Use the first narrative sentence, not
    # headings, navigation, topic lists, or Liquid includes. Never modify the body.
    if !explicit && item.url.start_with?('/research/')
      paragraph = item.content.split(/\n\s*\n/).find { |p| p.strip.match?(/\A[A-Z]/) }
      explicit = paragraph.to_s.split(/(?<=\.)\s+/, 2).first
    end
    text = Nokogiri::HTML.fragment(explicit.to_s).text.gsub(/\s+/, ' ').strip
    return text if text.length <= 220
    sentence = text.split(/(?<=\.)\s+/, 2).first
    return sentence if sentence.length.between?(35, 220)
    text[0, 217].sub(/\s+\S*\z/, '') + '…'
  end

  module Filters
    def astra_profile_url(value)
      value unless AstraRelease::BROKEN_PROFILES.include?(value.to_s)
    end

    def astra_canonical(value, origin)
      host = URI.parse(origin.to_s)
      raise 'Canonical origin must be production HTTPS' unless host.scheme == 'https' && host.host == 'astra-team.github.io' && host.port == 443 && !host.userinfo && !host.query && !host.fragment && ['', '/'].include?(host.path)
      path = value.to_s.split(/[?#]/, 2).first.to_s
      path = '/' + path.sub(%r{\A/+}, '')
      path = path.gsub(%r{/+}, '/').sub(%r{/index\.html\z}, '/')
      # page.url is the logical route; site.baseurl is a deployment prefix only.
      'https://astra-team.github.io' + path
    end
  end
end

Liquid::Template.register_filter(AstraRelease::Filters)
Jekyll::Hooks.register [:pages, :documents], :pre_render do |item, payload|
  description = AstraRelease.description(item)
  item.data['seo_description'] = description
  # Page payloads are snapshots; Document drops read their data dynamically.
  payload['page']['seo_description'] = description
end
