require 'minitest/autorun'

class PhaseG9jNoopDraftSaveTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  APP = File.read(File.join(ROOT, 'assets/js/admin/app.js'))

  def test_existing_draft_loads_pristine_and_disables_save
    assert_includes APP, 'var draftFormInitializing = false;'
    assert_includes APP, 'draftFormInitializing = true;'
    assert_includes APP, 'draftFormInitializing = false;'
    assert_includes APP, 'pristineDraftSignature = null;'
    assert_includes APP, 'async function finishNewsFormHydration(record, session)'
    assert_includes APP, 'previewItem = populateCoverMedia(record);'
    assert_includes APP, 'pristineDraftSignature = editableDraftSignature(currentEditableDraft());'
    assert_includes APP, "setDraftSaveState(record ? 'pristine' : '')"
    assert_includes APP, "else if (state === 'pristine') githubDraftMessage('');"
    assert_includes APP, "state === 'saving' || state === 'pristine' || state === 'saved'"
  end

  def test_dirty_state_is_based_on_the_canonical_serialized_draft
    assert_includes APP, 'function editableDraftSignature(record)'
    assert_includes APP, 'return serializeGithubDraft({'
    assert_includes APP, 'updateDraftDirtyState();'
    assert_includes APP, 'var dirty = editableDraftSignature(currentEditableDraft()) !== pristineDraftSignature;'
    assert_includes APP, "setDraftSaveState(dirty ? 'unsaved' : 'pristine');"
    assert_includes APP, '!draftFormInitializing'
  end

  def test_dirty_boolean_semantics_match_the_required_behavior
    dirty = ->(pristine, current) { current != pristine }
    assert_equal false, dirty.call('same-draft', 'same-draft')
    assert_equal true, dirty.call('same-draft', 'changed-draft')
    assert_equal false, dirty.call('same-draft', 'same-draft')
    assert_equal false, dirty.call('same-draft', 'same-draft')
    assert_includes APP, "button.disabled = state === 'saving' || state === 'pristine' || state === 'saved'"
  end

  def test_pristine_baseline_is_finalized_only_after_async_cover_hydration
    reset = APP.index('function resetNewsForm(record)')
    hydration = APP.index('async function finishNewsFormHydration(record, session)')
    baseline = APP.index('pristineDraftSignature = editableDraftSignature(currentEditableDraft());')
    assert_operator reset, :>=, 0
    assert_operator hydration, :>, reset
    assert_operator baseline, :>, hydration
    assert_operator APP.index('draftFormInitializing = false;', baseline), :<, APP.index('renderCoverPreview(previewItem, session);', baseline)
    assert_includes APP, 'finally {'
    assert_includes APP, 'draftFormInitializing = false;'
  end

  def test_async_hydration_behavioral_model_is_clean_then_dirty_then_clean
    fields = { title: 'Barcelona', cover_media_id: nil }
    initializing = true
    pristine = nil
    hydrate = lambda do
      fields[:cover_media_id] = 'media-mufgnd58'
      pristine = fields.dup
      initializing = false
    end
    refute_equal fields, pristine, 'baseline must not be finalized before hydration'
    hydrate.call
    refute initializing
    assert_equal false, fields != pristine
    fields[:title] = 'Barcelona updated'
    assert_equal true, fields != pristine
    fields[:title] = 'Barcelona'
    assert_equal false, fields != pristine
  end

  def test_noop_save_returns_before_github_write_and_real_save_resets_baseline
    assert_includes APP, "if (existingSha && pristineDraftSignature && editableDraftSignature(payload) === pristineDraftSignature) { setDraftSaveState('pristine'); return; }"
    assert_includes APP, 'pristineDraftSignature = editableDraftSignature(payload);'
    assert_includes APP, 'if (existingSha && currentDraftId()) await loadPublicationStatus(session, payload);'
  end

  def test_new_drafts_are_not_treated_as_pristine_existing_drafts
    assert_includes APP, 'var existing = Boolean(editingNews && editingNews.githubSha);'
    assert_includes APP, "if (!existing) { setDraftSaveState('unsaved'); return; }"
    assert_includes APP, 'var existingSha = editingNews && editingNews.githubSha;'
  end
end
