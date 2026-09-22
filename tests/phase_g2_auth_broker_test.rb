require 'minitest/autorun'

class PhaseG2AuthBrokerTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  WORKER = File.join(ROOT, 'auth-broker/src/index.ts')
  WRANGLER = File.join(ROOT, 'auth-broker/wrangler.toml')
  README = File.join(ROOT, 'auth-broker/README.md')
  SECRET_VALUE_MARKERS = /(?:GITHUB_APP_CLIENT_SECRET\s*=\s*[^\s#]|ghp_|github_pat_|-----BEGIN.*PRIVATE KEY)/i

  def setup
    @worker = File.read(WORKER)
  end

  def test_callback_and_cors_allowlists_are_exact
    %w[
      http://127.0.0.1:4000/admin/auth/callback/
      http://localhost:4000/admin/auth/callback/
      https://iyad-ayoub.github.io/astra-team.github.io/admin/auth/callback/
      http://127.0.0.1:4000
      http://localhost:4000
      https://iyad-ayoub.github.io
    ].each { |entry| assert_includes @worker, entry }
    refute_includes @worker, "headers.set('Access-Control-Allow-Origin', '*')"
    assert_includes @worker, 'ORIGINS.has(origin)'
    assert_includes @worker, "return json({ error: 'origin_not_allowed' }, 403"
    assert_includes @worker, 'SameSite=None; Secure'
  end

  def test_worker_generates_state_and_pkce_after_validating_callback_and_return_path
    %w[callbackAllowed returnToAllowed randomValue pkceVerifier state code_challenge code_challenge_method S256].each { |term| assert_includes @worker, term }
    assert_includes @worker, "url.searchParams.get('return_to')"
    assert_includes @worker, 'https://github.com/login/oauth/authorize'
    assert_includes @worker, "redirect_uri: githubCallback(request)"
  end

  def test_worker_exchanges_code_before_issuing_ticket_and_exchange_fails_closed
    assert_includes @worker, "await fetch('https://github.com/login/oauth/access_token'"
    assert_includes @worker, 'client_secret: env.GITHUB_APP_CLIENT_SECRET'
    assert_includes @worker, "error: 'invalid_or_expired_session'"
    assert_includes @worker, "safeErrorRedirect(transaction.callback, transaction.state, 'token_exchange_failed', request)"
    assert_includes @worker, 'clearTransactionCookie(request)'
    assert_includes @worker, 'code_verifier: transaction.pkceVerifier'
    assert_includes @worker, 'accessToken: result.access_token'
    refute_includes @worker, 'body.code_verifier'
    assert_includes @worker, 'const TICKET_TTL_MS = 60 * 1000;'
    assert_includes @worker, 'nonce: randomValue()'
    assert_includes @worker, 'equal(ticket.callback, body.redirect_uri || \'\')'
    assert_includes @worker, "'Set-Cookie': clearTransactionCookie(request)"
  end

  def test_final_ticket_exchange_does_not_depend_on_oauth_transaction_cookie
    exchange = @worker.split('async function exchange', 2).last.split('export default', 2).first
    refute_includes exchange, 'cookie(request, COOKIE_NAME)'
    refute_includes exchange, 'unseal<Transaction>'
    assert_includes exchange, 'unseal<Ticket>(body.ticket'
    assert_includes exchange, 'ticket.expiresAt < Date.now()'
  end

  def test_broker_restores_and_clears_an_encrypted_http_only_browser_session
    assert_includes @worker, 'CMS_SESSIONS'
    assert_includes @worker, 'async function restore'
    assert_includes @worker, "url.pathname === '/session/restore'"
    assert_includes @worker, "url.pathname === '/session/logout'"
    assert_includes @worker, 'CMS_SESSIONS.get'
    assert_includes @worker, 'CMS_SESSIONS.delete'
  end

  def test_worker_contains_no_tracked_secret_value
    [WORKER, WRANGLER, README].each do |path|
      refute_match SECRET_VALUE_MARKERS, File.read(path), path
    end
    assert_includes File.read(WRANGLER), 'GITHUB_APP_CLIENT_ID = "Iv23lioxfjVy65Y7Kb6R"'
    assert_includes File.read(README), 'wrangler secret put GITHUB_APP_CLIENT_SECRET'
  end

  def test_no_arbitrary_repository_or_cms_storage_is_present
    refute_match(/repo_owner|repo_name|drafts|cms_news|supabase/i, @worker)
    refute_match(/console\.(?:log|error|warn)/, @worker)
  end
end
