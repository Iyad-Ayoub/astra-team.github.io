require 'minitest/autorun'

class PhaseG9hPublicationUxTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  APP = File.read(File.join(ROOT, 'assets/js/admin/app.js'))
  EDIT = File.read(File.join(ROOT, '_pages/admin/news/edit.html'))

  def test_refresh_reuses_existing_publication_branch_and_pull_request
    assert_includes APP, 'async function refreshGithubPublication()'
    assert_includes APP, 'findOpenPublicationPull(session, id)'
    assert_includes APP, 'await createPublicationCommit(session, publicationBranch(id), record, media, published)'
    assert_includes APP, 'return commit.sha;'
    assert_includes APP, 'expectedPublicationSha = pull.head && pull.head.sha'
    assert_includes APP, 'expectedSha: expectedPublicationSha'
    assert_includes APP, 'Waiting for GitHub to register the refreshed publication…'
    assert_includes APP, "base: 'main'"
    refute_includes APP.split('async function refreshGithubPublication', 2).last.split('async function publishGithubPublication', 2).first, "method: 'POST'"
  end

  def test_publish_now_merges_only_a_validated_expected_pull
    assert_includes EDIT, 'admin-news-publish-now'
    assert_includes APP, 'async function publishGithubPublication()'
    assert_includes APP, "pull.base.ref !== 'main'"
    assert_includes APP, "pull.head.ref !== publicationBranch(id)"
    assert_includes APP, "publicationValidationState(session, freshPull) !== 'passed'"
    assert_includes APP, "freshPull.mergeable !== true"
    assert_includes APP, "freshPull = await githubResponse(base + '/pulls/' + pull.number, session)"
    assert_includes APP, "freshPull.mergeable === null"
    assert_includes APP, "publicationValidationState(session, freshPull)"
    assert_includes APP, "sha: freshPull.head.sha"
    assert_includes APP, "'/merge'"
    assert_includes APP, "merge_method: 'squash'"
    refute_match(/branch:\s*['"]main['"]/, APP)
  end

  def test_update_available_exposes_only_the_matching_action
    assert_includes APP, "renderPublicationState('Update available', 'Draft changed after submission. The draft or media changed after submission. Refresh publication first.', pull.html_url, publicNewsUrl(published), 'refresh')"
    assert_includes APP, "renderPublicationState('Update available', '', null, publicNewsUrl(published), 'update')"
    assert_includes APP, "value === 'Update available' && action === 'update'"
    assert_includes APP, "value === 'Update available' && action === 'refresh'"
  end

  def test_validation_is_bound_to_the_current_publication_head
    assert_includes APP, "pull.head.sha !== knownLifecycle.expectedSha"
    assert_includes APP, "publicationValidationState(session, pull)"
    assert_includes APP, "publicationDisplayState(internalState, validation)"
    assert_includes APP, "'Ready to publish'"
    assert_includes APP, "'Update ready to publish'"
    assert_includes APP, "['Submitted', 'Update submitted', 'Ready to publish', 'Update ready to publish'].indexOf(value)"
    assert_includes APP, "detail.className = 'astra-admin-message-success'"
    assert_includes APP, "detail.className = 'astra-admin-message-status'"
  end

  def test_stale_source_and_merge_failures_never_report_published
    assert_includes APP, 'Publication source changed. Refresh publication first.'
    assert_includes APP, 'GitHub did not merge the publication pull request.'
    assert_includes APP, "renderPublicationState('Published'"
    assert_includes APP, "publicationMessage('✓ Published successfully', 'success')"
    assert_includes APP, "if (publicationSubmitting) return;"
  end

  def test_existing_lifecycle_states_and_auth_remain_in_use
    %w[Draft Submitted Published Update\ available Update\ submitted Unpublish\ submitted].each { |state| assert_includes APP, "'#{state}'" }
    assert_includes APP, 'verifyGithubRepositoryAccess(session)'
    assert_includes APP, 'publicationBranchMatchesDraft'
    assert_includes APP, 'addEventListener(\'click\', refreshGithubPublication)'
    assert_includes APP, 'addEventListener(\'click\', publishGithubPublication)'
  end
end
