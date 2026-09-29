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
    assert_includes @app, "renderPublicationState('Submitting publication request…', '')"
  end

  def test_initial_lookup_hides_submission_until_a_draft_is_confirmed
    assert_includes @app, "function setPublicationLoading() { publicationStatusEpoch += 1; stopPublicationStatusPolling(); renderPublicationState('Checking publication status…', ''); }"
    assert_includes @app, 'if (id) { setPublicationLoading();'
    assert_includes @app, "if (epoch === publicationStatusEpoch) renderPublicationState('Draft', '');"
  end

  def test_submission_resolves_status_after_creating_the_pull_request
    assert_includes @app, "await loadPublicationStatus(session, record, { state: published ? 'Update submitted' : 'Submitted', pull: pr, unpublish: false });"
    assert_includes @app, 'View pull request'
    assert_includes @app, "renderPublicationState(published ? 'Update submitted' : 'Submitted', 'Validation in progress…', pr.html_url"
    refute_includes @app, "pull request #' + pr.number + ' created."
  end

  def test_stale_requests_and_propagation_cannot_restore_draft_after_a_known_pr
    assert_includes @app, 'publicationStatusEpoch += 1;'
    assert_includes @app, 'if (epoch !== publicationStatusEpoch) return;'
    assert_includes @app, 'async function loadPublicationStatus(session, record, knownLifecycle)'
    assert_includes @app, "if (knownLifecycle) { renderPublicationState(knownLifecycle.state, 'Validation in progress…', knownLifecycle.pull.html_url);"
    assert_includes @app, 'schedulePublicationStatusPolling(session, record, knownLifecycle);'
  end

  def test_validation_states_poll_neutrally_until_conclusive
    assert_includes @app, 'setTimeout(function () { loadPublicationStatus(session, record, knownLifecycle); }, 15000)'
    assert_includes @app, "if (validation === 'passed') return unpublish ? 'Validation passed. Ready to merge.' : 'Validation passed. Ready to publish.';"
    assert_includes @app, "validation === 'failed' ? 'Validation failed.' : 'Validation in progress…'"
    assert_includes @app, "if (validation === 'pending' || validation === 'unknown')"
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
