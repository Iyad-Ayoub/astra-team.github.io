require 'minitest/autorun'
require_relative '../scripts/validate_site'

class Phase5ContentTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  REPOSITORIES = {
    'pasco' => 'https://github.com/astra-vision/PaSCo',
    'famix' => 'https://github.com/astra-vision/FAMix',
    'latteclip' => 'https://github.com/astra-vision/LatteCLIP',
    'prolip' => 'https://github.com/astra-vision/ProLIP',
    'poda' => 'https://github.com/astra-vision/PODA',
    'materialpalette' => 'https://github.com/astra-vision/MaterialPalette',
    'materialtransform' => 'https://github.com/astra-vision/BRDFTransform',
    'umbrae' => 'https://github.com/weihaox/UMBRAE'
  }.freeze

  def projects
    Dir[File.join(ROOT, '_projects/*.md')].to_h do |path|
      data = SiteValidation.front_matter(path)
      [data.fetch('content_id'), data]
    end
  end

  def test_approved_projects_and_dates
    records = projects
    assert_equal %w[samba sight tirrex], records.keys.sort
    assert_equal ['2021-01', '2025-06', 'Completed'], records['sight'].values_at('start_date', 'end_date', 'status')
    assert_equal ['2021-12-18', '2022-01-14', 'Ongoing'], records['tirrex'].values_at('start_date', 'kickoff_date', 'status')
    refute records['tirrex'].key?('end_date')
    refute records['tirrex'].key?('coordinator')
    assert_equal 'Ongoing', records['samba']['status']
    %w[start_date end_date start_year end_year coordinator funder].each { |key| refute records['samba'].key?(key) }
    records.each_value { |record| refute record.key?('image'); refute record.key?('external_url') }
    assert_equal ['Inria Paris', 'Université Laval', 'Mines ParisTech'], records['sight']['partners']
    assert_equal ['SAFRAN Group', 'Inria Paris', 'TwinswHeel', 'Soben', 'Stanley Robotics', 'EXPLEO', 'Valeo'], records['samba']['partners']
  end

  def test_only_approved_platform
    platforms = YAML.safe_load_file(File.join(ROOT, '_data/platforms.yml'))
    assert_equal [{
      'id' => 'zoe', 'title' => 'Zoé Autonomous Research Vehicle',
      'type' => 'Experimental autonomous-driving research vehicle', 'status' => 'Current',
      'summary' => 'ASTRA operates a Renault Zoé research vehicle used as an experimental platform for autonomous-driving research and validation.'
    }], platforms
  end

  def test_outputs_and_repository_validation
    outputs = YAML.safe_load_file(File.join(ROOT, '_data/outputs.yml'))
    assert_equal REPOSITORIES.keys, outputs.map { |record| record['id'] }
    assert_equal REPOSITORIES, outputs.to_h { |record| record.values_at('id', 'repository') }
    assert_equal ['featured'] * 5 + ['additional'] * 3, outputs.map { |record| record['group'] }
    outputs.each do |record|
      assert_equal 'Software / research code', record['kind']
      refute record.key?('status'), 'Do not infer software maintenance status'
      refute record.key?('image')
    end
    record = { 'id' => 'fixture', 'title' => 'Fixture', 'repository' => 'javascript:void(0)' }
    assert_raises(RuntimeError) { SiteValidation.records([record]) }
    SiteValidation.records(outputs)
  end

  def test_rendered_content_when_artifact_supplied
    destination = ENV['PHASE5_SITE']
    skip 'Set PHASE5_SITE to check a built artifact' unless destination
    base = ENV.fetch('PHASE5_BASEURL', '')
    document = ->(path) { Nokogiri::HTML(File.read(File.join(destination, path, 'index.html'))) }
    index = document.call('projects')
    projects.each do |id, record|
      assert index.at_css("a[href='#{base}/projects/#{id}/']")
      detail = document.call("projects/#{id}")
      assert_includes detail.text, record['summary']
      assert_includes detail.text, record['status']
      assert detail.at_css("a[href='#{base}/projects/']")
    end
    assert_includes document.call('platforms').text, 'Zoé Autonomous Research Vehicle'
    outputs = document.call('outputs')
    REPOSITORIES.each do |id, url|
      assert_equal 1, outputs.css("##{id}").size
      assert outputs.at_css("##{id} a[href='#{url}']")
    end
    assert_equal 5, outputs.css('#featured-software + ul > li').size
    assert_equal 3, outputs.css('#additional-software ~ ul > li').size
    assert_equal ['GitHub repository ↗'] * 8, outputs.css('a.astra-text-link').map(&:text)
    {
      'sight' => { '2021-01' => 'January 2021', '2025-06' => 'June 2025' },
      'tirrex' => { '2021-12-18' => '18 December 2021', '2022-01-14' => '14 January 2022' }
    }.each do |id, dates|
      detail = document.call("projects/#{id}")
      assert detail.at_css('.astra-catalog .astra-project-metadata')
      dates.each do |canonical, display|
        assert_equal display, detail.at_css("time[datetime='#{canonical}']").text
      end
    end
    %w[research team publications news about info].each do |path|
      assert_nil document.call(path).at_css('.astra-catalog')
    end
    %w[projects platforms outputs].each do |path|
      refute_includes document.call(path).text, 'Content currently being prepared.'
    end
  end
end
