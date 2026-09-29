require 'minitest/autorun'

class PhaseG9iFastLivePublishingTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  WORKFLOW = File.read(File.join(ROOT, '.github/workflows/jekyll.yml'))
  APP = File.read(File.join(ROOT, 'assets/js/admin/app.js'))

  def test_fast_classification_is_associated_pr_and_fail_closed
    assert_includes WORKFLOW, 'classify-cms-merge:'
    assert_includes WORKFLOW, 'actions/github-script@ed597411d8f924073f98dfc5c65a23a2325f34cd # v8'
    refute_includes WORKFLOW, 'actions/github-script@v7'
    assert_includes WORKFLOW, 'listPullRequestsAssociatedWithCommit'
    assert_includes WORKFLOW, 'compareCommits'
    assert_includes WORKFLOW, 'context.payload.before'
    assert_includes WORKFLOW, "!actualFiles.length"
    assert_includes WORKFLOW, "actualFiles.some(name => !name.startsWith('_news/')"
    assert_includes WORKFLOW, 'core.setOutput(\'fast\', \'false\')'
    assert_includes WORKFLOW, "pull.base.ref !== 'main'"
    assert_includes WORKFLOW, "!/^cms-publish\\/news\\/news-[a-z0-9]+$/.test(pull.head.ref)"
    assert_includes WORKFLOW, "name.startsWith('_news/')"
    assert_includes WORKFLOW, "name.startsWith('assets/img/news/')"
    assert_includes WORKFLOW, "core.setOutput('fast', fast ? 'true' : 'false')"
    assert_includes WORKFLOW, 'using full pipeline'
  end

  def test_fast_path_skips_expensive_steps_but_keeps_production_build_and_pages
    %w['Validate source and regression tests' 'Build and test versioned root and project-subpath baselines' 'Install pinned browser test dependency' 'Check containment, metadata and analytics in browser'].each do |name|
      assert_includes WORKFLOW, "if: needs.classify-cms-merge.outputs.fast != 'true'"
    end
    assert_includes WORKFLOW, 'Validate fast CMS publication source'
    assert_includes WORKFLOW, 'Validate focused CMS publication invariants'
    assert_includes WORKFLOW, 'bundle exec ruby tests/phase7_news_test.rb'
    assert_includes WORKFLOW, 'bundle exec ruby tests/phase9_research_visuals_test.rb'
    assert_includes WORKFLOW, 'bundle exec ruby tests/phase10_release_test.rb'
    assert_includes WORKFLOW, 'bundle exec jekyll build --baseurl "$PAGES_BASE_PATH"'
    assert_includes WORKFLOW, 'actions/upload-pages-artifact@v3'
    assert_includes WORKFLOW, 'actions/deploy-pages@v4'
    assert_includes WORKFLOW, "if: github.ref == 'refs/heads/main'"
    assert_includes WORKFLOW, 'publication-update.sh'
  end

  def test_deployment_status_uses_exact_merge_sha_and_never_claims_live_early
    assert_includes APP, 'merge.sha'
    assert_includes APP, 'actions/runs?branch=main&head_sha='
    assert_includes APP, "candidate.name === 'Deploy astra-team with jekyll'"
    assert_includes APP, 'Waiting for website deployment…'
    assert_includes APP, "renderPublicationState('Merged to main', 'Waiting for website deployment…'"
    refute_includes APP, "renderPublicationState('Published', 'Waiting for website deployment…'"
    assert_includes APP, 'Website deployment has not started yet.'
    assert_includes APP, 'attempt >= 20'
    assert_includes APP, 'Deploying website…'
    assert_includes APP, "deployment.state === 'deploying' ? 'Deploying website' : 'Merged to main'"
    assert_includes APP, "renderPublicationState('Live', '✓ Published successfully'"
    assert_includes APP, "renderPublicationState('Published to repository', 'Website deployment failed.'"
    assert_includes APP, "method: 'GET'"
    assert_includes APP, "'X-GitHub-Api-Version': '2022-11-28'"
    fallback = APP.split("var response = await fetch('https://api.github.com' + path", 2).last.split('var publicData', 2).first
    refute_includes fallback, 'Authorization:'
    refute_includes APP, "publicationMessage('✓ Published successfully', 'success')"
  end

  def test_pending_deployment_does_not_enable_unpublish
    assert_includes APP, "unpublish.hidden = value !== 'Published' && value !== 'Live';"
    assert_includes APP, "unpublish.disabled = value !== 'Published' && value !== 'Live';"
    assert_includes APP, "detail.className = 'astra-admin-message-success'"
    assert_includes APP, "detail.className = 'astra-admin-message-status'"
  end

  def test_no_direct_main_content_write_is_added
    refute_match(/contents\/.*branch:s*['"]main['"]/, APP)
  end

  def test_lifecycle_branch_reuse_is_controlled_and_safe
    assert_includes APP, "var match = /^(cms-publish|cms-unpublish)\\/news\\/(news-[a-z0-9]+)$/.exec(branch);"
    assert_includes APP, "publicationBranch(match[2])"
    assert_includes APP, "unpublishBranch(match[2])"
    assert_includes APP, "pulls?state=open&head="
    assert_includes APP, "pull.merged_at && pull.base && pull.base.ref === 'main'"
    assert_includes APP, "body: { sha: main.object.sha, force: true }"
    assert_includes APP, "An open publication pull request still uses this branch."
    assert_includes APP, "no verified merged pull request"
  end

  def test_existing_save_refreshes_lifecycle_without_navigation
    assert_includes APP, "if (existingSha && currentDraftId()) await loadPublicationStatus(session, payload);"
  end
end
