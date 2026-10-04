require 'minitest/autorun'

class PhaseG12ProjectPublicationTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  APP = File.read(File.join(ROOT, 'assets/js/admin/app.js'))
  VALIDATOR = File.read(File.join(ROOT, 'scripts/validate_cms_project_publication.rb'))
  DISPATCH = File.read(File.join(ROOT, 'scripts/validate_cms_publication.rb'))
  EDIT = File.read(File.join(ROOT, '_pages/admin/projects/edit.html'))
  NEW = File.read(File.join(ROOT, '_pages/admin/projects/new.html'))

  def test_project_publication_routes_and_target_are_controlled
    assert_includes APP, "cms-publish/projects/' + id"
    assert_includes APP, "cms-unpublish/projects/' + id"
    assert_includes APP, "return '_projects/' + record.id + '.md'"
    assert_includes APP, 'cover_media_id: record.cover_media_id || null'
    assert_includes APP, "assets/img/projects/' + record.id + '/"
    assert_includes APP, 'cover_image_alt'
    assert_includes APP, "base: 'main'"
    refute_match(/branch:\s*['"]main['"]/, APP)
  end

  def test_project_publication_ui_and_validation_contract
    %w[admin-project-publish admin-project-update admin-project-refresh admin-project-publish-now admin-project-unpublish].each { |id| assert_includes EDIT, id }
    assert_includes VALIDATOR, 'cms-publish/projects/(project-[a-z0-9]+)'
    assert_includes VALIDATOR, 'CMS project contains unsupported front matter'
    assert_includes VALIDATOR, 'CMS project body contract is invalid'
    assert_includes VALIDATOR, 'CMS project cover media ID is invalid'
    assert_includes VALIDATOR, 'CMS project cover image path is invalid'
    assert_includes VALIDATOR, 'CMS project cover asset is missing'
    assert_includes VALIDATOR, '"_projects/#{content_id}.md"'
    %w[ongoing completed].each { |value| assert_includes VALIDATOR, value }
    %w[national european international].each { |value| assert_includes VALIDATOR, value }
    %w[research-project research-infrastructure joint-lab].each { |value| assert_includes VALIDATOR, value }
  end

  def test_project_cover_media_is_exported_and_rendered_safely
    assert_includes APP, "function projectPublicMediaPath(record, media)"
    assert_includes APP, "githubMediaBlob(session, media)"
    assert_includes APP, "assets/img/projects/' + record.id + '/"
    assert_includes APP, "cover_image: media ? '/' + projectPublicMediaPath(record, media) : null"
    assert_includes VALIDATOR, 'cover image path is invalid'
    assert_includes VALIDATOR, 'cover asset is missing'
    details = File.read(File.join(ROOT, '_includes/project_details.html'))
    assert_includes details, 'page.cover_image'
    assert_includes details, 'page.cover_image_alt'
    assert_includes details, "{% include figure.html path=page.cover_image"
  end

  def test_unsaved_project_skips_publication_status_and_disables_actions
    assert_includes APP, "renderProjectPublicationState('Draft', 'Save the project draft before publication becomes available.', null, 'unsaved')"
    assert_includes APP, "unavailable = action === 'unsaved'"
    assert_includes APP, "if (route === 'project-new')"
    assert_includes NEW, 'admin-project-publication-status'
  end

  def test_project_publication_feedback_and_reconciliation
    assert_includes APP, "setProjectPublicationActionBusy(button, button && button.id === 'admin-project-update' ? 'Submitting update…' : 'Submitting…')"
    assert_includes APP, "setProjectPublicationActionBusy(button, 'Refreshing…')"
    assert_includes APP, "setProjectPublicationActionBusy(button, 'Publishing…')"
    assert_includes APP, "setProjectPublicationActionBusy(button, 'Unpublishing…')"
    assert_includes APP, "projectPublicationSubmitting = true"
    assert_includes APP, "function scheduleProjectPublicationPolling(session, record, knownLifecycle)"
    assert_includes APP, "window.setTimeout(function () { reconcileProjectPublicationStatus(session, record, knownLifecycle); }, 15000)"
    assert_includes APP, 'function reconcileProjectPublicationStatus(session, record, knownLifecycle)'
    assert_includes APP, "validation === 'pending' || validation === 'unknown'"
    assert_includes APP, "publicationDisplayState('Update submitted', validation)"
  end

  def test_project_refresh_synchronizes_the_controlled_branch_with_main
    assert_includes APP, 'await synchronizeLifecycleBranchWithMain(session, branch, pull);'
    assert_includes APP, "base + '/pulls/' + pull.number"
    assert_includes APP, "base: branch, head: 'main'"
  end

  def test_failed_project_validation_exposes_refresh_but_not_publish
    assert_includes APP, "detail.indexOf('Validation failed') === 0"
    assert_includes APP, "value === 'Submitted' || value === 'Update submitted'"
    assert_includes APP, "refreshEligible = (value === 'Update available' && action === 'refresh') || failedControlledPull"
    assert_includes APP, "refreshProjectPublication(event)"
    assert_includes APP, "publishNow.hidden = unavailable || !(detail && detail.indexOf('Validation passed') === 0"
  end

  def test_project_deployment_reconciles_later_main_success_and_requires_current_project
    assert_includes APP, "mergeSha ? base + '/actions/runs?branch=main&head_sha='"
    assert_includes APP, "base + '/actions/runs?branch=main&per_page=100&page='"
    assert_includes APP, "deploymentAncestry(session, base, mergeSha, successfulRuns[index].head_sha)"
    monitor = APP.split('async function monitorProjectDeployment', 2).fetch(1).split('async function submitProjectPublication', 2).fetch(0)
    assert_includes monitor, "await publishedProjectByContentId(session, record.id)"
    assert_includes monitor, "Published Project is no longer present on main."
    assert_includes monitor, "renderProjectPublicationState('Live', '✓ Published successfully'"
  end

  def test_saved_existing_project_reconciles_publication_without_navigation
    assert_includes APP, "if (existingSha && currentProjectId())"
    assert_includes APP, 'await reconcileProjectPublicationStatus(session, payload, wasProjectLive ? { state: \'Live\' } : null);'
    assert_includes APP, 'var wasProjectLive = projectPublicationWasLive ||'
    assert_includes APP, "pristineProjectSignature = projectEditableSignature(payload);"
    assert_includes APP, "setProjectSaveState('saved');"
    assert_includes APP, 'if (projectPublicationReconciliation) return projectPublicationReconciliation;'
    assert_includes APP, '} catch (_) {}'
  end

  def test_news_publication_branch_contract_remains_present
    assert_includes APP, "cms-publish/news/' + id"
    assert_includes APP, 'async function submitGithubPublication()'
    assert_includes APP, 'async function publishGithubPublication()'
  end

  def test_publication_validator_dispatches_project_branches
    assert_includes DISPATCH, 'cms-publish/projects/project-[a-z0-9]+'
    assert_includes DISPATCH, 'validate_cms_project_publication.rb'
  end

end
