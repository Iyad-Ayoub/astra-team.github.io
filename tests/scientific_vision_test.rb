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

  def test_rendered_core_axes_are_titles_only_when_artifact_supplied
    destination = ENV['VISION_SITE']
    skip 'Set VISION_SITE for generated checks' unless destination

    research = Nokogiri::HTML(File.read(File.join(destination, 'research/index.html')))
    core_axes = research.css('#current-research ul > li')
    assert_equal AXES, core_axes.map { |item| item.at_css('a').text.strip }
    assert core_axes.all? { |item| item.css('p').empty? }

    axis = Nokogiri::HTML(File.read(File.join(destination, 'research/cooperative/index.html')))
    assert_includes axis.text, 'traffic dynamics, mobility modelling, fleet coordination, infrastructure interaction'
  end
end
