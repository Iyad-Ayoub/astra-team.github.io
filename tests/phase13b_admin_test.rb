require 'minitest/autorun'
require 'nokogiri'

class Phase13BAdminTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  ADMIN_PAGE = File.join(ROOT, '_pages/admin/index.html')
  CALLBACK_PAGE = File.join(ROOT, '_pages/admin/auth/callback.html')
  APP = File.join(ROOT, 'assets/js/admin/app.js')
  CONFIG_GENERATOR = File.join(ROOT, '_plugins/cms_admin_config.rb')
  PRIVILEGED_MARKERS = /SUPABASE_SECRET|service_role|sb_secret|github_pat_|ghp_/i

  def test_admin_routes_are_isolated_and_have_no_signup_ui
    admin = File.read(ADMIN_PAGE)
    callback = File.read(CALLBACK_PAGE)
    assert_includes admin, 'layout: none'
    assert_includes admin, 'permalink: /admin/'
    assert_includes callback, 'permalink: /admin/auth/callback/'
    assert_includes admin, 'admin-login-form'
    assert_includes admin, 'admin-reset-form'
    assert_includes callback, 'admin-password-form'
    assert_includes admin, "{{ '/assets/js/admin/app.js' | relative_url }}"
    assert_includes callback, "{{ '/admin/' | relative_url }}"
    refute_match(/sign[ -]?up|register/i, admin)
    refute_match(/sign[ -]?up|register/i, callback)
  end

  def test_auth_shell_uses_profile_role_and_session_hooks
    app = File.read(APP)
    %w[signInWithPassword resetPasswordForEmail updateUser getSession onAuthStateChange signOut].each do |hook|
      assert_includes app, hook
    end
    assert_includes app, "from('profiles')"
    assert_includes app, "response.data.status !== 'active'"
    %w[admin editor contributor].each { |role| assert_includes app, "'#{role}'" }
    refute_includes app, 'location.hash'
    refute_match(/location\.(?:search|hash).*role|role.*location\.(?:search|hash)/i, app)
  end

  def test_completed_signed_out_user_is_shown_login
    app = File.read(APP)
    assert_match(/if \(!session\).*?show\('admin-login'\)/m, app)
  end

  def test_active_session_loads_dashboard_from_profile
    app = File.read(APP)
    assert_match(/async function handleSession\(session\).*?await loadProfile\(session\)/m, app)
    assert_match(/async function loadProfile\(session\).*?show\('admin-dashboard'\)/m, app)
  end

  def test_valid_callback_auth_events_require_password_setup
    app = File.read(APP)
    assert_includes app, "event === 'PASSWORD_RECOVERY'"
    assert_includes app, "event === 'SIGNED_IN'"
    assert_includes app, 'passwordSetupRequired = true;'
    assert_match(/if \(passwordSetupRequired\) \{\s+show\('admin-password-setup'\)/m, app)
    assert_match(/updateUser\(\{ password: password \}\).*?passwordSetupRequired = false/m, app)
  end

  def test_expired_callback_and_normal_login_paths_remain_distinct
    app = File.read(APP)
    assert_match(/mode === 'callback'.*?deny\('This invitation or password-reset link is invalid/m, app)
    assert_includes app, 'signInWithPassword'
    assert_includes app, 'resetPasswordForEmail'
  end

  def test_only_browser_safe_configuration_is_emitted
    generator = File.read(CONFIG_GENERATOR)
    assert_includes generator, "ENV.fetch('SUPABASE_URL'"
    assert_includes generator, "ENV.fetch('SUPABASE_PUBLISHABLE_KEY'"
    refute_match(PRIVILEGED_MARKERS, generator.gsub('privileged credential', ''))
    assert_includes generator, "'assets/js/admin'"
  end

  def test_rendered_admin_routes_when_artifact_supplied
    destination = ENV['PHASE13B_SITE']
    skip 'Set PHASE13B_SITE to validate generated admin routes' unless destination
    %w[admin/index.html admin/auth/callback/index.html].each do |route|
      html = File.read(File.join(destination, route))
      doc = Nokogiri::HTML(html)
      assert_equal ['noindex, nofollow'], doc.css('meta[name="robots"]').map { |node| node['content'] }
      assert_empty doc.css('header, footer')
      refute_match(PRIVILEGED_MARKERS, html)
    end
    config = File.read(File.join(destination, 'assets/js/admin/config.js'))
    refute_match(PRIVILEGED_MARKERS, config)
  end
end
