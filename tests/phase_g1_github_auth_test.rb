require 'minitest/autorun'

class PhaseG1GitHubAuthTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  ADMIN = File.join(ROOT, '_pages/admin/index.html')
  ADMIN_LAYOUT = File.join(ROOT, '_layouts/admin.html')
  CALLBACK = File.join(ROOT, '_pages/admin/auth/callback.html')
  APP = File.join(ROOT, 'assets/js/admin/app.js')
  CONFIG = File.join(ROOT, '_plugins/cms_admin_config.rb')
  ENVIRONMENT = File.join(ROOT, '.env.example')
  ROUTES = %w[news/index.html news/new.html news/edit.html media.html].freeze
  SECRET_MARKERS = /GITHUB_APP_CLIENT_SECRET|GITHUB_PRIVATE_KEY|github_pat_|ghp_|ghs_|ghu_|ghr_/i

  def test_persistent_admin_routes_are_isolated_and_noindex
    ROUTES.each do |route|
      page = File.read(File.join(ROOT, '_pages/admin', route))
      assert_includes page, 'layout: admin'
    end
    layout = File.read(ADMIN_LAYOUT)
    assert_includes layout, 'layout: none'
    assert_includes layout, 'noindex, nofollow'
    assert_includes layout, "{{ '/assets/css/admin.css' | relative_url }}"
    assert_includes layout, "{{ '/assets/js/admin/app.js' | relative_url }}"
    %w[/admin/ /admin/news/ /admin/media/].each { |route| assert_includes layout, "{{ '#{route}' | relative_url }}" }
    assert_includes File.read(CALLBACK), "{{ '/admin/' | relative_url }}"
  end

  def test_github_login_uses_broker_transaction_and_opaque_ticket
    admin = File.read(ADMIN_LAYOUT)
    callback = File.read(CALLBACK)
    app = File.read(APP)
    assert_includes admin, 'Sign in with GitHub'
    assert_includes callback, 'Completing GitHub sign-in'
    %w[redirect_uri return_to /authorize /session/exchange].each do |hook|
      assert_includes app, hook
    end
    assert_includes app, "params.get('ticket')"
    assert_includes app, "window.history.replaceState({}, document.title, window.location.pathname)"
    refute_includes app, "params.get('code')"
    %w[getRandomValues randomUUID subtle.digest code_challenge code_verifier githubTransactionKey Math.random].each do |forbidden|
      refute_includes app, forbidden
    end
  end

  def test_repository_identity_is_fixed_and_write_access_is_required
    config = File.read(CONFIG)
    app = File.read(APP)
    environment = File.read(ENVIRONMENT)
    assert_includes config, "github_repo_owner == 'Iyad-Ayoub'"
    assert_includes config, "github_repo_name == 'astra-team.github.io'"
    assert_includes app, "github.repoOwner !== 'Iyad-Ayoub'"
    assert_includes app, "github.repoName !== 'astra-team.github.io'"
    assert_includes app, "repository.permissions.push !== true"
    %w[GITHUB_APP_CLIENT_ID= GITHUB_AUTH_BROKER_URL= GITHUB_REPO_OWNER=Iyad-Ayoub GITHUB_REPO_NAME=astra-team.github.io].each do |setting|
      assert_includes environment, setting
    end
  end

  def test_browser_contract_has_no_privileged_github_credential
    [ADMIN, CALLBACK, APP, CONFIG, ENVIRONMENT].each do |path|
      contents = File.read(path)
      refute_match SECRET_MARKERS, contents, path
    end
    assert_includes File.read(APP), "new URL('/session/restore'"
    assert_includes File.read(APP), "new URL('/session/logout'"
    refute_includes File.read(APP), 'sessionStorage.setItem'
    refute_includes File.read(APP), 'localStorage.setItem(githubSessionKey'
  end

  def test_github_auth_is_the_active_path_during_the_pivot
    app = File.read(APP)
    assert_match(/if \(githubSettings\(\)\) \{\s+await bootGithub\(\);\s+return;\s+\}\s+bindEvents\(\);\s+await bootSupabase\(\);/m, app)
  end
end
