require 'minitest/autorun'

class PhaseG9eDurableSessionTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  APP = File.read(File.join(ROOT, 'assets/js/admin/app.js'))
  WORKER = File.read(File.join(ROOT, 'auth-broker/src/index.ts'))
  README = File.read(File.join(ROOT, 'auth-broker/README.md'))

  def test_browser_receives_only_safe_session_metadata
    refute_includes APP, 'api.github.com'
    refute_includes APP, 'Authorization'
    refute_match(/(?:access_token|refresh_token|accessToken|refreshToken)/, APP)
    assert_includes APP, "localStorage.setItem(githubSessionHandleKey"
    assert_includes APP, "new URL('/v2/github'"
    assert_includes WORKER, 'function publicSession(handle: string, session: SessionRecord)'
    assert_includes WORKER, 'publicSession(result.handle, result.session)'
  end

  def test_kv_records_are_sealed_and_legacy_plaintext_fails_closed
    assert_includes WORKER, 'await seal(session, env.GITHUB_APP_CLIENT_SECRET)'
    assert_includes WORKER, 'unseal<SessionRecord>'
    assert_includes WORKER, 'if (!validHandle(handle)) return null;'
    assert_includes WORKER, 'if (!session || typeof session.accessToken !=='
  end

  def test_v2_sessions_are_access_token_only_and_expire_closed
    assert_includes WORKER, 'accessExpiresAt <= Date.now()'
    assert_includes WORKER, 'async function usableSession(handle: string, env: Env)'
    refute_includes WORKER, 'refreshLocks'
    refute_includes WORKER, 'refreshSession'
    refute_includes WORKER, 'refreshToken:'
    refute_includes WORKER, 'grant_type: \'refresh_token\''
    assert_includes WORKER, 'const session = await loadSession(handle, env);'
  end

  def test_controlled_transport_has_no_generic_repository_proxy
    assert_includes WORKER, "url.pathname === '/v2/github'"
    assert_includes WORKER, "operation === 'publication_prepare'"
    refute_includes WORKER, 'function githubProxy'
    refute_includes APP, '/git/blobs'
    refute_includes APP, '/git/trees'
    refute_includes APP, '/git/commits'
    assert_includes WORKER, 'Iyad-Ayoub/astra-team.github.io'
    assert_includes WORKER, "throw new Error('operation_not_allowed')"
    refute_includes WORKER, 'owner?: string'
  end

  def test_auth_failure_clears_ui_and_cross_tab_restore_preserves_editor
    assert_includes APP, "denyGithub('Your GitHub session expired or was revoked. Sign in again to continue.')"
    assert_includes APP, "window.addEventListener('storage'"
    assert_includes APP, 'restoreFromOtherTab'
    assert_includes APP, 'preserveNewsFormForReauthentication()'
    assert_includes APP, "admin-github-relogin-button"
    assert_includes APP, "sessionStorage.setItem('astra-cms-reauth-draft'"
    assert_includes APP, 'draftSha'
    assert_includes APP, 'await beginGithubLogin();'
  end

  def test_logout_and_publish_merge_scope_remain_safe
    assert_includes WORKER, 'CMS_SESSIONS.delete'
    assert_includes APP, "new URL('/v2/session/logout'"
    refute_includes APP, 'merge: true'
    refute_match(/\/merge/, APP)
  end

  def test_documentation_matches_server_side_credential_model
    assert_includes README, 'browser retains only an opaque'
    assert_includes README, 'refresh'
    assert_includes README, 'another browser tab'
    assert_includes README, 'Legacy plaintext'
  end

  def test_branch_conflicts_and_direct_main_writes_are_rejected
    assert_includes WORKER, "branch: 'cms-drafts'"
    assert_includes WORKER, "base: 'main'"
    assert_includes WORKER, "refs/heads/cms-drafts"
    assert_includes WORKER, "branch: 'cms-drafts'"
  end

  def test_expired_session_fails_closed_and_is_deleted
    assert_includes WORKER, 'catch (_) {'
    assert_includes WORKER, 'await env.CMS_SESSIONS.delete(await sessionKey(handle))'
    assert_includes WORKER, 'const session = await loadSession(handle, env);'
  end

  def test_recovery_is_revision_aware_and_cross_tab_is_epoch_guarded
    assert_includes APP, 'draftSha'
    assert_includes APP, 'window.confirm'
    assert_includes APP, 'sessionRestoreEpoch'
    assert_includes APP, 'sessionRestoreInFlight'
    assert_includes APP, 'epoch !== sessionRestoreEpoch'
    assert_includes APP, 'restoreGithubSession(expectedHandle, false)'
    assert_includes APP, 'storeNormalizedGithubSession(session)'
    assert_includes APP, 'function normalizedGithubSession(session)'
  end

  def test_stale_cross_tab_restore_cannot_commit_state
    assert_match(/restoreGithubSession\(expectedHandle, false\).*?epoch !== sessionRestoreEpoch.*?storeNormalizedGithubSession\(session\)/m, APP)
    refute_match(/restoreGithubSession\(expectedHandle\).*?storeGithubSession/m, APP)
  end

  def test_compatibility_contract_is_explicitly_versioned
    assert_includes WORKER, "url.pathname === '/session/exchange'"
    assert_includes WORKER, "url.pathname === '/v2/session/exchange'"
    assert_includes WORKER, "url.pathname === '/v2/github'"
    assert_includes README, 'temporary legacy compatibility endpoints'
    refute_includes APP, "new URL('/github'"
    refute_includes APP, "new URL('/session/exchange'"
    assert_includes WORKER, 'TEMPORARY: legacy token responses'
    assert_includes README, 'TEMPORARY — remove immediately after the new frontend is deployed and manually verified.'
  end
end
