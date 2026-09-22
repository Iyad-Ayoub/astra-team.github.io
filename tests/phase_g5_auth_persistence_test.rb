require 'minitest/autorun'

class PhaseG5AuthPersistenceTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  APP = File.join(ROOT, 'assets/js/admin/app.js')
  WORKER = File.join(ROOT, 'auth-broker/src/index.ts')

  def setup
    @app = File.read(APP)
    @worker = File.read(WORKER)
  end

  def test_login_establishes_a_restorable_broker_backed_session
    assert_includes @app, 'async function restoreGithubSession()'
    assert_includes @app, "new URL('/session/restore'"
    assert_includes @worker, 'CMS_SESSIONS.put'
    assert_includes @app, 'localStorage.setItem(githubSessionHandleKey'
  end

  def test_reload_and_direct_navigation_restore_before_sign_in_is_shown
    assert_match(/storedGithubSession\(\) \|\| await restoreGithubSession\(\)/, @app)
    assert_match(/if \(!session\) \{ showGithub\('admin-github-login'\); return; \}/, @app)
    assert_includes @app, 'await verifyGithubRepositoryAccess(session)'
  end

  def test_expiration_and_logout_clear_the_broker_session
    assert_includes @worker, 'Date.parse(session.sessionExpiresAt) <= Date.now()'
    assert_includes @app, "new URL('/session/logout'"
    assert_includes @worker, 'CMS_SESSIONS.delete'
  end

  def test_tokens_are_memory_only_and_not_browser_persistent_storage
    refute_includes @app, 'sessionStorage.setItem'
    refute_includes @app, 'localStorage.setItem(githubSessionKey'
    assert_includes @app, 'var githubSession;'
  end
end
