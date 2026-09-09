require 'date'

# Evidence dates are separate from Jekyll's automatic document/file date.
module AstraNews
  TYPES = %w[award event project open-source team collaboration demo].freeze
  SLUG = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  def self.date_parts(value, precision)
    pattern = { 'year' => /\A\d{4}\z/, 'month' => /\A\d{4}-\d{2}\z/, 'day' => /\A\d{4}-\d{2}-\d{2}\z/ }[precision]
    raise 'invalid news date precision/value' unless value.is_a?(String) && pattern && value.match?(pattern)
    parts = value.split('-').map(&:to_i)
    raise 'invalid news calendar date' unless Date.valid_date?(parts[0], parts[1] || 1, parts[2] || 1)
    parts
  end

  def self.date_label(record)
    parts = date_parts(record['event_date'], record['date_precision'])
    return parts[0].to_s if parts.size == 1
    return "#{Date::MONTHNAMES[parts[1]]} #{parts[0]}" if parts.size == 2
    first = Date.iso8601(record['event_date'])
    last = record['end_date'] && Date.iso8601(record['end_date'])
    if last && last != first
      return "#{first.day}–#{last.day} #{last.strftime('%B %Y')}" if first.strftime('%Y-%m') == last.strftime('%Y-%m')
      return "#{first.strftime('%-d %B %Y')} – #{last.strftime('%-d %B %Y')}"
    end
    first.strftime('%-d %B %Y')
  end

  def self.validate(records, root:, output_ids:, project_ids:)
    %w[content_id slug].each do |key|
      values = records.map { |r| r[key] }
      raise "invalid/duplicate news #{key}" unless values.all? { |v| v.is_a?(String) && v.match?(SLUG) } && values.uniq.size == values.size
    end
    records.each do |r|
      raise 'invalid news status/type' unless %w[draft published].include?(r['status']) && TYPES.include?(r['type'])
      raise 'news requires title and summary' unless %w[title summary].all? { |k| r[k].is_a?(String) && !r[k].strip.empty? }
      date_parts(r['event_date'], r['date_precision'])
      if r['end_date']
        date_parts(r['end_date'], 'day')
        raise 'invalid news date range' unless r['date_precision'] == 'day' && r['end_date'] >= r['event_date']
      end
      %w[homepage featured legacy].each do |key|
        raise 'news flags must be booleans' unless !r.key?(key) || [true, false].include?(r[key])
      end
      raise 'news display_order must be an integer' if r.key?('display_order') && !r['display_order'].is_a?(Integer)
      if r['external_url'] && !r['external_url'].empty?
        raise 'news external URL must be HTTPS' unless r['external_url'].match?(%r{\Ahttps://[^\s<>"']+\z})
      end
      if r['image'] && !r['image'].empty?
        path = r['image']
        raise 'news image must be an existing local asset' unless path.match?(%r{\A/assets/img/[a-zA-Z0-9_./-]+\.(?:png|jpe?g|gif|webp)\z}) && !path.split('/').include?('..') && File.file?(File.join(root, path.delete_prefix('/')))
        raise 'news image requires alt text' unless r['image_alt'].is_a?(String) && !r['image_alt'].strip.empty?
      end
      raise 'unknown related news output' if r['related_output'] && !output_ids.include?(r['related_output'])
      raise 'unknown related news project' if r['related_project'] && !project_ids.include?(r['related_project'])
      raise 'news permalink must agree with stable slug' if r['permalink'] && r['permalink'] != "/news/#{r['slug']}/"
    end
  end

  def self.ordered(documents)
    documents.sort_by do |doc|
      r = doc.respond_to?(:data) ? doc.data : doc
      y, m, d = date_parts(r['event_date'], r['date_precision'])
      [-y, -(m || 0), -(d || 0), r.fetch('display_order', 0), r['content_id']]
    end
  end

  def self.prepare(site)
    collection = site.collections['news']
    return unless collection
    validate(collection.docs.map(&:data), root: site.source,
             output_ids: site.data.fetch('outputs', []).map { |r| r['id'] },
             project_ids: site.collections.fetch('projects').docs.map { |d| d.data['content_id'] })
    # Remove drafts before generators (including sitemap) or rendering run.
    collection.docs.select! { |doc| doc.data['status'] == 'published' }
    collection.docs.each do |doc|
      r = doc.data
      r['permalink'] = "/news/#{r['slug']}/"
      r['news_year'] = r['event_date'][0, 4]
      r['news_date_label'] = date_label(r)
    end
    ordered = ordered(collection.docs)
    site.config['news_archive'] = ordered.reject { |d| d.data['legacy'] }
    site.config['news_legacy'] = ordered.select { |d| d.data['legacy'] }
    site.config['news_homepage'] = ordered.select { |d| d.data['homepage'] && !d.data['legacy'] }.first(3)
  end
end

Jekyll::Hooks.register(:site, :post_read) { |site| AstraNews.prepare(site) } if defined?(Jekyll::Hooks)
