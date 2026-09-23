require 'json'

# Emits browser-safe configuration for the GitHub App browser flow. No
# privileged credential is ever emitted.
module AstraCms
  class AdminConfigGenerator < Jekyll::Generator
    safe true
    priority :lowest

    def generate(site)
      github_client_id = ENV.fetch('GITHUB_APP_CLIENT_ID', '').strip
      github_broker_url = ENV.fetch('GITHUB_AUTH_BROKER_URL', '').strip.sub(%r{/\z}, '')
      github_repo_owner = ENV.fetch('GITHUB_REPO_OWNER', 'Iyad-Ayoub').strip
      github_repo_name = ENV.fetch('GITHUB_REPO_NAME', 'astra-team.github.io').strip
      unless github_repo_owner == 'Iyad-Ayoub' && github_repo_name == 'astra-team.github.io'
        raise 'GitHub CMS repository identity must remain Iyad-Ayoub/astra-team.github.io'
      end
      if ENV['CMS_REQUIRE_CONFIG'] == 'true' && (github_client_id.empty? || github_broker_url.empty?)
        raise 'GITHUB_APP_CLIENT_ID and GITHUB_AUTH_BROKER_URL are required for the CMS production build'
      end

      config = {
        githubAuth: {
          clientId: github_client_id,
          brokerUrl: github_broker_url,
          repoOwner: github_repo_owner,
          repoName: github_repo_name
        }
      }
      page = Jekyll::PageWithoutAFile.new(site, site.source, 'assets/js/admin', 'config.js')
      page.content = "window.ASTRA_CMS_CONFIG = Object.freeze(#{JSON.generate(config)});\n"
      page.data['layout'] = nil
      page.data['sitemap'] = false
      site.pages << page
    end
  end
end
