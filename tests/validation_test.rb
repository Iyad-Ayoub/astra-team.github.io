require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../scripts/validate_site'

class ValidationTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('astra-validator-')
    (SiteValidation::REQUIRED_ROUTES + SiteValidation::PHASE2_ROUTES).each do |route|
      path = File.join(@dir, route)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, '<html><body id="top">Baseline</body></html>')
    end
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def home(text)
    File.write(File.join(@dir, 'index.html'), text)
  end

  def test_root_and_subpath_links
    ['', '/preview'].each do |base|
      home("<a href='#{base}/team/'>Team</a><a href='#{base}/research/#top'>Research</a>")
      SiteValidation.artifact(@dir, base)
    end
  end

  def test_missing_link_and_fragment
    ['/missing/', '/team/#missing'].each do |link|
      home("<a href='#{link}'>Link</a>")
      assert_raises(RuntimeError) { SiteValidation.artifact(@dir) }
    end
  end

  def test_srcset_is_checked
    home('<img srcset="/missing.png 1x, /other.png 2x">')
    assert_raises(RuntimeError) { SiteValidation.artifact(@dir) }
  end

  def test_subpath_escape_is_rejected
    home('<a href="/team/">Team</a>')
    assert_raises(RuntimeError) { SiteValidation.artifact(@dir, '/preview') }
  end

  def test_forbidden_files
    %w[scripts/tool.py Dockerfile deploy.sh Gemfile.lock .env _.htpasswd assets/jsconfig.json].each do |path|
      assert SiteValidation.forbidden_path?(path), path
    end
    File.write(File.join(@dir, 'deploy.sh'), 'echo unsafe')
    assert_raises(RuntimeError) { SiteValidation.artifact(@dir) }
  end

  def test_secret_and_host_are_rejected_without_value_output
    ['AIza' + 'A' * 35, ['polyfill', 'io'].join('.')].each do |value|
      home(value)
      error = assert_raises(RuntimeError) { SiteValidation.artifact(@dir) }
      refute_includes error.message, value
    end
  end

  def test_duplicate_and_malformed_yaml
    assert_raises(RuntimeError) do
      SiteValidation.yaml_nodes(Psych.parse_stream("name: first\nname: second\n"), 'fixture')
    end
    assert_raises(Psych::SyntaxError) { Psych.parse_stream('items: [') }
  end

  def test_missing_route
    File.unlink(File.join(@dir, 'research/index.html'))
    assert_raises(RuntimeError) { SiteValidation.artifact(@dir) }
  end

  def test_missing_phase2_route
    File.unlink(File.join(@dir, 'research/vision/index.html'))
    assert_raises(RuntimeError) { SiteValidation.artifact(@dir) }
  end

  def test_structured_record_contract
    SiteValidation.records([])
    SiteValidation.records([{ 'id' => 'fixture', 'title' => 'Test', 'url' => '/outputs/' }])
    assert_raises(RuntimeError) { SiteValidation.records({}) }
    assert_raises(RuntimeError) { SiteValidation.records([{ 'title' => 'No ID' }]) }
    record = { 'id' => 'fixture', 'title' => 'Test' }
    assert_raises(RuntimeError) { SiteValidation.records([record, record]) }
    assert_raises(RuntimeError) { SiteValidation.records([record.merge('url' => 'javascript:void(0)')]) }
  end

  def test_research_boundaries_and_navigation
    root = SiteValidation::ROOT
    navigation = YAML.safe_load_file(File.join(root, '_data/navigation.yml'))
    assert_equal %w[/ /research/ /projects/ /team/ /publications/ /outputs/ /platforms/ /news/ /about/], navigation.map { |item| item['url'] }
    axes = Dir[File.join(root, '_research_axes/*.md')].map { |path| SiteValidation.front_matter(path) }
    assert_equal %w[perception mapping decision cooperative cross-cutting], axes.sort_by { |axis| axis['order'] }.map { |axis| axis['content_id'] }
    assert_equal 4, axes.count { |axis| axis['axis_group'] == 'core' }
    assert_equal 1, axes.count { |axis| axis['axis_group'] == 'cross_cutting' }
    vision = SiteValidation.front_matter(File.join(root, '_pages/research/vision.md'))
    assert_equal 'scientific_vision', vision['content_type']
    assert_equal '/research/vision/', vision['permalink']
  end

  def test_desktop_more_group_preserves_mobile_navigation
    navigation = YAML.safe_load_file(File.join(SiteValidation::ROOT, '_data/navigation.yml'))
    more = navigation.select { |item| item['desktop_group'] == 'more' }
    primary = navigation.reject { |item| item['desktop_group'] == 'more' }
    assert_equal %w[/ /research/ /projects/ /team/ /publications/], primary.map { |item| item['url'] }
    assert_equal %w[/outputs/ /platforms/ /news/ /about/], more.map { |item| item['url'] }
    assert_equal 9, navigation.size
  end
end
