require 'minitest/autorun'
require 'jekyll'
require 'jekyll/scholar'
require 'digest'
require 'json'
require 'tmpdir'
require 'fileutils'
require_relative '../scripts/validate_site'
require_relative '../_plugins/publication_presentation'

class Phase8PublicationsTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  HASHES = {
    '_bibliography/rits-astra.bib' => 'c5f03fdefae21026eda865f99cb10d167b672d90afc082f42938e9262a01c14a',
    '_data/team.yml' => '2dec38f1b48f8e041b70cfb84449a863c2ad09d5d0987723b85dc982cd467028',
    '_data/coauthors.yml' => 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    'scripts/publication-update.sh' => '030972e452dca9dd92fcc2088b80bde19667b46ab29897498f55b5722cd5ae21',
    'scripts/hal-export-to-bib.py' => '6b7cc85889885c98c962fa070d45f801586a257a1a1d862add6432b0dc415173'
  }.freeze

  def entries
    BibTeX.open(File.join(ROOT, '_bibliography/rits-astra.bib')).entries.values
  end

  def test_corpus_and_ingestion_boundary
    HASHES.each { |path, sha| assert_equal sha, Digest::SHA256.file(File.join(ROOT, path)).hexdigest, path }
    assert_equal 259, entries.size
    assert_equal 259, entries.map(&:key).uniq.size
  end

  def test_normalization_and_safe_actions
    mapping = {
      'article' => 'Journal', 'inproceedings' => 'Conference', 'conference' => 'Conference',
      'unpublished' => 'Preprint', 'preprint' => 'Preprint', 'phdthesis' => 'Thesis',
      'mastersthesis' => 'Thesis', 'thesis' => 'Thesis', 'techreport' => 'Technical Report',
      'book' => 'Book / Chapter', 'inbook' => 'Book / Chapter', 'incollection' => 'Book / Chapter',
      'misc' => 'Other', 'unknown' => 'Other'
    }
    mapping.each do |type, label|
      entry = BibTeX::Entry.new(bibtex_type: type.to_sym, bibtex_key: 'fixture', year: '2025')
      before = entry.to_s
      assert_equal label, AstraPublications.view(entry, {})['type']
      assert_equal before, entry.to_s
    end
    entry = BibTeX::Entry.new(bibtex_type: :techreport, bibtex_key: 'fixture', year: '2025', type: 'Research Report')
    assert_equal 'Technical Report', AstraPublications.view(entry, { 'type' => 'Research Report' })['type']
    assert_equal '2025', AstraPublications.view(entry, {})['date']
    entry[:month] = 'Jul'
    assert_equal 'July 2025', AstraPublications.view(entry, {})['date']
    entry[:month] = 'not-a-month'
    assert_equal '2025', AstraPublications.view(entry, {})['date']
    assert_nil AstraPublications.view(entry, {})['venue']
    assert_equal 'Institution', AstraPublications.view(entry, { 'institution' => 'Institution' })['venue']
    assert_nil AstraPublications.view(entry, {})['pdf']
    assert_nil AstraPublications.view(entry, {})['doi']
    entry[:url] = 'https://example.org/paper'
    assert_nil AstraPublications.hal_url(entry)
    assert_nil AstraPublications.view(entry, {})['pdf'] # No generic-URL-as-PDF fallback.
    entry[:hal_id] = 'hal-12345678'
    assert_equal 'https://hal.science/hal-12345678', AstraPublications.hal_url(entry)
    entry[:url] = 'https://inria.hal.science/hal-12345678'
    assert_equal entry[:url].to_s, AstraPublications.hal_url(entry)
    entry.delete(:hal_id)
    entry[:url] = 'https://hal.science.example.org/123'
    assert_nil AstraPublications.hal_url(entry)
    %w[javascript:alert(1) //example.org/file https://user:pass@example.org/file].each { |url| assert_nil AstraPublications.safe_url(url) }
    assert_nil AstraPublications.doi_url('not-a-doi')
    assert_equal 'https://doi.org/10.1234/example%23part%3Fx%3D1', AstraPublications.doi_url('10.1234/example#part?x=1')
    assert_equal 'https://doi.org/10.1234/example', AstraPublications.doi_url('https://doi.org/10.1234/example')
  end

  def test_dynamic_small_corpus_without_second_data_store
    Dir.mktmpdir('astra-publication-fixture-') do |root|
      %w[_layouts _bibliography].each { |p| FileUtils.mkdir_p(File.join(root, p)) }
      FileUtils.cp(File.join(ROOT, '_layouts/bib.html'), File.join(root, '_layouts/bib.html'))
      File.write(File.join(root, '_bibliography/fixture.bib'), <<~BIB)
        @article{test-one, title={Test one}, author={Author, Test}, year={2027}, journal={Test Journal}}
        @inproceedings{test-two, title={Test two}, author={Author, Test}, year={2026}, booktitle={Test Conference}}
      BIB
      File.write(File.join(root, 'index.html'), "---\n---\n{% capture rows %}{% astra_bibliography -f fixture %}{% endcapture %}<p id='total'>{{ publication_count }}</p>{{ rows }}")
      config = Jekyll.configuration('source' => root, 'destination' => File.join(root, '_site'), 'quiet' => true,
        'plugins' => [], 'filtered_bibtex_keywords' => [], 'scholar' => {
          'source' => '_bibliography', 'bibliography_template' => 'bib', 'sort_by' => 'year', 'order' => 'descending',
          'first_name' => [], 'last_name' => [] })
      Jekyll::Site.new(config).process
      doc = Nokogiri::HTML(File.read(File.join(root, '_site/index.html')))
      assert_equal '2', doc.at_css('#total').text
      assert_equal %w[2027 2026], doc.css('.publication-year h2').map(&:text)
      assert_equal ['1 publication', '1 publication'], doc.css('.publication-year-count').map(&:text)
      assert_equal 2, doc.css('details.publication-bibtex').size
      assert_empty doc.css('.publication-hal, .publication-pdf, .publication-doi')
    end
  end

  def test_production_artifact
    destination = ENV['PHASE8_SITE']
    skip 'Set PHASE8_SITE to validate a production artifact' unless destination
    baseurl = ENV.fetch('PHASE8_BASEURL', '')
    doc = Nokogiri::HTML(File.read(File.join(destination, 'publications/index.html')))
    rows = doc.css('.publication-record')
    assert_equal entries.size, rows.size
    assert_equal entries.map(&:key).sort, rows.map { |r| r['data-key'] }.sort
    assert_equal "#{entries.size} publications", doc.at_css('#publication-count').text
    years = entries.group_by { |e| e[:year].to_s }
    assert_equal years.keys.sort.reverse, doc.css('.publication-year').map { |s| s['data-year'] }
    assert_equal years.keys.sort.reverse, doc.css('#publication-year option').drop(1).map { |o| o['value'] }
    assert_equal AstraPublications::TYPES, doc.css('#publication-type option').drop(1).map { |o| o['value'] }
    doc.css('.publication-year').each do |section|
      n = years.fetch(section['data-year']).size
      assert_equal n, section.css('.publication-record').size
      assert_equal "#{n} #{n == 1 ? 'publication' : 'publications'}", section.at_css('.publication-year-count').text
    end
    authors = {}
    bibtex = {}
    by_key = entries.to_h { |e| [e.key, e] }
    rows.each do |row|
      entry = by_key.fetch(row['data-key'])
      view = AstraPublications.view(entry, {})
      assert_equal view['type'], row['data-type']
      assert_equal view['date'], row.at_css('.publication-meta > span:last-child').text
      %w[hal pdf doi].each do |action|
        links = row.css(".publication-#{action}")
        assert_equal(view[action] ? 1 : 0, links.size, "#{entry.key} #{action}")
        assert_equal view[action], links.first['href'] if view[action]
      end
      assert_equal 1, row.css('h3').size
      assert_empty row.css('details[open], [onclick]')
      authors[entry.key] = row.css('.author a').map { |a| [a.text, a['href'].start_with?('/') ? a['href'].delete_prefix(baseurl) : a['href']] }
      bibtex[entry.key] = row.at_css('.publication-bibtex code').text
      assert_equal entry.key, BibTeX.parse(bibtex[entry.key]).entries.values.first.key
    end
    # Snapshots from the unmodified pre-Phase-8 build, covering every record.
    assert_equal 'a1c3a9af1dc5d179c400d7665876f2782e25596593893650645a513e58d0c91e', Digest::SHA256.hexdigest(JSON.generate(authors.sort.to_h))
    assert_equal 'e81a1fa11087bc323713ec494c2067c723ce0c000c162642381b46e7b002ef07', Digest::SHA256.hexdigest(JSON.generate(bibtex.sort.to_h))
    assert doc.at_css('#publication-empty').key?('hidden')
    %w[bibsearch publication-year publication-type].each { |id| refute_nil doc.at_css("label[for='#{id}']") }
    assert_equal 'Search by title, author, venue or keyword', doc.at_css('#bibsearch')['placeholder']
    assert doc.css('script[src]').any? { |s| s['src'].start_with?(baseurl + '/assets/js/bibsearch.js') }
  end
end
