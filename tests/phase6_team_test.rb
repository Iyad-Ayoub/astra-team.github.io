require 'minitest/autorun'
require_relative '../scripts/validate_site'

class Phase6TeamTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  CURRENT = {
    'leadership' => ['Fawzi Nashashibi', 'Benazouz Bradai'],
    'permanent' => ['Raoul de Charette', 'Guy Fayolle', 'Jean-Marc Lasgouttes', 'Gérard Le Lann'],
    'industrial' => ['Alexandre Boulch', 'Andrei Bursuc',
      'Fernando Garrido', 'Axel Jeanne', 'Renaud Marlet', 'Gilles Puy',
      'Tiago Rocha Goncalves', 'Tuan Hung Vu'],
    'associates' => ['Iyad Abuhadrous', 'Itheri Yahiaoui', 'Paul Roger-Dauvergne'],
    'phd' => ['Fatima Balde', 'Mohammad Fahes', 'Islem Kobbi', 'Elias Maharmeh',
      'Tetiana Martyniuk', 'Antionios Tragoudaras', 'William Gaudelier'],
    'administration' => ['Christelle Leclerc']
  }.freeze
  REQUIRED_ALUMNI = ['Karim Essalmi', 'Noël Nadal', 'Yacine Ben Ameur',
    'Anh-Quan Cao', 'Amina Ghoul', 'Ivan Lopes', 'Jiahao Zhang', 'Fabio Pizzati',
    'Renaud Poncelet', 'Anne Verroust-Blondet', 'Zayed Alsayed', 'Hussam Atoui',
    'Nelson De Moura', 'Emmanuel Doucet', 'Kathia Melbouci', 'Kaouther Messaoud',
    'Clotilde Monnet', 'Patrick Pérez', 'Paulo Resende', 'Geoffroy Cousin', 'Martial Le-Henaff', 'Abigaïl Palma'].freeze
  EXTRA_ALUMNI = ['Anne Mathurin', 'Souhaiel Ben Salem', 'Tan Khiem Huynh',
    'Clément Weinreich', 'Matteo Marengo', 'Weihao Xia'].freeze
  PENDING = ['Yasser Benigmim', 'Soumava Paul', 'Jonathan Seele'].freeze
  ALIASES = {
    'Fernando Garrido' => 'Fernando Garrido Carpio',
    'Tiago Rocha Goncalves' => 'Tiago Goncalves Rocha',
    'Tuan Hung Vu' => 'Tuan-Hung Vu',
    'Anne Verroust-Blondet' => 'Anne-Verroust Blondet',
    'Nelson De Moura' => 'Nelson de Moura'
  }.freeze

  def roster
    YAML.safe_load_file(File.join(ROOT, '_data/team_roster.yml'))
  end

  def legacy
    YAML.safe_load_file(File.join(ROOT, '_data/team.yml'), permitted_classes: [Date])
  end

  def test_approved_membership_and_leadership
    current = roster.select { |r| r['status'] == 'current' }
    alumni = roster.select { |r| r['status'] == 'alumni' }
    assert_equal 25, current.size
    assert_equal 28, alumni.size
    CURRENT.each do |category, names|
      assert_equal names, current.select { |r| r['category'] == category }.sort_by { |r| r['display_order'] }.map { |r| r['name'] }
    end
    assert_equal (REQUIRED_ALUMNI + EXTRA_ALUMNI).sort, alumni.map { |r| r['name'] }.sort
    assert_equal 53, roster.map { |r| r['id'] }.uniq.size
    assert_equal 53, roster.map { |r| r['name'] }.uniq.size
    assert_equal 'ASTRA Team Leader', current.find { |r| r['name'] == 'Fawzi Nashashibi' }['role']
    assert_equal 'Valeo Scientific Leader', current.find { |r| r['name'] == 'Benazouz Bradai' }['role']
    assert_equal 1, roster.count { |r| r['role'] == 'ASTRA Team Leader' }
    {
      'christelle-leclerc' => ['current', 'Team Assistant'],
      'abigail-palma' => ['alumni', 'Former Administrative Assistant'],
      'iyad-abuhadrous' => ['current', 'R&D Engineer'],
      'itheri-yahiaoui' => ['current', 'Research Associate'],
      'paul-roger-dauvergne' => ['current', 'Integration Engineer'],
      'martial-le-henaff' => ['alumni', 'Former Team Assistant'],
      'raoul-de-charette' => ['current', 'Researcher'],
      'guy-fayolle' => ['current', 'Researcher Emeritus'],
      'jean-marc-lasgouttes' => ['current', 'Researcher'],
      'gerard-le-lann' => ['current', 'Researcher Emeritus']
    }.each do |id, expected|
      assert_equal expected, roster.find { |r| r['id'] == id }.values_at('status', 'role')
    end
    martial = alumni.find { |r| r['id'] == 'martial-le-henaff' }
    assert_empty martial.keys & %w[end_date current_position current_organization profile_url]
    abigail = alumni.find { |r| r['id'] == 'abigail-palma' }
    assert_empty abigail.keys & %w[end_date current_position current_organization profile_url photo bio]
    %w[karim-essalmi noel-nadal].each do |id|
      member = alumni.find { |r| r['id'] == id }
      refute_nil member
      refute member.key?('end_date')
    end
    PENDING.each { |name| refute roster.any? { |r| r['name'] == name } }
  end

  def test_no_fabricated_links_photos_employment_or_dates
    roster.each do |r|
      old_name = ALIASES.fetch(r['name'], r['name'])
      old = legacy.find { |o| "#{o['firstname']} #{o['lastname']}" == old_name }
      assert_empty r.keys & %w[start_date end_date bio research_interests last_verified source_years]
      if old && old['url'] && !old['url'].empty?
        assert_equal old['url'], r['profile_url']
      else
        refute r.key?('profile_url')
      end
      if old && old['profilepic']
        assert_equal "/assets/img/team/#{old['profilepic']}", r['photo']
      else
        refute r.key?('photo')
      end
      if r['current_position']
        assert_equal old['alumni_now'].gsub(/<[^>]*>/, ''), r['current_position']
      end
    end
    assert_equal 'Inria', roster.find { |r| r['name'] == 'Fawzi Nashashibi' }['affiliation']
    assert_equal 'Valeo', roster.find { |r| r['name'] == 'Benazouz Bradai' }['affiliation']
    assert_equal 'University of Reims', roster.find { |r| r['name'] == 'Itheri Yahiaoui' }['affiliation']
    %w[elias-maharmeh tetiana-martyniuk].each do |id|
      assert_equal 'CIFRE', roster.find { |r| r['id'] == id }['additional_role']
    end
  end

  def test_schema_rejects_ambiguous_status_and_duplicate_ids
    SiteValidation.team_records(roster)
    record = roster.first
    assert_raises(RuntimeError) { SiteValidation.team_records([record, record]) }
    assert_raises(RuntimeError) { SiteValidation.team_records([record.merge('status' => 'unknown')]) }
    assert_raises(RuntimeError) { SiteValidation.team_records([record.merge('status' => 'alumni')]) }
    assert_raises(RuntimeError) { SiteValidation.team_records([record.merge('profile_url' => 'javascript:void(0)')]) }
    assert_raises(RuntimeError) { SiteValidation.team_records([record.merge('photo' => '/elsewhere/picture.png')]) }
  end

  def test_rendered_team
    destination = ENV['PHASE6_SITE']
    skip 'Set PHASE6_SITE for artifact checks' unless destination
    base = ENV.fetch('PHASE6_BASEURL', '')
    doc = Nokogiri::HTML(File.read(File.join(destination, 'team/index.html')))
    team = doc.at_css('.astra-team')
    refute_nil team
    assert_equal ['Scientific Leadership', 'Permanent Researchers',
      'Associate / Industrial Research Members', 'Associated Researchers & Engineers',
      'PhD Students', 'Administrative Support', 'Alumni & Former Members'],
      team.css('h2').map(&:text)
    CURRENT.each do |category, names|
      assert_equal names, team.css("[aria-labelledby='team-#{category}'] h3").map(&:text)
    end
    assert_equal (REQUIRED_ALUMNI + EXTRA_ALUMNI).sort,
      team.css('[aria-labelledby="team-alumni"] h3').map(&:text).sort
    assert_equal 25, team.css('[data-status="current"]').size
    assert_equal 28, team.css('[data-status="alumni"]').size
    assert_includes team.at_css('[aria-labelledby="team-administration"] #christelle-leclerc').text, 'Team Assistant'
    assert_includes team.at_css('.astra-team-alumni #abigail-palma').text, 'Former Administrative Assistant'
    assert_empty team.css('[data-status="current"]#abigail-palma')
    {
      'iyad-abuhadrous' => 'R&D Engineer',
      'itheri-yahiaoui' => 'Research Associate',
      'paul-roger-dauvergne' => 'Integration Engineer'
    }.each do |id, role|
      assert_equal role, team.at_css("[aria-labelledby='team-associates'] ##{id} .astra-person-role").text
    end
    refute_includes team.at_css('#iyad-abuhadrous').text, 'Non-permanent Researcher'
    refute_includes team.at_css('#iyad-abuhadrous').text, 'Senior Researcher'
    %w[Engineers Postdocs Visitors].each { |title| refute_includes team.css('h2').map(&:text), title }
    refute_includes team.css('h2').map(&:text), 'Other Researchers / Research Associates'
    assert_includes team.at_css('.astra-team-alumni #martial-le-henaff').text, 'Former Team Assistant'
    assert_empty team.css('[data-status="current"]#martial-le-henaff')
    assert_empty team.css('[aria-labelledby="team-phd"] #karim-essalmi, [aria-labelledby="team-phd"] #noel-nadal')
    assert_includes team.at_css('#fawzi-nashashibi').text, 'ASTRA Team Leader'
    assert_includes team.at_css('#benazouz-bradai').text, 'Valeo Scientific Leader'
    refute_includes team.at_css('#benazouz-bradai').text, 'ASTRA Team Leader'
    refute_includes team.css('h2').map(&:text).join, 'Postdoc'
    assert_empty team.css('.astra-team-alumni img')
    assert_equal 21, team.css('img').size
    team.css('img').each do |img|
      assert img['src'].start_with?("#{base}/assets/img/team/")
      assert_equal '72', img['width']
      assert_equal '72', img['height']
      refute_includes img['src'], 'anonymous'
    end
    assert team.at_css("#fawzi-nashashibi a[href='#{base}/team/fawzi-nashashibi.html']")
    PENDING.each { |name| refute_includes team.text, name }
    roster.each do |r|
      assert_equal 1, team.css("##{r['id']}").size
      if r['profile_url']
        url = r['profile_url'].start_with?('/') ? base + r['profile_url'] : r['profile_url']
        assert team.at_css("##{r['id']} a[href='#{url}']")
      end
    end
    assert_empty team.css('time')
  end
end
