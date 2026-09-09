require 'minitest/autorun'
require 'jekyll'
require 'tmpdir'
require 'fileutils'
require 'digest'
require_relative '../scripts/validate_site'

class Phase7NewsTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  NEW_IDS = %w[news-ieee-iv-2025 news-matswap-egsr-2025 news-acvss-2025
    news-pasco-cvpr-2024 news-acvss-nairobi-2024 news-raoul-dr-2024
    news-open-source-2024 news-open-source-2023 news-visapp-2022-best-paper].freeze
  HOME_IDS = %w[news-ieee-iv-2025 news-matswap-egsr-2025 news-acvss-2025].freeze

  def records
    Dir[File.join(ROOT, '_news/*.md')].map { |p| SiteValidation.front_matter(p) }
  end

  def validate(items)
    AstraNews.validate(items, root: ROOT, output_ids: ['pasco'], project_ids: [])
  end

  def test_inventory_and_evidence_boundaries
    assert_equal 11, records.size
    assert_equal NEW_IDS.sort, records.reject { |r| %w[news-astra-creation-2022 news-plenary-2025].include?(r['content_id']) }.map { |r| r['content_id'] }.sort
    assert_equal (NEW_IDS + ['news-plenary-2025']).sort, records.select { |r| r['status'] == 'published' }.map { |r| r['content_id'] }.sort
    assert records.all? { |r| AstraNews::TYPES.include?(r['type']) }
    assert records.all? { |r| !r['image'] && !r['author'] && !r['published_at'] }
    assert_equal ['https://github.com/astra-vision/PaSCo', 'https://ieee-iv.org/2025/'], records.filter_map { |r| r['external_url'] }.sort
    assert_nil records.find { |r| r['content_id'] == 'news-matswap-egsr-2025' }['related_output']
    assert_equal 'pasco', records.find { |r| r['content_id'] == 'news-pasco-cvpr-2024' }['related_output']
    validate(records)
    assert_equal 7, records.count { |r| r['date_precision'] == 'year' }
    assert_equal HOME_IDS, AstraNews.ordered(records.select { |r| r['homepage'] }).first(3).map { |r| r['content_id'] }
    assert_equal AstraNews.ordered(records), AstraNews.ordered(records.reverse)
  end

  def test_creation_is_stored_as_draft_with_unchanged_body
    path = File.join(ROOT, '_news/2022-07-01-astra-creation.md')
    assert File.file?(path)
    creation = SiteValidation.front_matter(path)
    assert_equal 'draft', creation['status']
    assert_equal false, creation['homepage']
    body = File.read(path).split(/^---\s*$\n?/, 3)[2]
    assert_equal 'eabbcb640d5a89be00b97e212da831ba186911a12e0febf4d4d54700f715e71d', Digest::SHA256.hexdigest(body)
  end

  def test_precision_and_ranges
    assert_equal '2025', AstraNews.date_label('event_date' => '2025', 'date_precision' => 'year')
    assert_equal 'July 2024', AstraNews.date_label('event_date' => '2024-07', 'date_precision' => 'month')
    assert_equal '22–25 June 2025', AstraNews.date_label('event_date' => '2025-06-22', 'end_date' => '2025-06-25', 'date_precision' => 'day')
    assert_equal '14–24 July 2024', AstraNews.date_label('event_date' => '2024-07-14', 'end_date' => '2024-07-24', 'date_precision' => 'day')
    assert_equal '30 December 2024 – 2 January 2025', AstraNews.date_label('event_date' => '2024-12-30', 'end_date' => '2025-01-02', 'date_precision' => 'day')
    [['2025-02-29', 'day'], ['2025-13', 'month'], ['2025', 'day'], ['2025-01-01', 'year']].each do |value, precision|
      assert_raises(RuntimeError) { AstraNews.date_parts(value, precision) }
    end
    original = records.first
    %w[type status slug content_id].each do |key|
      assert_raises(RuntimeError) { validate([original.merge(key => 'INVALID')]) }
    end
    assert_raises(RuntimeError) { validate([original, original]) }
    assert_raises(RuntimeError) { validate([original.merge('external_url' => 'javascript:alert(1)')]) }
    assert_raises(RuntimeError) { validate([original.merge('image' => '/assets/img/missing.jpg', 'image_alt' => 'Missing')]) }
    assert_raises(RuntimeError) { validate([original.merge('related_output' => 'unverified')]) }
    assert_raises(RuntimeError) { validate([original.merge('event_date' => '2025-06-22', 'date_precision' => 'day', 'end_date' => '2025-06-21')]) }
    image = '/assets/img/publication_preview/2023-pasco.gif'
    assert_raises(RuntimeError) { validate([original.merge('image' => image)]) }
    validate([original.merge('image' => image, 'image_alt' => 'PaSCo research preview')])
  end

  def test_drafts_images_months_and_editorial_privacy_in_real_jekyll_fixture
    Dir.mktmpdir('astra-news-fixture-') do |root|
      %w[_news _projects _layouts _includes/news _data assets/img].each { |p| FileUtils.mkdir_p(File.join(root, p)) }
      FileUtils.cp_r(File.join(ROOT, '_includes/news/.'), File.join(root, '_includes/news'))
      FileUtils.cp(File.join(ROOT, '_includes/news.html'), File.join(root, '_includes'))
      FileUtils.cp(File.join(ROOT, '_layouts/news.html'), File.join(root, '_layouts'))
      File.write(File.join(root, '_layouts/default.html'), '{{ content }}')
      File.write(File.join(root, 'index.html'), "---\n---\n{% include news.html %}")
      FileUtils.cp(File.join(ROOT, 'assets/img/publication_preview/2023-pasco.gif'), File.join(root, 'assets/img/fixture.gif'))
      base = records.find { |r| r['content_id'] == 'news-acvss-2025' }.merge(
        'layout' => 'news', 'source' => 'PRIVATE-EDITORIAL-SENTINEL', 'author' => 'PRIVATE-AUTHOR-SENTINEL',
        'event_date' => '2024-07', 'date_precision' => 'month')
      [base.merge('content_id' => 'fixture-image', 'slug' => 'fixture-image', 'image' => '/assets/img/fixture.gif', 'image_alt' => 'Fixture research preview', 'image_credit' => 'Fixture credit'),
       base.merge('content_id' => 'fixture-no-image', 'slug' => 'fixture-no-image'),
       base.merge('content_id' => 'fixture-draft', 'slug' => 'fixture-draft', 'status' => 'draft')].each do |r|
        body = r['status'] == 'draft' ? 'DRAFT-CONTENT-SENTINEL' : (r['image'] ? 'Fixture body' : '')
        File.write(File.join(root, "_news/#{r['slug']}.md"), r.to_yaml + "---\n\n#{body}\n")
      end
      ['', '/astra-team.github.io'].each do |baseurl|
        destination = File.join(root, baseurl.empty? ? 'root-build' : 'subpath-build')
        config = Jekyll.configuration('source' => root, 'destination' => destination, 'baseurl' => baseurl,
          'quiet' => true, 'plugins' => [], 'exclude' => %w[root-build subpath-build],
          'collections' => { 'news' => { 'output' => true }, 'projects' => { 'output' => true } })
        Jekyll::Site.new(config).process
        refute File.exist?(File.join(destination, 'news/fixture-draft/index.html'))
        html = Dir[File.join(destination, '**/*.html')].map { |p| File.read(p) }.join
        %w[DRAFT-CONTENT-SENTINEL PRIVATE-EDITORIAL-SENTINEL PRIVATE-AUTHOR-SENTINEL].each { |s| refute_includes html, s }
        with_image = Nokogiri::HTML(File.read(File.join(destination, 'news/fixture-image/index.html')))
        assert_equal baseurl + '/assets/img/fixture.gif', with_image.at_css('img')['src']
        assert_equal 'Fixture research preview', with_image.at_css('img')['alt']
        assert_equal 'Fixture credit', with_image.at_css('figcaption').text
        assert_equal 'July 2024', with_image.at_css('time').text
        assert_equal '2024-07', with_image.at_css('time')['datetime']
        without = Nokogiri::HTML(File.read(File.join(destination, 'news/fixture-no-image/index.html')))
        assert_empty without.css('figure, img')
        assert_equal base['summary'], without.at_css('.astra-news-body').text
        home = Nokogiri::HTML(File.read(File.join(destination, 'index.html')))
        assert_equal 2, home.css('.astra-news-row').size
        assert_equal 1, home.css('figure').size
      end
    end
  end

  def test_generated_site
    destination = ENV['PHASE7_SITE']
    skip 'Set PHASE7_SITE to inspect a production artifact' unless destination
    baseurl = ENV.fetch('PHASE7_BASEURL', '')
    archive = Nokogiri::HTML(File.read(File.join(destination, 'news/index.html')))
    assert_equal %w[2025 2024 2023 2022], archive.css('[id^="news-year-"]').map(&:text)
    assert_equal 10, archive.css('.astra-news-row').size
    assert_equal 10, archive.css('.astra-news-type').size
    assert_empty archive.css('.astra-news-image, .astra-news-row img')
    published = records.select { |r| r['status'] == 'published' }
    expected = AstraNews.ordered(published).map { |r| r['content_id'] }
    assert_equal expected, archive.css('.astra-news-row').map { |n| n['data-news-id'] }
    assert_equal (NEW_IDS + ['news-plenary-2025']).sort, expected.sort
    assert_empty archive.css('#news-legacy, [data-news-id="news-astra-creation-2022"]')
    refute File.exist?(File.join(destination, 'news/2022-07-01-astra-creation/index.html'))
    # Check all public text artifacts, including sitemap/feed, not just listings.
    public_text = Dir[File.join(destination, '**/*.{html,xml,json}')].map { |p| File.read(p) }.join
    ['2022-07-01-astra-creation', 'news-astra-creation-2022', '20xx',
     'historical-review', 'historical details await editorial review',
     'Historical announcement preserved', 'editorial warning'].each do |text|
      refute_includes public_text.downcase, text.downcase
    end
    published.each do |r|
      doc = Nokogiri::HTML(File.read(File.join(destination, "news/#{r['slug']}/index.html")))
      assert_equal r['title'], doc.at_css('h1').text
      assert_equal AstraNews.date_label(r), doc.at_css('.astra-news-date').text
      assert_equal r['type'].tr('-', ' '), doc.at_css('.astra-news-type').text
      assert_empty doc.css('.astra-news-image')
      assert_empty doc.css('.astra-news-date time') if r['date_precision'] == 'year'
      assert_empty doc.css('iframe, .astra-news-body script')
      refute_includes doc.text, r['source']
      assert doc.css('a').any? { |a| a['href'] == baseurl + '/news/' }
      assert_includes doc.text, r['summary'] if NEW_IDS.include?(r['content_id'])
    end
    home = Nokogiri::HTML(File.read(File.join(destination, 'index.html')))
    assert_equal HOME_IDS, home.css('.astra-news-row').map { |n| n['data-news-id'] }
    assert_empty home.css('[data-news-id="news-astra-creation-2022"]')
    assert home.css('.astra-news a').any? { |a| a.text.include?('View all news') && a['href'] == baseurl + '/news/' }
    assert_equal 3, home.css('.astra-news .news-title').size
    %w[open-source-2023 open-source-2024 pasco-cvpr-2024].each do |slug|
      doc = Nokogiri::HTML(File.read(File.join(destination, "news/#{slug}/index.html")))
      target = baseurl + '/outputs/' + (slug.start_with?('pasco') ? '#pasco' : '')
      assert doc.css('a').any? { |a| a['href'] == target }
    end
  end
end
