require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'digest'
require_relative '../scripts/validate_site'

class ValidationTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('astra-validator-')
    (SiteValidation::REQUIRED_ROUTES + SiteValidation::PHASE2_ROUTES).each do |route|
      path = File.join(@dir, route)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, '<html><body id="top">Baseline</body></html>')
    end
    FileUtils.mkdir_p(File.join(@dir, 'assets/css'))
    File.write(File.join(@dir, 'assets/css/main.css'),
               %w[astra-hero-heading astra-button astra-intro astra-research-grid astra-card-image astra-card-heading].map { |s| ".#{s} { display: block; }" }.join("\n"))
    home('Baseline')
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def home(text, baseurl = '')
    File.write(File.join(@dir, 'index.html'),
               "<link rel='stylesheet' href='#{baseurl}/assets/css/main.css?v=20260907000000'>#{text}")
  end

  def test_root_and_subpath_links
    ['', '/preview'].each do |base|
      home("<a href='#{base}/team/'>Team</a><a href='#{base}/research/#top'>Research</a>", base)
      SiteValidation.artifact(@dir, base)
    end
  end

  def test_missing_link_and_fragment
    ['/missing/', '/team/#missing'].each do |link|
      home("<a href='#{link}'>Link</a>")
      assert_raises(RuntimeError) { SiteValidation.artifact(@dir) }
    end
  end

  def test_phase3_stylesheet_url_and_compilation
    ['', '/astra-team.github.io'].each do |base|
      home('Baseline', base)
      SiteValidation.artifact(@dir, base)
    end
    ['/assets/css/main.css?v=20260907000000',
     '/astra-team.github.io/assets/css/main.css',
     '/astra-team.github.io/assets/css/missing.css?v=20260907000000'].each do |href|
      File.write(File.join(@dir, 'index.html'), "<link rel='stylesheet' href='#{href}'>")
      assert_raises(RuntimeError) { SiteValidation.artifact(@dir, '/astra-team.github.io') }
    end
    home('Baseline', '/astra-team.github.io')
    path = File.join(@dir, 'assets/css/main.css')
    File.write(path, '/* .astra-hero-heading {} */ .navbar { display: flex; }')
    assert_raises(RuntimeError) { SiteValidation.artifact(@dir, '/astra-team.github.io') }
    File.unlink(path)
    assert_raises(RuntimeError) { SiteValidation.artifact(@dir, '/astra-team.github.io') }
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

  def test_approved_research_copy
    # Phase 4C approval snapshot: changes to this exact copy need editorial approval.
    approved = {
      '_research_axes/perception.md' => '1065cca669efe9f555d45510db83474a0e5da92c3c59a90d651184a775cd8ec0',
      '_research_axes/mapping.md' => 'e89fc43b3d6defb802146006a9b17cb3c2d4aac8cef05fb7c458e2a7affccc68',
      '_research_axes/decision.md' => 'a608e67e48b2e5aeebb460bf250de14fd397407e75d67b6d9dd71146824d82e3',
      '_research_axes/cooperative.md' => 'cb5c9a62d1fca3c521b2164f7f6e0ba2fb597f40709e1691c85acbb7e6cfbc03',
      '_research_axes/cross-cutting.md' => '95aeab0d9c9994eb4991e13793c8b6f36b38bf2666507a533ef8f5344b2639dd',
      '_pages/research/vision.md' => '6cd65f0f3fc16f51256748bf481eaed5a5d8872ed5d03b13e591e81871dfac63'
    }
    approved.each do |relative, digest|
      body = File.read(File.join(SiteValidation::ROOT, relative)).split(/^---\s*$\n?/, 3).last.strip
      assert_equal digest, Digest::SHA256.hexdigest(body), relative
      refute_includes body, 'Content currently being prepared.'
    end
  end

  def test_shared_approved_about_copy
    root = SiteValidation::ROOT
    path = File.join(root, '_includes/content/about-astra.md')
    assert_equal '43073d1b55df0cf68f4070e32dfca13f7badfe8f94a2209dcf4cae88f4bdafd8', Digest::SHA256.file(path).hexdigest
    %w[_layouts/about.html _includes/content/contact.md].each do |relative|
      assert_includes File.read(File.join(root, relative)), 'include content/about-astra.md'
    end
    refute_includes File.read(File.join(root, '_layouts/research.html')), 'axis.description'
  end
end
