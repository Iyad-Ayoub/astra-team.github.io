require 'minitest/autorun'

class PhaseG9dUnpublishUiTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  APP = File.read(File.join(ROOT, 'assets/js/admin/app.js'))

  def test_unpublish_is_only_available_from_the_resolved_published_state
    assert_includes APP, "if (unpublish) { unpublish.hidden = value !== 'Published';"
    %w[Draft Submitted Update\ submitted Unpublish\ submitted Error/Conflict Checking].each do |state|
      refute_match(/unpublish\.hidden = value !== '#{Regexp.escape(state)}'/, APP)
    end
  end

  def test_confirmation_and_cancel_happen_before_any_github_write
    assert_includes APP, "window.confirm('Unpublish this News item?\\n\\nIt will be removed from the public website after approval. The CMS draft and media will be kept.')"
    assert_includes APP, "if (!window.confirm"
    assert_includes APP, 'if (unpublishSubmitting || publicationSubmitting) return;'
    assert_includes APP, "renderPublicationState('Requesting unpublish…', '')"
  end

  def test_controlled_unpublish_preserves_draft_and_media
    handler = APP[/async function submitGithubUnpublish\(\) \{([\s\S]*?)\n  \}\n\n  async function saveGithubDraft/, 1]
    refute_nil handler
    assert_includes APP, "function unpublishBranch(id)"
    assert_includes APP, "return 'cms-unpublish/news/' + id;"
    assert_includes handler, 'branch = unpublishBranch(id)'
    assert_includes handler, "method: 'DELETE'"
    assert_includes handler, "branch: branch"
    assert_includes handler, "base: 'main'"
    assert_includes handler, 'Public media remains in place until it can be proven unreferenced.'
    refute_match(/contents\/cms\/drafts\/news.*method: 'DELETE'/m, handler)
    refute_match(/contents\/cms\/media\/news.*method: 'DELETE'/m, handler)
    refute_match(/assets\/img\/news.*method: 'DELETE'/m, handler)
    refute_match(/branch:\s*['\"]main['\"]/, handler)
  end

  def test_unpublish_pr_has_a_consistent_lifecycle_and_neutral_propagation
    assert_includes APP, "renderPublicationState('Unpublish submitted', 'Validation in progress…', pr.html_url)"
    assert_includes APP, "{ state: 'Unpublish submitted', pull: pr, unpublish: true }"
    assert_includes APP, "unpublish ? 'Validation passed. Ready to merge.'"
    assert_includes APP, "return validation === 'failed' ? 'Validation failed.' : 'Validation in progress…';"
    assert_includes APP, 'publicationStatusEpoch += 1;'
    assert_includes APP, 'stopPublicationStatusPolling();'
    assert_includes APP, 'if (publicationPulls.length) throw new Error'
  end

  def test_completed_unpublish_returns_to_the_existing_editable_draft_state
    assert_includes APP, "if (epoch === publicationStatusEpoch) renderPublicationState('Draft', '');"
    assert_includes APP, 'async function readGithubDraft(session, id)'
    assert_includes APP, "branch: githubDraftBranch"
  end

  def test_no_in_cms_merge_is_added
    refute_match(/method:\s*'PUT'.*\/merge/m, APP)
    refute_includes APP, 'merge: true'
  end
end
