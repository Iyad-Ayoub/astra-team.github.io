require 'minitest/autorun'
require 'digest'
require 'nokogiri'
require 'fileutils'
require 'tmpdir'
require_relative '../scripts/validate_site'

class Phase9ResearchVisualsTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  IMAGES = {
    'perception' => ['axis_astra-vision.png', 591, 480],
    'mapping' => ['axis_localization.jpg', 672, 397],
    'decision' => ['axis_decision.jpg', 659, 536]
  }.freeze
  PROTECTED_IMAGE_DIRECTORIES = %w[
    assets/img/research
    _responsive/assets/img/research
  ].freeze
  PROTECTED_RESEARCH_IMAGE_HASH = '1af5495e580ce801b24543a719994b0f141ae88bb58d5fd946635ed3cfcf58f9'
  BODY_HASHES = {
    # Pre-Phase-10 explicitly approved replacement; other scientific snapshots unchanged.
    'cooperative' => 'd7bdf77f2bdbb42574e6c26a96269215113820e29a5d597d95e9cadcaf6e56f6',
    'cross-cutting' => '8aab6721ed171ea4b93c26e43e810d0af9f22cc04f7ff7d7a2b3b4258f59361d',
    'decision' => '5de2f7f6c4b42d0a07cd28a997a4fa29a2b95566e56280e20a88abab1b1bec35',
    'mapping' => 'db0200ae1c729c4caca28f4ae414dbbdd2c128ea781f270f0645983af2eb1f84',
    'perception' => '86bfb69eff6a6d160a987ab7a706a02ca259eb60d8dc747376ea0e1e99dee00b'
  }.freeze
  PIPELINE_HASHES = {
    # Internal environment-file and Worker exclusions do not change image settings.
    # Retain a full-config pin: no image-pipeline setting has changed.
    '_config.yml' => '99b958cf0325a22a7a37bca7189f6442fac160b6cf994ea329481dee4fb62e5b',
    # Phase 10D: Ruby baseline and same-version native source variants only.
    # phase10d_runtime_test independently pins all 90 existing gem versions.
    'Gemfile' => 'e703ea4b078a59be2035256c0f810aa1987ab7808fefd975954870e28eadf7cc',
    'Gemfile.lock' => '69f2dce6e90cdb8f327cc28a62e3a964097d59d0d7433c931c99c4c2542e62d1',
    '_includes/figure.html' => '48fe9e4477433fdd658f106b433e0b004fed32b5cb8e1df1936a314c3adf02b3'
  }.freeze

  def test_only_approved_associations_and_unchanged_scientific_bodies
    BODY_HASHES.each do |id, hash|
      path = File.join(ROOT, "_research_axes/#{id}.md")
      assert_equal hash, Digest::SHA256.hexdigest(File.binread(path).split('---', 3).last), id
      data = SiteValidation.front_matter(path)
      if IMAGES.key?(id)
        name, width, height = IMAGES[id]
        assert_equal "/assets/img/research/#{name}", data['image']
        assert File.file?(File.join(ROOT, data['image'].delete_prefix('/')))
        assert_equal [width, height], data.values_at('image_width', 'image_height')
        refute_empty data.fetch('image_alt').strip
        refute_empty data.fetch('image_caption').strip
        refute data.key?('image_credit'), 'No invented credits'
      else
        refute data.key?('image'), id
      end
    end
  end

  def protected_research_image_digest(root = ROOT)
    files = PROTECTED_IMAGE_DIRECTORIES.flat_map do |directory|
      Dir[File.join(root, directory, '**/*')].select { |path| File.file?(path) }.sort
    end
    digest = Digest::SHA256.new
    files.each do |path|
      digest.update(path.delete_prefix(root + '/') + "\0")
      digest.update(File.binread(path))
    end
    digest.hexdigest
  end

  def test_pipeline_and_protected_research_image_bytes_preserved
    PIPELINE_HASHES.each { |path, hash| assert_equal hash, Digest::SHA256.file(File.join(ROOT, path)).hexdigest, path }
    assert_equal PROTECTED_RESEARCH_IMAGE_HASH, protected_research_image_digest
    css = File.read(File.join(ROOT, '_sass/_astra.scss')).split('.astra-axis-illustration {', 2).last.split('@media', 2).first
    assert_includes css, 'max-width: 100%'
    assert_includes css, 'height: auto'
    refute_match(/object-fit|aspect-ratio|(?<![\w-])height:\s*\d/, css)
  end

  def test_cms_news_cover_does_not_change_the_protected_research_visual_baseline
    Dir.mktmpdir('astra-phase9-research-') do |root|
      PROTECTED_IMAGE_DIRECTORIES.each do |directory|
        FileUtils.mkdir_p(File.join(root, File.dirname(directory)))
        FileUtils.cp_r(File.join(ROOT, directory), File.join(root, File.dirname(directory)))
      end
      assert_equal PROTECTED_RESEARCH_IMAGE_HASH, protected_research_image_digest(root)

      cover = File.join(root, 'assets/img/news/news-fixturecover/cover.png')
      FileUtils.mkdir_p(File.dirname(cover))
      File.binwrite(cover, 'valid additional CMS cover fixture')
      assert_equal PROTECTED_RESEARCH_IMAGE_HASH, protected_research_image_digest(root)

      protected = File.join(root, 'assets/img/research/axis_astra-vision.png')
      File.binwrite(protected, File.binread(protected) + 'modified')
      refute_equal PROTECTED_RESEARCH_IMAGE_HASH, protected_research_image_digest(root)
      FileUtils.rm_f(protected)
      refute_equal PROTECTED_RESEARCH_IMAGE_HASH, protected_research_image_digest(root)
    end
  end

  def assert_non_axis_page_visuals(relative, doc, base)
    assert_empty doc.css('figure.astra-axis-illustration'), relative
    if relative.match?(%r{\A(?:research|projects|platforms|outputs)/})
      assert_empty doc.css('article img'), relative
    elsif relative.start_with?('news/')
      doc.css('article img').each do |image|
        assert_match(%r{\A#{Regexp.escape(base)}/assets/img/news/news-[a-z0-9]+/[a-zA-Z0-9_.-]+\.(?:png|jpe?g|gif|webp)\z}, image['src'], relative)
        refute_empty image['alt'].to_s.strip, relative
      end
    end
  end

  def test_additional_cms_news_detail_with_a_cover_is_not_an_excluded_visual_page
    doc = Nokogiri::HTML('<article><img src="/assets/img/news/news-fixturecover/cover.png" alt="Fixture cover"></article>')
    assert_non_axis_page_visuals('news/fixture-cover/index.html', doc, '')
  end

  def test_generated_placements_and_excluded_pages
    destination = ENV['PHASE9_SITE']
    skip 'Set PHASE9_SITE to validate a built artifact' unless destination
    base = ENV.fetch('PHASE9_BASEURL', '')
    found = []
    Dir[File.join(destination, '**/*.html')].each do |path|
      doc = Nokogiri::HTML(File.read(path))
      figures = doc.css('figure.astra-axis-illustration')
      relative = path.delete_prefix(destination + '/')
      expected = IMAGES.keys.find { |id| relative == "research/#{id}/index.html" }
      unless expected
        # Research and catalog pages remain image-free. CMS News pages may have
        # an optional validated cover image under their content-owned public path.
        assert_non_axis_page_visuals(relative, doc, base)
        next
      end
      found << expected
      assert_equal 1, figures.size
      assert_equal 1, doc.css('article img').size
      figure = figures.first
      image = figure.at_css('img')
      name, width, height = IMAGES.fetch(expected)
      assert_equal "#{base}/assets/img/research/#{name}", image['src']
      assert File.file?(File.join(destination, 'assets/img/research', name))
      data = SiteValidation.front_matter(File.join(ROOT, "_research_axes/#{expected}.md"))
      assert_equal data['image_alt'], image['alt']
      assert_equal data['image_caption'], figure.at_css('figcaption').text.strip
      assert_equal [width.to_s, height.to_s], [image['width'], image['height']]
      assert_equal 'p', figure.previous_element.name
      assert_equal 'h2', figure.next_element.name
      assert_equal 1, doc.css('h1').size
      assert_empty figure.css('a, h1, h2, h3')
    end
    assert_equal IMAGES.keys.sort, found.sort
  end
end
