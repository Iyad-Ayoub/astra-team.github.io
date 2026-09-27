require 'minitest/autorun'

class PhaseG3GitHubDraftsTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  APP = File.join(ROOT, 'assets/js/admin/app.js')
  CSS = File.join(ROOT, 'assets/css/admin.css')
  NEWS = File.join(ROOT, '_pages/admin/news/index.html')
  NEW = File.join(ROOT, '_pages/admin/news/new.html')
  EDIT = File.join(ROOT, '_pages/admin/news/edit.html')

  def setup
    @app = File.read(APP)
  end

  def test_avatar_is_constrained_to_dashboard_identity_size
    css = File.read(CSS)
    assert_match(/\.astra-admin-avatar .*height: 64px;.*object-fit: cover;.*width: 64px;/, css)
    assert_includes css, 'border-radius: 50%'
  end

  def test_github_drafts_use_only_fixed_branch_and_path
    assert_includes @app, "var githubDraftBranch = 'cms-drafts';"
    assert_includes @app, "var githubDraftRoot = 'cms/drafts/news';"
    assert_includes @app, "return githubDraftRoot + '/' + id + '.md';"
    assert_includes @app, "githubOperation('ensure_draft_branch'"
    refute_includes @app.split('function draftPath', 2).last.split('function utf8Base64', 2).first, '_news/'
  end

  def test_contents_api_creates_updates_with_sha_and_never_targets_main
    assert_includes @app, "githubOperation('draft_save'"
    assert_includes @app, 'if (existingSha) body.sha = existingSha;'
    assert_includes @app, "'cms: ' + (existingSha ? 'update' : 'create') + ' news draft ' + id"
    assert_includes @app, "branch: githubDraftBranch"
    assert_includes @app, "error.status === 409"
    assert_includes @app, 'Your GitHub session has expired. Sign in again before saving this draft.'
    refute_match(/branch:\s*['\"]main['\"]/, @app)
  end

  def test_draft_serialization_and_routes_are_constrained
    %w[content_id title type summary content_date status].each { |field| assert_includes @app, field }
    assert_includes @app, "status: 'draft'"
    assert_includes @app, 'safeNewsText(payload.title)'
    assert_includes @app, "new URLSearchParams(window.location.search).get('id')"
    assert_includes @app, '/^news-[a-z0-9]+$/'
    [NEWS, NEW, EDIT].each { |path| assert_includes File.read(path), 'layout: admin' }
    [NEW, EDIT].each { |path| assert_includes File.read(path), '{% include admin/news_form.html %}' }
  end

  def test_github_draft_flow_has_no_legacy_database_calls
    flow = @app.split('async function ensureGithubDraftBranch', 2).last.split('async function bootGithub', 2).first
    refute_includes flow, "from('cms_news')"
    refute_includes flow, "from('profiles')"
    assert_includes flow, 'verifyGithubRepositoryAccess(session)'
  end
end
