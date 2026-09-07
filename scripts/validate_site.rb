require 'date'
require 'find'
require 'nokogiri'
require 'pathname'
require 'uri'
require 'yaml'
require_relative 'validate_bibliography'

module SiteValidation
  ROOT = File.expand_path('..', __dir__)
  REQUIRED_ROUTES = %w[index.html research/index.html team/index.html
                       team/fawzi-nashashibi.html publications/index.html info/index.html
                       news/2022-07-01-astra-creation/index.html
                       news/2025-01-20-plenary/index.html 404.html].freeze
  PHASE2_ROUTES = %w[research/vision/index.html research/perception/index.html
                    research/mapping/index.html research/decision/index.html
                    research/cooperative/index.html research/cross-cutting/index.html
                    projects/index.html outputs/index.html platforms/index.html
                    news/index.html about/index.html].freeze
  CREDENTIALS = /AIza[\w-]{35}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/n
  FORBIDDEN_HOST = /polyfill[.]io/i

  def self.check_content(data, path)
    raise "credential pattern in #{path} (value withheld)" if data.b.match?(CREDENTIALS)
    raise "forbidden script host in #{path}" if data.b.match?(FORBIDDEN_HOST)
  end

  def self.yaml_nodes(node, path)
    if node.is_a?(Psych::Nodes::Mapping)
      keys = node.children.each_slice(2).map(&:first)
      raise "duplicate YAML key in #{path}" unless keys.map(&:value).uniq.size == keys.size
    end
    Array(node.children).each { |child| yaml_nodes(child, path) } if node.respond_to?(:children)
  end

  def self.source(root = ROOT)
    paths = %w[_config.yml Gemfile README.md].map { |p| File.join(root, p) }
    paths += Dir[File.join(root, '{_data,_pages,_news,_projects,_research_axes,_layouts,_includes,_plugins,scripts,tests,.github,assets/js,assets/css}/**/*')].select { |p| File.file?(p) }
    paths += [File.join(root, '404.html'), File.join(root, 'robots.txt')]
    paths.each do |path|
      text = File.read(path)
      check_content(text, path)
      yaml = if path.end_with?('.yml', '.yaml')
               text
             elsif text.start_with?("---\n", "---\r\n")
               text.split(/^---\s*$\n?/, 3)[1]
             end
      next unless yaml
      yaml_nodes(Psych.parse_stream(yaml), path)
      YAML.safe_load(yaml, permitted_classes: [Date, Time], aliases: false)
    end
    BibliographyValidation.validate(File.join(root, '_bibliography/rits-astra.bib'))
    content_model(root)
    puts 'PASS: YAML/front matter, source credential/host patterns, bibliography'
  end

  def self.front_matter(path)
    text = File.read(path)
    raise 'content document requires front matter' unless text.start_with?("---\n")
    YAML.safe_load(text.split(/^---\s*$\n?/, 3)[1], permitted_classes: [Date, Time], aliases: false)
  end

  def self.records(records)
    raise 'structured records must be a list' unless records.is_a?(Array)
    ids = records.map do |record|
      raise 'record requires a stable id and title' unless record.is_a?(Hash) &&
        record['id'].is_a?(String) && record['id'].match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/) &&
        record['title'].is_a?(String) && !record['title'].strip.empty?
      if record['url'] && !record['url'].match?(%r{\A(?:https?://|/(?!/))})
        raise 'record URL must be HTTP(S) or root-relative'
      end
      record['id']
    end
    raise 'duplicate record id' unless ids.uniq.size == ids.size
  end

  def self.content_model(root = ROOT)
    %w[outputs platforms].each do |type|
      records(YAML.safe_load_file(File.join(root, "_data/#{type}.yml")))
    end
    %w[_research_axes _projects].each do |directory|
      ids = Dir[File.join(root, directory, '*.md')].map do |path|
        data = front_matter(path)
        records([{ 'id' => data['content_id'], 'title' => data['title'] }])
        raise 'document id must match filename' unless data['content_id'] == File.basename(path, '.md')
        data['content_id']
      end
      raise 'duplicate document id' unless ids.uniq.size == ids.size
    end
    puts 'PASS: content model IDs and structured records'
  end

  def self.forbidden_path?(relative)
    parts = relative.split('/')
    return true if parts.any? { |p| p.start_with?('.') && p != '.nojekyll' }
    return true if %w[scripts tests docs bin vendor node_modules _responsive].include?(parts.first)
    relative.match?(/(?:\A|\/)(?:Dockerfile[^\/]*|(?:docker-)?compose[^\/]*\.ya?ml|Gemfile(?:\.lock)?|README(?:\.md)?|CONTRIBUTING\.md|TODO\.txt|.*htpasswd|.*htaccess|jsconfig\.json|package(?:-lock)?\.json)\z/i) ||
      relative.match?(/\.(?:py|rb|sh|ya?ml|env|lock|log)\z/i)
  end

  def self.artifact(destination, baseurl = '')
    destination = File.expand_path(destination)
    raise 'artifact directory missing' unless File.directory?(destination)
    baseurl = baseurl.to_s.sub(%r{/+$}, '')
    raise 'baseurl must start with /' unless baseurl.empty? || baseurl.start_with?('/')
    documents = {}
    Find.find(destination) do |path|
      next if path == destination
      relative = Pathname.new(path).relative_path_from(Pathname.new(destination)).to_s
      raise "forbidden artifact path: #{relative}" if forbidden_path?(relative) || File.symlink?(path)
      next unless File.file?(path)
      data = File.binread(path)
      check_content(data, relative)
      documents[relative] = Nokogiri::HTML(data) if relative.end_with?('.html')
    end
    (REQUIRED_ROUTES + PHASE2_ROUTES).each { |p| raise "required route missing: #{p}" unless documents.key?(p) }
    phase3_stylesheet(destination, documents.fetch('index.html'), baseurl)
    documents.each do |relative, doc|
      page_uri = 'https://local.invalid' + baseurl + '/' + relative.sub(/index\.html$/, '')
      references = doc.css('[href], [src]').flat_map do |node|
        %w[href src].filter_map { |attribute| node[attribute] }
      end
      references += doc.css('[srcset]').flat_map { |node| node['srcset'].split(',').map { |part| part.strip.split.first } }
      references.compact.each do |reference|
        next if reference.empty? || reference.match?(/\A(?:mailto:|tel:|data:|javascript:)/)
        begin
          uri = URI.join(page_uri, reference)
        rescue URI::Error
          raise "invalid URL in #{relative} (value withheld)"
        end
        next unless uri.host == 'local.invalid'
        decoded = URI::DEFAULT_PARSER.unescape(uri.path)
        unless baseurl.empty? || decoded == baseurl || decoded.start_with?(baseurl + '/')
          raise "link escapes staging baseurl in #{relative}"
        end
        local = decoded.delete_prefix(baseurl).sub(%r{\A/}, '')
        candidates = [local, local + 'index.html', local + '/index.html', local + '.html']
        target = candidates.find do |candidate|
          expanded = File.expand_path(candidate, destination)
          expanded.start_with?(destination + '/') && File.file?(expanded)
        end
        raise "missing local target from #{relative} (value withheld)" unless target
        # Publication fragments are search terms, not necessarily element IDs.
        if uri.fragment && !uri.fragment.empty? && documents[target] && target != 'publications/index.html'
          fragment = URI::DEFAULT_PARSER.unescape(uri.fragment)
          unless documents[target].css('[id], a[name]').any? { |n| n['id'] == fragment || n['name'] == fragment }
            raise "missing local fragment from #{relative} (value withheld)"
          end
        end
      end
    end
    puts "PASS: #{documents.size} HTML routes, internal links/assets, forbidden files, credential/host patterns (baseurl=#{baseurl.inspect})"
  end

  def self.phase3_stylesheet(destination, homepage, baseurl)
    expected = "#{baseurl}/assets/css/main.css"
    links = homepage.css('link[rel="stylesheet"]').map { |link| link['href'].to_s }
    unless links.any? { |href| href.match?(/\A#{Regexp.escape(expected)}\?v=\d{14}\z/) }
      raise 'homepage requires a baseurl-safe, build-versioned main stylesheet'
    end
    path = File.join(destination, 'assets/css/main.css')
    raise 'compiled main stylesheet missing' unless File.file?(path)
    css = File.read(path).gsub(%r{/\*.*?\*/}m, '')
    %w[astra-hero-heading astra-button astra-intro astra-research-grid astra-card-image astra-card-heading].each do |selector|
      raise "compiled Phase 3 selector missing: #{selector}" unless css.match?(/\.#{selector}\s*\{/)
    end
    puts 'PASS: versioned Phase 3 stylesheet URL and compiled selectors'
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    SiteValidation.source
    SiteValidation.artifact(ARGV[0] || File.join(SiteValidation::ROOT, '_site'), ARGV[1] || '') unless ARGV[0] == '--source-only'
  rescue StandardError => error
    # Parser error details may contain source values. Only our fixed messages are safe.
    message = error.instance_of?(RuntimeError) ? error.message : error.class.to_s
    abort "FAIL: #{message}"
  end
end
