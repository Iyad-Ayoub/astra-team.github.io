require 'json'
require 'minitest/autorun'

module Jekyll
  class Generator
    def self.safe(*) = nil
    def self.priority(*) = nil
  end
  class PageWithoutAFile
    attr_accessor :content, :data
    def initialize(*) = @data = {}
  end
end

require_relative '../_plugins/cms_admin_config'

class CmsAdminConfigTest < Minitest::Test
  Site = Struct.new(:source, :pages)

  def with_env(values)
    original = ENV.to_h
    ENV.replace(original.merge(values))
    yield
  ensure
    ENV.replace(original)
  end

  def generated(values)
    with_env(values) do
      site = Site.new(Dir.pwd, [])
      AstraCms::AdminConfigGenerator.new.generate(site)
      JSON.parse(site.pages.last.content[/Object\.freeze\((.*)\);/, 1])
    end
  end

  def github_env
    { 'CMS_REQUIRE_CONFIG' => 'true', 'GITHUB_APP_CLIENT_ID' => 'client-id', 'GITHUB_AUTH_BROKER_URL' => 'https://broker.example', 'GITHUB_REPO_OWNER' => 'Iyad-Ayoub', 'GITHUB_REPO_NAME' => 'astra-team.github.io' }
  end

  def test_github_configuration_is_sufficient_for_production
    config = generated(github_env)
    assert_equal 'client-id', config.dig('githubAuth', 'clientId')
    assert_equal %w[githubAuth], config.keys
  end

  def test_required_github_configuration_is_rejected_when_missing
    error = assert_raises(RuntimeError) { generated(github_env.merge('GITHUB_AUTH_BROKER_URL' => '')) }
    assert_match(/GITHUB_APP_CLIENT_ID and GITHUB_AUTH_BROKER_URL/, error.message)
  end
end
