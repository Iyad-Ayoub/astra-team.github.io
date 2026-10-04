require 'minitest/autorun'
require 'nokogiri'

class ScientificVisionTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  AXES = [
    'Multimodal Perception & Scene Intelligence',
    'Localization, Mapping & Spatial Intelligence',
    'Prediction, Decision-Making, Planning & Control',
    'Large-Scale Mobility Systems'
  ].freeze

  def test_source_preserves_the_four_axis_structure_and_system_framing
    vision = File.read(File.join(ROOT, '_pages/research/vision.md'))
    AXES.each { |axis| assert_includes vision, axis }
    assert_includes vision, 'ASTRA is a joint Inria–Valeo research team in intelligent and autonomous mobility.'
    assert_includes vision, 'traffic dynamics, mobility modelling, fleet and system coordination, infrastructure interaction, congestion, network-level behaviour and mobility-system intelligence'
    assert_includes vision, 'Connected, cooperative and V2X approaches are considered where they help address these system-level questions.'

    dedicated_axis = File.read(File.join(ROOT, '_research_axes/cooperative.md'))
    assert_includes dedicated_axis, 'ASTRA studies mobility not only at the level of an individual autonomous vehicle'
  end

  def test_core_axis_overview_uses_canonical_collection_metadata
    links = File.read(File.join(ROOT, '_includes/research_links.html'))
    assert_includes links, 'class="astra-axis-grid"'
    assert_includes links, 'section.axis_number'
    assert_includes links, 'section.image'
    assert_includes links, 'section.summary'
    assert_includes links, 'Explore axis'
    assert_includes File.read(File.join(ROOT, '_layouts/research.html')), 'astra-research-overview'
    expected = {
      'perception' => '/assets/img/research/axis-perception.png',
      'mapping' => '/assets/img/research/axis-localization-mapping.png',
      'decision' => '/assets/img/research/axis-decision-navigation.png',
      'cooperative' => '/assets/img/research/axis-large-scale-mobility.png'
    }
    expected.each do |id, image|
      source = File.read(File.join(ROOT, "_research_axes/#{id}.md"))
      assert_includes source, "image: #{image}"
      assert_match(/axis_number: [1-4]/, source)
      assert_match(/summary: .{25,}/, source)
    end
  end

  def test_homepage_research_cards_use_canonical_axis_images
    layout = File.read(File.join(ROOT, '_layouts/about.html'))
    assert_includes layout, 'axis.image | relative_url'
    assert_includes layout, 'axis.image_alt'
    assert_includes layout, 'axis.image_width'
    assert_includes layout, 'axis.image_height'
    refute_includes layout, 'site.data.axes[forloop.index0]'
  end

  def test_research_axis_visual_and_heading_polish_is_scoped
    page_layout = File.read(File.join(ROOT, '_layouts/page.html'))
    styles = File.read(File.join(ROOT, '_sass/_astra.scss'))
    assert_includes page_layout, 'research-axis-page'
    assert_includes styles, '.astra-research-overview'
    assert_includes styles, '.research-axis-page article > h2'
    assert_includes styles, 'max-width: 56rem'
    assert_includes styles, '.astra-axis-card .astra-axis-eyebrow'
  end

  def test_rendered_core_axes_are_titles_only_when_artifact_supplied
    destination = ENV['VISION_SITE']
    skip 'Set VISION_SITE for generated checks' unless destination

    base = ENV.fetch('VISION_BASEURL', '')
    homepage = Nokogiri::HTML(File.read(File.join(destination, 'index.html')))
    homepage_cards = homepage.css('.astra-home .astra-research-grid > .astra-research-card')
    assert_equal 4, homepage_cards.size
    expected_images = AXES.zip(%w[perception mapping decision cooperative]).map do |_, id|
      axis = File.read(File.join(ROOT, "_research_axes/#{id}.md"))
      axis[/^image: (\S+)$/, 1]
    end
    assert_equal expected_images.map { |image| "#{base}#{image}" }, homepage_cards.map { |card| card.at_css('img')['src'] }
    refute homepage.text.include?('axis_astra-vision')

    research = Nokogiri::HTML(File.read(File.join(destination, 'research/index.html')))
    core_axes = research.css('#current-research ul.astra-axis-grid > li')
    assert_equal AXES, core_axes.map { |item| item.at_css('h3').text.strip }
    assert_equal %w[01 02 03 04], core_axes.map { |item| item.at_css('.astra-axis-eyebrow').text[/\d+/] }
    assert core_axes.all? { |item| item.at_css('img') && item.at_css('p') }

    axis = Nokogiri::HTML(File.read(File.join(destination, 'research/cooperative/index.html')))
    assert_includes axis.text, 'traffic dynamics, mobility modelling, fleet coordination, infrastructure interaction'
  end
end
