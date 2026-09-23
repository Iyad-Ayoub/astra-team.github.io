require 'minitest/autorun'
require 'nokogiri'

class Phase13BAdminTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  ADMIN_PAGE = File.join(ROOT, '_pages/admin/index.html')
  ADMIN_LAYOUT = File.join(ROOT, '_layouts/admin.html')
  CALLBACK_PAGE = File.join(ROOT, '_pages/admin/auth/callback.html')
  APP = File.join(ROOT, 'assets/js/admin/app.js')
  CONFIG_GENERATOR = File.join(ROOT, '_plugins/cms_admin_config.rb')
  PRIVILEGED_MARKERS = /service_role|sb_secret|github_pat_|ghp_/i

  def test_admin_routes_are_isolated_and_use_the_github_shell
    admin = File.read(ADMIN_PAGE)
    layout = File.read(ADMIN_LAYOUT)
    callback = File.read(CALLBACK_PAGE)
    assert_includes admin, 'layout: admin'
    assert_includes layout, 'layout: none'
    assert_includes admin, 'permalink: /admin/'
    assert_includes callback, 'permalink: /admin/auth/callback/'
    assert_includes layout, 'Sign in with GitHub'
    assert_includes callback, 'Completing GitHub sign-in'
    refute_match(/cdn\.jsdelivr\.net/i, layout)
  end

  def test_browser_configuration_and_app_are_github_only
    generator = File.read(CONFIG_GENERATOR)
    app = File.read(APP)
    assert_includes generator, 'githubAuth:'
    assert_includes generator, "ENV.fetch('GITHUB_APP_CLIENT_ID'"
    assert_includes app, 'async function bootGithub()'
    refute_match(/cms_news|signInWithPassword|createClient\(/i, generator + app)
    refute_match(PRIVILEGED_MARKERS, generator + app)
  end

  def test_rendered_admin_routes_when_artifact_supplied
    destination = ENV['PHASE13B_SITE']
    skip 'Set PHASE13B_SITE to validate generated admin routes' unless destination
    %w[admin/index.html admin/auth/callback/index.html].each do |route|
      html = File.read(File.join(destination, route))
      doc = Nokogiri::HTML(html)
      assert_equal ['noindex, nofollow'], doc.css('meta[name="robots"]').map { |node| node['content'] }
      refute_match(PRIVILEGED_MARKERS, html)
      refute_match(/cdn\.jsdelivr\.net\/npm\//i, html)
    end
  end
end
