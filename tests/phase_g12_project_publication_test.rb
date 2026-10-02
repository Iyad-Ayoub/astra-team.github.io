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
    assert_includes APP, "base: 'main'"
    refute_match(/branch:\s*['"]main['"]/, APP)
  end

  def test_project_publication_ui_and_validation_contract
    %w[admin-project-publish admin-project-update admin-project-refresh admin-project-publish-now admin-project-unpublish].each { |id| assert_includes EDIT, id }
    assert_includes VALIDATOR, 'cms-publish/projects/(project-[a-z0-9]+)'
    assert_includes VALIDATOR, 'CMS project contains unsupported front matter'
    assert_includes VALIDATOR, 'CMS project body contract is invalid'
    assert_includes VALIDATOR, 'CMS project cover media ID is invalid'
    assert_includes VALIDATOR, '"_projects/#{content_id}.md"'
    %w[ongoing completed].each { |value| assert_includes VALIDATOR, value }
    %w[national european international].each { |value| assert_includes VALIDATOR, value }
    %w[research-project research-infrastructure joint-lab].each { |value| assert_includes VALIDATOR, value }
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
    assert_includes APP, "window.setTimeout(function () { loadProjectPublicationStatus(session, record, knownLifecycle); }, 15000)"
    assert_includes APP, "validation === 'pending' || validation === 'unknown'"
    assert_includes APP, "publicationDisplayState('Update submitted', validation)"
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
