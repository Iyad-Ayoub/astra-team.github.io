require 'minitest/autorun'

class PhaseG9jNoopDraftSaveTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  APP = File.read(File.join(ROOT, 'assets/js/admin/app.js'))

  def test_existing_draft_loads_pristine_and_disables_save
    assert_includes APP, 'var draftFormInitializing = false;'
    assert_includes APP, 'draftFormInitializing = true;'
    assert_includes APP, 'draftFormInitializing = false;'
    assert_includes APP, 'pristineDraftSignature = record ? editableDraftSignature(record) : null;'
    assert_includes APP, "setDraftSaveState(record ? 'pristine' : '')"
    assert_includes APP, "else if (state === 'pristine') githubDraftMessage('');"
    assert_includes APP, "state === 'saving' || state === 'pristine' || state === 'saved'"
  end

  def test_dirty_state_is_based_on_the_canonical_serialized_draft
    assert_includes APP, 'function editableDraftSignature(record)'
    assert_includes APP, 'return serializeGithubDraft({'
    assert_includes APP, 'updateDraftDirtyState();'
    assert_includes APP, 'pristineDraftSignature === editableDraftSignature(currentEditableDraft())'
    assert_includes APP, '!draftFormInitializing'
  end

  def test_noop_save_returns_before_github_write_and_real_save_resets_baseline
    assert_includes APP, "if (existingSha && pristineDraftSignature && editableDraftSignature(payload) === pristineDraftSignature) { setDraftSaveState('pristine'); return; }"
    assert_includes APP, 'pristineDraftSignature = editableDraftSignature(payload);'
    assert_includes APP, 'if (existingSha && currentDraftId()) await loadPublicationStatus(session, payload);'
  end

  def test_new_drafts_are_not_treated_as_pristine_existing_drafts
    assert_includes APP, 'var existing = Boolean(editingNews && editingNews.githubSha);'
    assert_includes APP, "else setDraftSaveState('unsaved');"
    assert_includes APP, 'var existingSha = editingNews && editingNews.githubSha;'
  end
end
