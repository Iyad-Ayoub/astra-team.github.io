require 'minitest/autorun'
require_relative '../scripts/validate_site'

class Phase5ContentTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  BASELINE_PROJECT_IDS = %w[gat samba shift2sdv sight tirrex].freeze
  BASELINE_ONGOING_IDS = %w[shift2sdv tirrex gat].freeze
  BASELINE_COMPLETED_IDS = %w[sight samba].freeze
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

  def expected_project_listing_title(record)
    acronym = record.fetch('acronym')
    title = record.fetch('title').to_s.strip
    title.start_with?(acronym) ? title : "#{acronym} — #{title}"
  end

  def test_approved_projects_and_dates
    records = projects
    assert_operator records.size, :>=, BASELINE_PROJECT_IDS.size
    assert_equal BASELINE_PROJECT_IDS.sort, records.keys.select { |id| BASELINE_PROJECT_IDS.include?(id) }.sort
    ongoing = records.values.sort_by { |r| r['order'] || 9999 }.select { |r| r['status'] == 'ongoing' }
    completed = records.values.sort_by { |r| r['order'] || 9999 }.select { |r| r['status'] == 'completed' }
    assert_equal BASELINE_ONGOING_IDS, ongoing.select { |r| BASELINE_ONGOING_IDS.include?(r['content_id']) }.map { |r| r['content_id'] }
    assert_equal BASELINE_COMPLETED_IDS, completed.select { |r| BASELINE_COMPLETED_IDS.include?(r['content_id']) }.map { |r| r['content_id'] }
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
      assert_match(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, record['content_id'])
      %w[acronym title summary astra_role].each { |key| refute_empty record[key].to_s.strip }
      refute record.key?('image')
      %w[external_url cordis_url].each do |key|
        next unless record.key?(key)

        value = record[key].to_s.strip
        refute_empty value
        assert_match(%r{\Ahttps?://}i, value)
      end
      assert_includes %w[ongoing completed], record['status']
      assert_includes %w[national european international], record['scope']
      assert_includes %w[research-project research-infrastructure joint-lab], record['type']
      refute_empty record['acronym']
    end
    assert_equal ['Inria Paris', 'Université Laval', 'Mines ParisTech'], records['sight']['partners']
    assert_equal ['SAFRAN Group', 'Inria Paris', 'TwinswHeel', 'Soben', 'Stanley Robotics', 'EXPLEO', 'Valeo'], records['samba']['partners']
    assert_equal ['Inria', 'Valeo', 'UC Berkeley', 'EPFL', 'Shanghai Jiao Tong University', 'Mines ParisTech', 'Stellantis', 'Safran'], records['gat']['partners']
  end

  def test_platform_ids_remain_stable
    platforms = YAML.safe_load_file(File.join(ROOT, '_data/platforms.yml'))
    assert_equal %w[zoe citroen-c1 cybus cybercars cruise4u drive4u navya], platforms.map { |r| r['id'] }
    assert_equal 7, platforms.size
    assert_equal 'Zoé Autonomous Research Vehicle', platforms.first.fetch('name')
  end

  def test_project_listing_ordering_preserves_curated_history_and_prioritizes_cms_defaults
    listing = File.read(File.join(ROOT, '_pages/projects.md'))
    assert_includes listing, "where_exp: 'project', 'project.order <= 0 or project.order == 9999'"
    assert_includes listing, "where_exp: 'project', 'project.order > 0 and project.order != 9999'"
    assert_includes listing, "auto_projects = all_projects | where_exp: 'project', 'project.order <= 0 or project.order == 9999' | sort: 'order'"
    records = [
      { 'content_id' => 'historical', 'order' => 1, 'start_date' => '2020-01' },
      { 'content_id' => 'newer', 'order' => -2_026_010_100, 'start_date' => '2026-01-01' },
      { 'content_id' => 'same-date-a', 'order' => -2_025_010_100, 'start_date' => '2025-01-01' },
      { 'content_id' => 'same-date-b', 'order' => -2_025_010_200, 'start_date' => '2025-01-01' },
      { 'content_id' => 'legacy-cms', 'order' => 9999, 'start_date' => '2025-01-01' },
      { 'content_id' => 'historical-2', 'order' => 2, 'start_date' => '2021-01' }
    ]
    auto = records.select { |record| record['order'] <= 0 || record['order'] == 9999 }.sort_by { |record| record['order'] }
    curated = records.select { |record| record['order'] > 0 && record['order'] != 9999 }.sort_by { |record| record['order'] }
    assert_equal %w[newer same-date-b same-date-a legacy-cms historical historical-2], (auto + curated).map { |record| record['content_id'] }
  end

  def test_project_listing_title_rule_is_generic
    listing = File.read(File.join(ROOT, '_pages/projects.md'))
    assert_includes listing, 'title_prefix = project_title | slice: 0, project_acronym.size'
    assert_includes listing, 'title_remainder = project_title | remove_first: project_acronym | strip'
    assert_includes listing, 'title_prefix == project_acronym'
    fixtures = [
      { 'acronym' => 'Shift2SDV', 'title' => 'Shift2SDV' },
      { 'acronym' => 'TIRREX', 'title' => 'TIRREX — Infrastructure technologique pour la recherche d’excellence en robotique' },
      { 'acronym' => 'TEST-HDMap', 'title' => 'Cooperative HD Mapping for Autonomous Driving' }
    ]
    assert_equal 'Shift2SDV', expected_project_listing_title(fixtures[0])
    assert_equal 'TIRREX — Infrastructure technologique pour la recherche d’excellence en robotique', expected_project_listing_title(fixtures[1])
    assert_equal 'TEST-HDMap — Cooperative HD Mapping for Autonomous Driving', expected_project_listing_title(fixtures[2])
    assert_includes expected_project_listing_title(fixtures[1]), 'TIRREX — '
  end

  def test_outputs_and_repository_validation
    outputs = YAML.safe_load_file(File.join(ROOT, '_data/outputs.yml'))
    assert_equal 18, outputs.size
    assert_equal 18, outputs.map { |r| r['id'] }.uniq.size
    repositories = outputs.select { |r| r['repository'] }.to_h { |record| record.values_at('id', 'repository') }
    REPOSITORIES.each do |id, url|
      assert_equal url, repositories[id]
    end
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
      unless record['id'] == 'monoscene' ||
             record['id'] == 'dream' ||
             record['repository']
        assert_empty record.keys & %w[url repository website download]
      end
    end
    record = { 'id' => 'fixture', 'title' => 'Fixture', 'repository' => 'javascript:void(0)' }
    assert_raises(RuntimeError) { SiteValidation.records([record]) }
    SiteValidation.records(outputs)
  end

  def test_rendered_content_when_artifact_supplied
    records = projects
    destination = ENV['PHASE5_SITE']
    skip 'Set PHASE5_SITE to check a built artifact' unless destination
    base = ENV.fetch('PHASE5_BASEURL', '')
    document = ->(path) { Nokogiri::HTML(File.read(File.join(destination, path, 'index.html'))) }
    index = document.call('projects')
    projects.each do |id, record|
      assert index.at_css("a[href='#{base}/projects/#{id}/']")
      assert_equal expected_project_listing_title(record), index.at_css("a[href='#{base}/projects/#{id}/']").text.strip
      detail = document.call("projects/#{id}")
      assert_includes detail.text, record['summary']
      assert_includes detail.text, record['status'].capitalize
      assert detail.at_css("a[href='#{base}/projects/']")
      %w[external_url cordis_url].each do |key|
        assert detail.at_css("article a[href='#{record[key]}']") if record[key]
      end
      if record['cover_image']
        cover_src = "#{base}#{record['cover_image']}"
        assert detail.at_css("img[src='#{cover_src}']")
        refute_empty detail.at_css("img[src='#{cover_src}']")['alt'].to_s
      else
        assert_empty detail.css('.astra-project-cover')
      end
      assert_equal record.values_at('external_url', 'cordis_url').compact.sort,
                   detail.css('article a[href^="http"]').map { |a| a['href'] }.sort
    end
    assert_includes document.call('platforms').text, 'Zoé Autonomous Research Vehicle'
    output_records = YAML.safe_load_file(File.join(ROOT, '_data/outputs.yml'))
    outputs_page = document.call('outputs')
    output_records.select { |record| record['repository'] }.each do |record|
      id = record.fetch('id')
      url = record.fetch('repository')
      assert_equal 1, outputs_page.css("##{id}").size
      assert outputs_page.at_css("##{id} a[href='#{url}']")
    end
    %w[featured additional datasets frameworks].each do |group|
      heading = {
        'featured' => '#featured-software',
        'additional' => '#additional-software',
        'datasets' => '#datasets',
        'frameworks' => '#frameworks'
      }.fetch(group)
      assert_equal output_records.count { |record| record['group'] == group },
                   outputs_page.css("#{heading} + ul > li").size
    end
    actions = outputs_page.css('a.astra-text-link').map(&:text)
    assert_operator actions.count('GitHub repository ↗'), :>, 0
    assert_equal output_records.count { |record| record['url'] && record['repository'].nil? }, actions.count('Project website ↗')
    assert outputs_page.at_css('#monoscene a[href="https://cv-rits.github.io/MonoScene/"]')
    assert outputs_page.at_css('#dream a[href="https://weihaox.github.io/DREAM"]')
    %w[texsd pbrrand].each do |id|
      assert_empty outputs_page.css("##{id} a")
    end
    ongoing = records.values.select { |record| record['status'] == 'ongoing' }
    completed = records.values.select { |record| record['status'] == 'completed' }
    assert_equal ongoing.size, index.css('#ongoing-projects + ul > li').size
    assert_equal completed.size, index.css('#completed-projects + ul > li').size
    assert_equal BASELINE_ONGOING_IDS, index.css('#ongoing-projects + ul h3 a').map { |a| a['href'].split('/').last }.select { |id| BASELINE_ONGOING_IDS.include?(id) }
    assert_equal BASELINE_COMPLETED_IDS, index.css('#completed-projects + ul h3 a').map { |a| a['href'].split('/').last }.select { |id| BASELINE_COMPLETED_IDS.include?(id) }
    platforms = document.call('platforms')
    current = platforms.at_css('#current-astra-inria-platforms').parent
    unverified = platforms.at_css('#documented-inria-inventory').parent
    partner = platforms.at_css('#valeo-partner-demonstrators').parent
    historical = platforms.at_css('#experimental-heritage').parent
    assert_equal 1, current.css('.astra-platform-records > article').size
    assert_equal 1, unverified.css('.astra-platform-records > article').size
    assert_equal 3, partner.css('.astra-platform-records > article').size
    assert_equal 2, historical.css('.astra-platform-records > article').size

    assert_empty current.css('#cruise4u, #drive4u')
    assert_equal 'Featured Software & Models', outputs_page.at_css('#featured-software').text
    assert_equal 'Open-Source Research Software', outputs_page.at_css('#additional-software').text
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
