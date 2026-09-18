require 'minitest/autorun'
require 'yaml'
require 'nokogiri'

class Phase12DPlatformsTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  IDS = %w[zoe citroen-c1 cybus cybercars cruise4u drive4u navya].freeze
  TEMPORAL_STATUSES = %w[current reported_inventory historical status_unverified].freeze
  REQUIRED_FIELDS = %w[id name platform_type relationship temporal_status evidence_status summary ownership_context evidence_as_of sources media].freeze

  def platforms
    YAML.safe_load_file(File.join(ROOT, '_data/platforms.yml'))
  end

  def test_platform_registry_has_dated_primary_evidence
    assert_equal IDS, platforms.map { |record| record.fetch('id') }
    platforms.each do |record|
      assert_empty REQUIRED_FIELDS - record.keys
      assert_includes TEMPORAL_STATUSES, record.fetch('temporal_status')
      assert_kind_of Array, record.fetch('media')
      refute_empty record.fetch('sources')
      record.fetch('sources').each do |source|
        assert_equal %w[title url publisher year source_type supports], source.keys
        assert_match(%r{\Ahttps://}, source.fetch('url'))
      end
      refute_match(/LiDAR|radar|certification|Level [0-5]/i, record.fetch('summary'))
    end

    by_id = platforms.to_h { |record| [record.fetch('id'), record] }
    assert_equal 'current', by_id.fetch('zoe').fetch('temporal_status')
    %w[cybus cybercars].each { |id| assert_equal 'historical', by_id.fetch(id).fetch('temporal_status') }
    assert_equal 'status_unverified', by_id.fetch('citroen-c1').fetch('temporal_status')
    assert_equal 'reported_inventory', by_id.fetch('navya').fetch('temporal_status')
  end

  def test_platform_renderer_is_data_driven
    renderer = File.read(File.join(ROOT, '_includes/platform_records.html'))
    refute_match(/case\s+record\.id|record\.id\s*==|record\.id\s*!=/, renderer)
    assert_includes renderer, '{{ record.platform_type | escape }}'
    assert_includes renderer, '{{ record.summary | escape }}'
  end

  def test_rendered_platforms_when_artifact_supplied
    destination = ENV['PHASE12D_SITE']
    skip 'Set PHASE12D_SITE for generated checks' unless destination
    base = ENV.fetch('PHASE12D_BASEURL', '')
    platforms_page = Nokogiri::HTML(File.read(File.join(destination, 'platforms/index.html')))

    # Intended sections render
    assert platforms_page.at_css('#current-astra-inria-platforms')
    assert platforms_page.at_css('#documented-inria-inventory')
    assert platforms_page.at_css('#valeo-partner-demonstrators')
    assert platforms_page.at_css('#experimental-heritage')

    # Stable primary and legacy anchors remain valid
    IDS.each { |id| assert platforms_page.at_css("##{id}") }
    assert platforms_page.at_css('#cybus-la-rochelle-2012')
    assert platforms_page.at_css('#cybercars-service-2011')

    # Platform cards are not list items, preventing list markers between cards.
    containers = platforms_page.css('.astra-platform-records')
    assert_equal 4, containers.size
    containers.each do |container|
      assert_empty container.css('ol')
      assert_empty container.element_children.select { |child| child.name == 'li' }
      refute_empty container.element_children.select do |child|
        child.name == 'article' && child['class'].to_s.split.include?('astra-research-card')
      end
    end

    # Zoé renders as current
    zoe_card = platforms_page.at_css('#zoe')
    assert_includes zoe_card.at_css('.astra-record-status').text, 'Current'
    assert platforms_page.at_css('#current-astra-inria-platforms').parent.at_css('#zoe')

    # Raw schema labels such as status_unverified and reported_inventory are not exposed
    refute_includes platforms_page.text, 'status_unverified'
    refute_includes platforms_page.text, 'reported_inventory'

    # Citroën C1 does not render as current
    c1_card = platforms_page.at_css('#citroen-c1')
    refute_includes c1_card.at_css('.astra-record-status').text, 'Current'
    assert_includes c1_card.at_css('.astra-record-status').text, 'Experimental research vehicle'
    refute platforms_page.at_css('#current-astra-inria-platforms').parent.at_css('#citroen-c1')

    # NAVYA does not render as current
    navya_card = platforms_page.at_css('#navya')
    refute_includes navya_card.at_css('.astra-record-status').text, 'Current'
    assert_includes navya_card.at_css('.astra-record-status').text,
                    platforms.find { |platform| platform.fetch('id') == 'navya' }.fetch('platform_type')
    refute platforms_page.at_css('#current-astra-inria-platforms').parent.at_css('#navya')

    # Cybus and Cybercars are not duplicated as current inventory cards
    %w[cybus cybercars].each do |id|
      record = platforms_page.at_css("##{id}")
      assert_includes record.text, platforms.find { |platform| platform.fetch('id') == id }.fetch('platform_type')
      refute_includes platforms_page.at_css('#current-astra-inria-platforms').text, record.at_css('h3').text
      assert platforms_page.at_css('#experimental-heritage').parent.at_css("##{id}")
    end

    # Source links render
    IDS.each do |id|
      card = platforms_page.at_css("##{id}")
      refute_empty card.css('.astra-platform-sources a.astra-text-link')
    end
    assert zoe_card.at_css("a[href='https://radar.inria.fr/report/2025/astra/index.html']")

    # Research Outputs remain unaffected
    outputs_page = Nokogiri::HTML(File.read(File.join(destination, 'outputs/index.html')))
    assert outputs_page.at_css("#pasco a[href='https://github.com/astra-vision/PaSCo']")
  end
end
