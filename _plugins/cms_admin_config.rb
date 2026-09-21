require 'json'

# Emits browser-safe Supabase configuration at build time. Only the project URL
# and publishable key are permitted here; privileged credentials are rejected.
module AstraCms
  class AdminConfigGenerator < Jekyll::Generator
    safe true
    priority :lowest

    def generate(site)
      url = ENV.fetch('SUPABASE_URL', '').strip
      key = ENV.fetch('SUPABASE_PUBLISHABLE_KEY', '').strip
      if ENV['CMS_REQUIRE_CONFIG'] == 'true' && (url.empty? || key.empty?)
        raise 'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required for the CMS production build'
      end

      page = Jekyll::PageWithoutAFile.new(site, site.source, 'assets/js/admin', 'config.js')
      page.content = "window.ASTRA_CMS_CONFIG = Object.freeze(#{JSON.generate({ supabaseUrl: url, supabasePublishableKey: key })});\n"
      page.data['layout'] = nil
      page.data['sitemap'] = false
      site.pages << page
    end
  end
end
