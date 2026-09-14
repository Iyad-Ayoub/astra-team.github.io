require 'minitest/autorun'
require 'jekyll'
require 'nokogiri'
require 'yaml'
require_relative '../_plugins/release_metadata'
require_relative '../_plugins/publication_presentation'

class Phase10ReleaseTest < Minitest::Test
  FILTER = Object.new.extend(AstraRelease::Filters)
  ROOT = File.expand_path('..', __dir__)

  def test_canonical_and_profile_policy
    %w[/about/ /about/index.html /about/?x=1#anchor //about///].each do |route|
      assert_equal 'https://astra-team.github.io/about/', FILTER.astra_canonical(route, 'https://astra-team.github.io/')
    end
    %w[http://astra-team.github.io https://localhost https://iyad-ayoub.github.io].each do |host|
      assert_raises(RuntimeError) { FILTER.astra_canonical('/', host) }
    end
    AstraRelease::BROKEN_PROFILES.each { |url| assert_nil FILTER.astra_profile_url(url) }
    assert_equal 'https://weihaox.github.io/DREAM', FILTER.astra_profile_url('https://weihaox.github.io/DREAM')
    assert_equal 'https://doi.org/10.1007/978-3-031-39991-6_7', AstraPublications.doi_url('10.1007/978-3-031-39991-6\_7')
  end

  def test_analytics_disabled_in_configuration
    config = YAML.safe_load_file(File.join(ROOT, '_config.yml'))
    assert_equal false, config['enable_google_analytics']
    assert_equal false, config['enable_panelbear_analytics']
  end

  def test_description_uses_existing_prose_and_complete_sentences
    site = Struct.new(:data).new({})
    first = 'This existing project summary provides a complete factual sentence.'
    item = Struct.new(:data, :site, :url, :content).new({'summary' => first + ' ' + ('Further existing description ' * 20)}, site, '/projects/test/', '')
    assert_equal first, AstraRelease.description(item)
    item.data = {}
    item.url = '/research/test/'
    item.content = "## Heading\n\n#{first}\n\n{% include links.html %}"
    assert_equal first, AstraRelease.description(item)
  end

  def test_public_artifact
    dest = ENV['PHASE10_SITE']
    skip 'Set PHASE10_SITE to validate generated HTML' unless dest
    files = Dir[File.join(dest, '**/*.html')]
    assert_equal 36, files.size
    descriptions = []
    files.each do |file|
      html = File.read(file)
      doc = Nokogiri::HTML(html)
      refute_match(/googletagmanager|google-analytics|\bG-[A-Z0-9]{6,}\b/i, html, file)
      route = '/' + file.delete_prefix(dest + '/').sub(/index\.html\z/, '')
      route = '/about/' if route == '/info/'
      canonicals = doc.css('link[rel="canonical"]')
      assert_equal 1, canonicals.size, file
      assert_equal 'https://astra-team.github.io' + route, canonicals.first['href'], file
      nodes = doc.css('meta[name="description"]')
      assert_equal 1, nodes.size, file
      description = nodes.first['content']
      assert_operator description.size, :>=, 35, file
      assert_operator description.size, :<=, 220, file
      descriptions << description
      refute_match(/join research|\{%|\{\{/, description)
      doc.css('a[href]').each { |a| refute_includes AstraRelease::BROKEN_PROFILES, a['href'] }
      refute_includes html, '978-3-031-39991-6%5C_7'
      refute_includes doc.at_css('footer').text, 'Powered by'
    end
    assert_equal descriptions.size, descriptions.uniq.size
    refute File.exist?(File.join(dest, 'news/2022-07-01-astra-creation/index.html'))
    biography = Nokogiri::HTML(File.read(File.join(dest, 'team/fawzi-nashashibi.html')))
    assert_equal 1, biography.css('h1').size
    assert_includes biography.at_css('article').text, 'ASTRA Team Leader'
    assert_includes biography.at_css('article').text, 'Senior Researcher / HDR, Inria'
    refute_match(/50 years|since 2010|Program Manager|international expert/, biography.text)
    pub = Nokogiri::HTML(File.read(File.join(dest, 'publications/index.html')))
    # A future validated HAL corpus need not retain this individual entry.
    # When present in the displayed BibTeX, its corrected action is mandatory.
    if pub.text.include?('978-3-031-39991-6')
      refute_nil pub.at_css('a[href="https://doi.org/10.1007/978-3-031-39991-6_7"]')
    end
  end
end
