# Context is explicit for deployment; local root/subpath builds remain testable.
module AstraIndexing
  def self.staging?(baseurl, context = ENV['ASTRA_BUILD_CONTEXT'])
    raise 'Unknown ASTRA_BUILD_CONTEXT' unless [nil, '', 'production', 'staging'].include?(context)
    raise 'Production must be built at the site root' if context == 'production' && !baseurl.to_s.empty?
    context == 'staging' || (context.to_s.empty? && !baseurl.to_s.empty?)
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  site.config['astra_staging'] = AstraIndexing.staging?(site.baseurl)
end
