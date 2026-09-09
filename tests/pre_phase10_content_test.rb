require 'minitest/autorun'
require 'nokogiri'
require 'kramdown'
require_relative '../scripts/validate_site'

class PrePhase10ContentTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  TITLE = 'Large-Scale Mobility Systems'
  SUMMARY = 'Modelling, analysing and coordinating transportation systems at vehicle, fleet and network scales, including traffic dynamics, infrastructure interaction and connected mobility.'

  def test_source_and_alumni_boundary
    axis = SiteValidation.front_matter(File.join(ROOT, '_research_axes/cooperative.md'))
    assert_equal TITLE, axis['title']
    assert_equal SUMMARY, axis['summary']
    assert_equal 'cooperative', axis['content_id']
    roster = YAML.safe_load_file(File.join(ROOT, '_data/team_roster.yml'))
    assert_equal ['current', 'Team Assistant'], roster.find { |p| p['id'] == 'christelle-leclerc' }.values_at('status', 'role')
    assert_equal ['alumni', 'Former Team Assistant'], roster.find { |p| p['id'] == 'martial-le-henaff' }.values_at('status', 'role')
  end

  def test_rendered_copy_contacts_and_compatibility
    destination = ENV['PRE10_SITE']
    skip 'Set PRE10_SITE for artifact validation' unless destination
    base = ENV.fetch('PRE10_BASEURL', '')
    doc = Nokogiri::HTML(File.read(File.join(destination, 'research/cooperative/index.html')))
    assert_equal TITLE, doc.at_css('h1').text
    assert_includes doc.at_css('title').text, TITLE
    # Compare every approved paragraph/topic to source; source is independently hash-pinned.
    source = File.read(File.join(ROOT, '_research_axes/cooperative.md')).split(/^---\s*$\n?/, 3).last
    expected = Nokogiri::HTML.fragment(Kramdown::Document.new(source).to_html)
    expected.css('p, li').reject { |n| n.text.include?('Back to Research') }.each do |node|
      assert_includes doc.at_css('article').text, node.text
    end
    ['index.html', 'research/index.html'].each do |file|
      page = Nokogiri::HTML(File.read(File.join(destination, file)))
      assert_includes page.text, SUMMARY
      labels = page.css("a[href='#{base}/research/cooperative/']").map { |a| a.css('[aria-hidden="true"]').remove; a.text.strip }
      assert_includes labels, TITLE
    end
    %w[about info].each do |route|
      page = Nokogiri::HTML(File.read(File.join(destination, route, 'index.html')))
      contact = page.at_css('a[href="mailto:krystel.leclerc@inria.fr"]')
      refute_nil contact
      assert_equal 'Christelle Leclerc', contact.text
      assert_equal 'For general requests, please contact our team assistant: Christelle Leclerc.', contact.parent.text.strip
    end
    Dir[File.join(destination, '**/*.html')].each do |file|
      page = Nokogiri::HTML(File.read(file))
      refute_includes page.text, 'Cooperative & Connected Autonomous Systems', file
      refute_includes File.read(file).downcase, 'martial.le-henaff@inria.fr', file
      page.css('a[href*="/research/cooperative/"]').each { |a| a.css('[aria-hidden="true"]').remove; assert_equal TITLE, a.text.strip }
    end
    team = Nokogiri::HTML(File.read(File.join(destination, 'team/index.html')))
    assert_includes team.at_css('.astra-team-alumni #martial-le-henaff').text, 'Former Team Assistant'
    assert_empty team.css('[data-status="current"]#martial-le-henaff')
  end
end
