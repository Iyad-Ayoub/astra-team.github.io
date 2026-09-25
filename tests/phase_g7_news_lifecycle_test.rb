require 'minitest/autorun'

class PhaseG7NewsLifecycleTest < Minitest::Test
  APP = File.expand_path('../assets/js/admin/app.js', __dir__)

  def setup
    @app = File.read(APP)
  end

  def test_published_identity_uses_controlled_content_id_not_slug
    assert_includes @app, 'async function publishedNewsByContentId(session, id)'
    assert_includes @app, "githubOperation('published_find'"
    assert_includes @app, "if (!/^news-[a-z0-9]+$/.test(id))"
  end

  def test_existing_published_path_is_preserved_for_updates
    assert_includes @app, 'function publicSlug(record, published)'
    assert_includes @app, "return published.path.replace(/^_news\\//, '').replace(/\\.md$/, '')"
    assert_includes @app, 'function publicNewsPath(record, published)'
    assert_includes @app, 'serializePublicNews(record, media, published)'
    assert_includes @app, 'async function createPublicationCommit(session, branch, record, media, published)'
    assert_includes @app, "githubOperation('publication_prepare'"
  end

  def test_lifecycle_states_and_stale_submission_are_derived_from_github
    %w[Draft Submitted Published Update\ available Update\ submitted Error/Conflict].each do |state|
      assert_includes @app, "'#{state}'"
    end
    assert_includes @app, 'publicationBranchMatchesDraft'
    assert_includes @app, 'Draft changed after submission.'
    assert_includes @app, "githubOperation('pulls'"
    assert_includes @app, 'async function ensureLifecycleBranch(session, branch)'
    assert_includes @app, "githubOperation('ensure_branch'"
    assert_includes @app, 'publicationValidationState'
  end

  def test_unpublish_uses_a_deterministic_pr_branch_and_never_deletes_drafts
    assert_includes @app, "'cms-unpublish/news/' + id"
    assert_includes @app, 'async function submitGithubUnpublish()'
    assert_includes @app, "githubOperation('unpublish_prepare'"
    assert_includes @app, "githubOperation('create_pr'"
    assert_includes @app, 'Public media remains in place until it can be proven unreferenced.'
    refute_match(/contents\/cms\/drafts\/news.*method: 'DELETE'/m, @app)
    refute_match(/contents\/cms\/media\/news.*method: 'DELETE'/m, @app)
  end

  def test_update_and_unpublish_actions_are_bound_without_direct_main_writes
    assert_includes @app, "addEventListener('click', submitGithubPublication)"
    assert_includes @app, "addEventListener('click', submitGithubUnpublish)"
    refute_match(/branch:\s*['\"]main['\"]/, @app)
    refute_includes @app, 'merge: true'
  end
end
