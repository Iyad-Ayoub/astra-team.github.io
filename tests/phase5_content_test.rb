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
    assert_equal %w[gat samba shift2sdv sight tirrex], records.keys.sort
    assert_equal %w[shift2sdv tirrex gat], records.values.sort_by { |r| r['order'] }.select { |r| r['status'] == 'ongoing' }.map { |r| r['content_id'] }
    assert_equal %w[sight samba], records.values.sort_by { |r| r['order'] }.select { |r| r['status'] == 'completed' }.map { |r| r['content_id'] }
    assert_equal ['2021-01', '2025-06', 'completed'], records['sight'].values_at('start_date', 'end_date', 'status')
    assert_equal ['2021-12-18', '2022-01-14', 'ongoing'], records['tirrex'].values_at('start_date', 'kickoff_date', 'status')
    refute records['tirrex'].key?('end_date')
    refute records['tirrex'].key?('coordinator')
    assert_equal ['2020-09', '2023-01', 'completed'], records['samba'].values_at('start_date', 'end_date', 'status')
    %w[coordinator funder funding_amount].each { |key| refute records['samba'].key?(key) }
    assert_equal %w[ongoing european research-project], records['shift2sdv'].values_at('status', 'scope', 'type')
    assert_equal ['2025-07-01', '2028-06-30'], records['shift2sdv'].values_at('start_date', 'end_date')
    assert_equal %w[national research-infrastructure], records['tirrex'].values_at('scope', 'type')
    assert_equal %w[international joint-lab], records['gat'].values_at('scope', 'type')
    %w[start_date end_date coordinator external_url cordis_url].each { |key| refute records['gat'].key?(key) }
    %w[coordinator partners].each { |key| refute records['shift2sdv'].key?(key) }
    assert_equal 'https://shift2sdv-project.eu/', records['shift2sdv']['external_url']
    assert_equal 'https://cordis.europa.eu/project/id/101194245', records['shift2sdv']['cordis_url']
    assert_equal 'https://tirrex.fr/', records['tirrex']['external_url']
    records.each do |id, record|
      refute record.key?('image')
      refute record.key?('cordis_url') unless id == 'shift2sdv'
      refute record.key?('external_url') unless %w[shift2sdv tirrex].include?(id)
      assert_includes %w[ongoing completed], record['status']
      assert_includes %w[national european international], record['scope']
      assert_includes %w[research-project research-infrastructure joint-lab], record['type']
      refute_empty record['acronym']
    end
    assert_equal ['Inria Paris', 'Université Laval', 'Mines ParisTech'], records['sight']['partners']
    assert_equal ['SAFRAN Group', 'Inria Paris', 'TwinswHeel', 'Soben', 'Stanley Robotics', 'EXPLEO', 'Valeo'], records['samba']['partners']
    assert_equal ['Inria', 'Valeo', 'UC Berkeley', 'EPFL', 'Shanghai Jiao Tong University', 'Mines ParisTech', 'Stellantis', 'Safran'], records['gat']['partners']
  end

  def test_only_approved_platform
    platforms = YAML.safe_load_file(File.join(ROOT, '_data/platforms.yml'))
    assert_equal %w[zoe citroen-c1 cybus cybercars], platforms.select { |r| r['group'] == 'inria-astra' }.map { |r| r['id'] }
    assert_equal %w[cruise4u drive4u navya], platforms.select { |r| r['group'] == 'valeo' }.map { |r| r['id'] }
    assert_equal 7, platforms.size
    assert_equal({
      'id' => 'zoe', 'title' => 'Zoé Autonomous Research Vehicle',
      'type' => 'Experimental autonomous-driving research vehicle', 'status' => 'Current',
      'group' => 'inria-astra',
      'summary' => 'ASTRA operates a Renault Zoé research vehicle used as an experimental platform for autonomous-driving research and validation.'
    }, platforms.first)
    platforms.each do |record|
      assert_empty record.keys - %w[id title summary group type status]
      refute record['summary'].match?(/LiDAR|radar|certification|Level [0-5]/i)
      next if record['id'] == 'zoe'
      refute record.key?('status')
      refute record.key?('type')
    end
  end

  def test_outputs_and_repository_validation
    outputs = YAML.safe_load_file(File.join(ROOT, '_data/outputs.yml'))
    assert_equal 18, outputs.size
    assert_equal 18, outputs.map { |r| r['id'] }.uniq.size
    assert_equal REPOSITORIES, outputs.select { |r| r['repository'] }.to_h { |record| record.values_at('id', 'repository') }
    {
      'featured' => %w[pasco monoscene famix latteclip prolip poda],
      'additional' => %w[scenerf materialpalette materialtransform dream umbrae],
      'datasets' => %w[texsd pbrrand brainhub weather-kitti weather-cityscapes weather-nuscenes],
      'frameworks' => %w[weather-simulator]
    }.each { |group, ids| assert_equal ids, outputs.select { |r| r['group'] == group }.map { |r| r['id'] } }
    assert_equal({
      'monoscene' => 'https://cv-rits.github.io/MonoScene/',
      'dream' => 'https://weihaox.github.io/DREAM'
    }, outputs.select { |r| r['url'] }.to_h { |r| r.values_at('id', 'url') })
    outputs.each do |record|
      expected_kind = if record['id'] == 'brainhub'
                        'Dataset / benchmark'
                      elsif record['group'] == 'datasets'
                        'Dataset'
                      elsif record['group'] == 'frameworks'
                        'Framework / experimental tool'
                      else
                        'Software / research code'
                      end
      assert_equal expected_kind, record['kind']
      refute record.key?('status'), 'Do not infer software maintenance status'
      refute record.key?('image')
      unless REPOSITORIES.key?(record['id']) || %w[monoscene dream].include?(record['id'])
        assert_empty record.keys & %w[url repository website download]
      end
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
      assert_includes detail.text, record['status'].capitalize
      assert detail.at_css("a[href='#{base}/projects/']")
      %w[external_url cordis_url].each do |key|
        assert detail.at_css("article a[href='#{record[key]}']") if record[key]
      end
      assert_equal record.values_at('external_url', 'cordis_url').compact.sort,
                   detail.css('article a[href^="http"]').map { |a| a['href'] }.sort
    end
    assert_includes document.call('platforms').text, 'Zoé Autonomous Research Vehicle'
    outputs = document.call('outputs')
    REPOSITORIES.each do |id, url|
      assert_equal 1, outputs.css("##{id}").size
      assert outputs.at_css("##{id} a[href='#{url}']")
    end
    assert_equal 6, outputs.css('#featured-software + ul > li').size
    assert_equal 5, outputs.css('#additional-software + ul > li').size
    assert_equal 6, outputs.css('#datasets + ul > li').size
    assert_equal 1, outputs.css('#frameworks + ul > li').size
    actions = outputs.css('a.astra-text-link').map(&:text)
    assert_equal 8, actions.count('GitHub repository ↗')
    assert_equal 2, actions.count('Project website ↗')
    assert outputs.at_css('#monoscene a[href="https://cv-rits.github.io/MonoScene/"]')
    assert outputs.at_css('#dream a[href="https://weihaox.github.io/DREAM"]')
    %w[scenerf weather-simulator texsd pbrrand brainhub weather-kitti weather-cityscapes weather-nuscenes].each do |id|
      assert_empty outputs.css("##{id} a")
    end
    assert_equal 3, index.css('#ongoing-projects + ul > li').size
    assert_equal 2, index.css('#completed-projects + ul > li').size
    assert_equal %w[shift2sdv tirrex gat], index.css('#ongoing-projects + ul h3 a').map { |a| a['href'].split('/').last }
    assert_equal %w[sight samba], index.css('#completed-projects + ul h3 a').map { |a| a['href'].split('/').last }
    platforms = document.call('platforms')
    assert_equal 4, platforms.css('#inria-astra-platforms + ul > li').size
    assert_equal 3, platforms.css('#valeo-platforms + ul > li').size
    assert_empty platforms.css('#inria-astra-platforms + ul #cruise4u, #inria-astra-platforms + ul #drive4u')
    assert_equal 'Featured Software & Models', outputs.at_css('#featured-software').text
    assert_equal 'Open-Source Research Software', outputs.at_css('#additional-software').text
    {
      'sight' => { '2021-01' => 'January 2021', '2025-06' => 'June 2025' },
      'tirrex' => { '2021-12-18' => '18 December 2021', '2022-01-14' => '14 January 2022' },
      'samba' => { '2020-09' => 'September 2020', '2023-01' => 'January 2023' },
      'shift2sdv' => { '2025-07-01' => '1 July 2025', '2028-06-30' => '30 June 2028' }
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
