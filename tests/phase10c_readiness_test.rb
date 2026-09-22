require 'minitest/autorun'
require 'jekyll'
require 'nokogiri'
require 'yaml'
require_relative '../_plugins/indexing_policy'

class Phase10CReadinessTest < Minitest::Test
  SUMMARIES = {
    'perception' => 'Understanding complex road environments through robust visual and multimodal perception.',
    'mapping' => 'Reliable localization, mapping and spatial representations for autonomous mobility.',
    'decision' => 'Anticipating traffic situations and translating them into safe decisions, trajectories and vehicle control.',
    'cooperative' => 'Modelling and coordinating transportation systems at vehicle, fleet and network scales.'
  }.freeze

  def test_context_policy
    refute AstraIndexing.staging?('', 'production')
    refute AstraIndexing.staging?('', nil)
    assert AstraIndexing.staging?('', 'staging'), 'A root-hosted fork must also be noindex'
    assert AstraIndexing.staging?('/astra-team.github.io', nil)
    assert AstraIndexing.staging?('/astra-team.github.io', 'staging')
    assert_raises(RuntimeError) { AstraIndexing.staging?('/astra-team.github.io', 'production') }
    assert_raises(RuntimeError) { AstraIndexing.staging?('', 'typo') }
    assert_equal SUMMARIES, YAML.safe_load_file(File.expand_path('../_data/home_research.yml', __dir__))
  end

  def test_artifact
    dest = ENV['PHASE10_SITE']
    skip 'Set PHASE10_SITE for generated checks' unless dest
    base = ENV.fetch('PHASE10_BASEURL', '')
    staging = AstraIndexing.staging?(base)
    files = Dir[File.join(dest, '**/*.html')].reject { |file| file.include?('/admin/') }
    routes = files.map { |file| '/' + file.delete_prefix(dest + '/').sub(/index\.html\z/, '') }
    %w[legal privacy accessibility].each { |route| assert_includes routes, "/#{route}/" }
    files.each do |file|
      html = File.read(file)
      doc = Nokogiri::HTML(html)
      robots = doc.css('meta[name="robots"]')
      staging ? assert_equal(['noindex, follow'], robots.map { |n| n['content'] }, file) : assert_empty(robots, file)
      %w[legal privacy accessibility].each do |route|
        assert_equal 1, doc.css("footer a[href='#{base}/#{route}/']").size, file
      end
      assert_includes doc.at_css('footer').text, 'ASTRA — joint Inria–Valeo research team'
      assert_match(/© Copyright \d{4} Astra team\./, doc.at_css('footer').text)
      refute_match(/martial.le-henaff@inria.fr|googletagmanager|google-analytics|cdn.panelbear.com/i, html, file)
    end
    home = Nokogiri::HTML(File.read(File.join(dest, 'index.html')))
    cards = home.css('.astra-research-card')
    assert_equal 4, cards.size
    SUMMARIES.each do |id, summary|
      card = cards.find { |c| c.at_css("a[href='#{base}/research/#{id}/']") }
      refute_nil card
      assert_equal [summary], card.css('p').map { |n| n.text.strip }
    end
    alias_page = Nokogiri::HTML(File.read(File.join(dest, 'info/index.html')))
    assert_equal 'https://astra-team.github.io/about/', alias_page.at_css('link[rel="canonical"]')['href']
    xml = Nokogiri::XML(File.read(File.join(dest, 'sitemap.xml'))) { |c| c.strict }
    urls = xml.xpath('//*[local-name()="loc"]').map(&:text)
    expected = (routes - ['/info/', '/404.html']).map { |r| 'https://astra-team.github.io' + r }
    assert_equal expected.sort, urls.sort
    assert_equal urls.uniq, urls
    refute urls.any? { |u| u.include?('2022-07-01-astra-creation') }
    robots = File.read(File.join(dest, 'robots.txt'))
    assert_match(/^Disallow:\s*$/, robots)
    staging ? refute_includes(robots, 'Sitemap:') : assert_includes(robots, 'Sitemap: https://astra-team.github.io/sitemap.xml')
    privacy = Nokogiri::HTML(File.read(File.join(dest, 'privacy/index.html')))
    assert_includes privacy.text, 'No audience-measurement or advertising trackers are currently enabled by ASTRA on this website.'
    assert_includes privacy.text, 'no user accounts or contact form'
    assert_includes privacy.text, 'ASTRA does not directly control GitHub’s logs'
    assert privacy.at_css('a[href="mailto:dpo@inria.fr"]')
    legal = Nokogiri::HTML(File.read(File.join(dest, 'legal/index.html'))).at_css('article').text
    assert_includes legal, 'publication director for this ASTRA website remains subject to institutional confirmation'
    assert_includes legal, 'GitHub Pages'
    refute_match(/WordPress|Automattic|hosted by Inria/, legal)
    accessibility = Nokogiri::HTML(File.read(File.join(dest, 'accessibility/index.html'))).at_css('article').text
    assert_includes accessibility, 'This notice does not claim RGAA compliance or partial compliance.'
    refute_match(/\d+(?:[.,]\d+)?\s*%/, accessibility)
    %w[legal privacy accessibility about info].each do |route|
      doc = Nokogiri::HTML(File.read(File.join(dest, route, 'index.html')))
      assert_equal 'Christelle Leclerc', doc.at_css('a[href="mailto:krystel.leclerc@inria.fr"]').text
    end
  end
end
