require 'minitest/autorun'

class PhaseG9CmsStabilizationTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  APP = File.join(ROOT, 'assets/js/admin/app.js')
  WORKFLOW = File.join(ROOT, '.github/workflows/jekyll.yml')

  def setup
    @app = File.read(APP)
    @workflow = File.read(WORKFLOW)
  end

  def test_submission_has_a_busy_state_and_prevents_duplicates
    assert_includes @app, 'var publicationSubmitting = false;'
    assert_includes @app, 'if (publicationSubmitting) return;'
    assert_includes @app, "Submitting publication request…"
    assert_includes @app, 'setPublicationBusy(true)'
    assert_includes @app, 'finally { setPublicationBusy(false); }'
  end

  def test_submission_resolves_status_after_creating_the_pull_request
    assert_includes @app, 'await loadPublicationStatus(session, record);'
    assert_includes @app, 'View pull request'
    assert_operator @app.index("pull request #' + pr.number + ' created."), :<, @app.index('await loadPublicationStatus(session, record);', @app.index("pull request #' + pr.number + ' created."))
  end

  def test_expired_session_preserves_the_target_route_before_reauthentication
    assert_includes @app, 'preserveNewsFormForReauthentication'
    assert_includes @app, "sessionStorage.setItem('astra-cms-reauth-draft'"
    assert_includes @app, 'await beginGithubLogin();'
  end

  def test_publication_uses_one_atomic_commit_after_branch_setup
    assert_includes @app, 'async function createPublicationCommit'
    %w[/git/blobs /git/trees /git/commits /git/refs/heads/].each { |path| assert_includes @app, path }
    assert_includes @app, 'force: false'
    refute_includes @app, "'/contents/' + publicNewsPath(record, published)"
  end

  def test_publication_branch_runs_are_cancelled_but_main_deployment_is_not
    assert_includes @workflow, "startsWith(github.ref, 'refs/heads/cms-publish/')"
    assert_includes @workflow, 'cancel-in-progress:'
    assert_includes @workflow, "if: github.ref == 'refs/heads/main'"
  end

  def test_no_browser_merge_control_bypasses_ci
    refute_match(/method:\s*'PUT'.*\/merge/m, @app)
    refute_includes @app, 'merge: true'
  end
end
