require 'minitest/autorun'

class PhaseG9bFastPublicationTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  APP = File.read(File.join(ROOT, 'assets/js/admin/app.js'))
  FULL_WORKFLOW = File.read(File.join(ROOT, '.github/workflows/jekyll.yml'))
  FAST_WORKFLOW = File.read(File.join(ROOT, '.github/workflows/cms-publication.yml'))
  VALIDATOR = File.read(File.join(ROOT, 'scripts/validate_cms_publication.rb'))

  def test_submitted_state_replaces_draft_and_retains_the_pr_link
    assert_includes APP, 'var publicationStatusEpoch = 0;'
    assert_includes APP, 'publicationStatusEpoch += 1;'
    assert_includes APP, 'renderPublicationState'
    assert_includes APP, 'Validation in progress…'
    assert_includes APP, 'View pull request'
    assert_includes APP, 'publicationStatusEpoch) return;'
  end

  def test_validation_pending_success_and_failure_have_explicit_rendering
    %w[pending passed failed unknown].each { |state| assert_includes APP, "validation === '#{state}'" }
    assert_includes APP, 'Validation passed. Ready to publish.'
    assert_includes APP, 'Validation failed.'
    assert_includes APP, "/check-runs?filter=latest"
    assert_includes APP, "check.name === 'CMS publication validation'"
  end

  def test_fast_workflow_is_publication_only_and_main_keeps_the_full_path
    assert_includes FAST_WORKFLOW, "- 'cms-publish/**'"
    assert_includes FAST_WORKFLOW, 'cancel-in-progress: true'
    assert_includes FAST_WORKFLOW, 'scripts/validate_cms_publication.rb origin/main'
    %w[phase7_news_test.rb phase9_research_visuals_test.rb phase10_release_test.rb validate_site.rb].each { |gate| assert_includes FAST_WORKFLOW, gate }
    refute_includes FAST_WORKFLOW, 'playwright'
    refute_includes FAST_WORKFLOW, 'publication-update.sh'
    refute_includes FAST_WORKFLOW, 'deploy-pages'
    assert_includes FULL_WORKFLOW, "if: github.event_name != 'push' || !startsWith(github.ref, 'refs/heads/cms-publish/')"
    assert_includes FULL_WORKFLOW, "if: github.ref == 'refs/heads/main'"
  end

  def test_cms_and_jekyll_workflows_use_distinct_cms_publish_concurrency_namespaces
    assert_includes FAST_WORKFLOW, 'group: cms-publication-${{ github.ref }}'
    assert_includes FULL_WORKFLOW, "format('jekyll-{0}', github.ref)"
    refute_includes FULL_WORKFLOW, "format('cms-publication-{0}', github.ref)"
  end

  def test_fast_validator_locks_branch_identity_and_changed_paths
    assert_includes VALIDATOR, 'cms-publish/news/(news-[a-z0-9]+)'
    assert_includes VALIDATOR, 'CMS publication must change exactly one public News Markdown file'
    assert_includes VALIDATOR, 'unexpected CMS publication change'
    assert_includes VALIDATOR, 'path == expected_cover'
    assert_includes VALIDATOR, 'CMS publication may change only one owned cover image'
    assert_includes VALIDATOR, 'CMS publication cover image requires alt text'
    assert_includes VALIDATOR, "include?('cms/')"
  end
end
