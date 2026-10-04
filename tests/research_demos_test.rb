require 'minitest/autorun'
require 'yaml'
require_relative '../scripts/validate_site'

class ResearchDemosTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def setup
    @demo = YAML.safe_load_file(File.join(ROOT, '_data/research_demos.yml')).find { |record| record['id'] == 'revamp' }
    @include = File.read(File.join(ROOT, '_includes/research_demos.html'))
    @axis = File.read(File.join(ROOT, '_research_axes/decision.md'))
    @overview = File.read(File.join(ROOT, '_pages/research.md'))
  end

  def test_revamp_has_only_verified_demo_metadata
    refute_nil @demo
    assert_equal 'REVAMP', @demo['title']
    assert_equal 'Reversible Lookahead', @demo['subtitle']
    assert_equal 'Research Demo', @demo['type']
    assert_equal 'decision', @demo['related_axis']
    assert_equal 'https://islemkobbi.github.io/revamp_demo/', @demo['demo_url']
    assert_equal ['Islem Kobbi', 'Tiago Rocha Goncalves', 'Fawzi Nashashibi'], @demo['researchers']
    SiteValidation.records([@demo.merge('title' => @demo['title'])])
  end

  def test_demo_surface_is_reusable_and_connected_to_overview_and_axis_three
    assert_includes @overview, '{% include research_demos.html %}'
    assert_includes @include, "where: 'related_axis', include.axis"
    assert_includes @include, '>Research Demos</h2>'
    assert_includes @include, 'View demo'
    assert_includes @axis, 'content_id: decision'
    refute_includes @overview, 'revamp'
    refute_includes @axis, 'revamp'
  end

  def test_demo_is_not_added_to_projects_platforms_or_navigation
    refute_includes File.read(File.join(ROOT, '_data/navigation.yml')), 'research-demos'
    refute_includes File.read(File.join(ROOT, '_pages/projects.md')), 'revamp'
    refute_includes File.read(File.join(ROOT, '_pages/platforms.md')), 'revamp'
  end
end
