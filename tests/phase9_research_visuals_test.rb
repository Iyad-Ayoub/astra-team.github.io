require 'minitest/autorun'
require 'digest'
require 'nokogiri'
require_relative '../scripts/validate_site'

class Phase9ResearchVisualsTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  IMAGES = {
    'perception' => ['axis_astra-vision.png', 591, 480],
    'mapping' => ['axis_localization.jpg', 672, 397],
    'decision' => ['axis_decision.jpg', 659, 536]
  }.freeze
  BODY_HASHES = {
    # Pre-Phase-10 explicitly approved replacement; other scientific snapshots unchanged.
    'cooperative' => 'd7bdf77f2bdbb42574e6c26a96269215113820e29a5d597d95e9cadcaf6e56f6',
    'cross-cutting' => '8aab6721ed171ea4b93c26e43e810d0af9f22cc04f7ff7d7a2b3b4258f59361d',
    'decision' => '5de2f7f6c4b42d0a07cd28a997a4fa29a2b95566e56280e20a88abab1b1bec35',
    'mapping' => 'db0200ae1c729c4caca28f4ae414dbbdd2c128ea781f270f0645983af2eb1f84',
    'perception' => '86bfb69eff6a6d160a987ab7a706a02ca259eb60d8dc747376ea0e1e99dee00b'
  }.freeze
  PIPELINE_HASHES = {
    '_config.yml' => '70aacf5d212131d5b8e7393d3b0507dd70fa7e2797bd9670f254b5b2e3e75099',
    'Gemfile' => '1f3d9b694f9c984c8e567cbfb7eeb58a852e807e9e4dfca72612b8cbf350351b',
    'Gemfile.lock' => '137c5ef5fad8e70bc4f9494484503f07da3313cd5aa5416bbcd5a683f5e483c6',
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

  def test_pipeline_and_all_image_bytes_preserved
    PIPELINE_HASHES.each { |path, hash| assert_equal hash, Digest::SHA256.file(File.join(ROOT, path)).hexdigest, path }
    files = %w[_responsive assets/img].flat_map { |dir| Dir[File.join(ROOT, dir, '**/*')].select { |p| File.file?(p) }.sort }
    digest = Digest::SHA256.new
    files.each { |path| digest.update(path.delete_prefix(ROOT + '/') + "\0"); digest.update(File.binread(path)) }
    assert_equal '9282457eb36df2c0ad27cdf76e0b8478eb5e206c29867ba306125fe0c50a0295', digest.hexdigest
    css = File.read(File.join(ROOT, '_sass/_astra.scss')).split('.astra-axis-illustration {', 2).last.split('@media', 2).first
    assert_includes css, 'max-width: 100%'
    assert_includes css, 'height: auto'
    refute_match(/object-fit|aspect-ratio|(?<![\w-])height:\s*\d/, css)
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
        assert_empty figures, relative
        # All other research pages and catalog/news routes remain image-free.
        if relative.match?(%r{\A(?:research|projects|platforms|outputs|news)/})
          assert_empty doc.css('article img'), relative
        end
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
