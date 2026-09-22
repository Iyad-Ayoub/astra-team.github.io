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

  def test_authorize_validates_fixed_client_callback_state_and_pkce
    assert_includes @worker, "url.searchParams.get('client_id') !== env.GITHUB_APP_CLIENT_ID"
    %w[callbackAllowed state code_challenge code_challenge_method S256].each { |term| assert_includes @worker, term }
    assert_includes @worker, 'https://github.com/login/oauth/authorize'
    assert_includes @worker, "redirect_uri: githubCallback(request)"
  end

  def test_exchange_fails_closed_and_uses_server_side_secret
    assert_includes @worker, "await fetch('https://github.com/login/oauth/access_token'"
    assert_includes @worker, 'client_secret: env.GITHUB_APP_CLIENT_SECRET'
    assert_includes @worker, "error: 'invalid_or_expired_session'"
    assert_includes @worker, "error: 'token_exchange_failed'"
    assert_includes @worker, 'clearTransactionCookie(request)'
    assert_includes @worker, 'challengeFor(body.code_verifier)'
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
