require 'minitest/autorun'
require 'yaml'
require 'nokogiri'
require_relative '../scripts/validate_site'

class Phase12ScientificHeritageTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  AXES = %w[perception mapping decision cooperative].freeze

  def data
    YAML.safe_load_file(File.join(ROOT, '_data/scientific_heritage.yml'))
  end

  def test_editorial_data_is_dated_and_safe
    milestones = data.fetch('timeline')
    assert_operator milestones.size, :<=, 7
    assert_equal %w[1993 1997 2001–2005 2012 2014–2015 2022], milestones.map { |item| item['year'] }
    milestones.each do |item|
      assert_match(/\A\d{4}(?:–\d{4})?\z/, item.fetch('year'))
      assert_match(%r{\Ahttps://}, item.fetch('source'))
      assert_includes %w[CURRENT_ASTRA HISTORICAL_RITS HISTORICAL_IMARA HISTORICAL_EARLY_MOBILITY CONTINUITY_TO_ASTRA UNCERTAIN], item.fetch('classification')
    end
    rits = milestones.find { |item| item.fetch('classification') == 'HISTORICAL_RITS' }
    assert_equal 'Inria created RITS in February 2014 under the leadership of Fawzi Nashashibi; it became a project-team in July 2015, with research spanning vehicle guidance, communication and transportation systems.', rits.fetch('summary')
    assert_equal 'https://radar.inria.fr/report/2015/rits/uid1.html', rits.fetch('source')
    refute_match(/ASTRA has been doing|ASTRA since 1993/i, File.read(File.join(ROOT, '_includes/content/contact.md')))
  end

  def test_axis_relationships_reference_existing_records_only
    bibliography = File.read(File.join(ROOT, '_bibliography/rits-astra.bib'))
    outputs = YAML.safe_load_file(File.join(ROOT, '_data/outputs.yml')).map { |item| item.fetch('id') }
    AXES.each do |axis|
      item = data.fetch('axes').fetch(axis)
      refute_empty item.fetch('historical_foundation')
      assert_operator item.fetch('selected_publications').size, :<=, 5
      item.fetch('selected_publications').each { |key| assert_match(/@\w+\{#{Regexp.escape(key)},/i, bibliography) }
      item.fetch('related_outputs').each { |id| assert_includes outputs, id }
    end
  end

  def test_rendered_heritage_when_artifact_supplied
    destination = ENV['PHASE12_SITE']
    skip 'Set PHASE12_SITE for generated checks' unless destination
    base = ENV.fetch('PHASE12_BASEURL', '')
    about = Nokogiri::HTML(File.read(File.join(destination, 'about/index.html')))
    assert_equal 1, about.css('#scientific-heritage').size
    assert_equal data.fetch('timeline').size, about.css('.astra-heritage-milestone').size
    assert_equal data.fetch('timeline').size - 1, about.css('.astra-historical-label').size
    assert_includes about.text, 'ASTRA today'
    AXES.each do |axis|
      doc = Nokogiri::HTML(File.read(File.join(destination, "research/#{axis}/index.html")))
      assert doc.at_css('#scientific-foundations')
      assert doc.at_css('#selected-works')
      data.fetch('axes').fetch(axis).fetch('selected_publications').each do |key|
        assert doc.at_css("[data-publication-key='#{key}'] a[href='#{base}/publications/##{key}']")
      end
    end
    platforms = Nokogiri::HTML(File.read(File.join(destination, 'platforms/index.html')))
    assert platforms.at_css('#experimental-heritage')
    data.fetch('platform_heritage').each { |item| assert platforms.at_css("##{item.fetch('id')}") }
  end
end
