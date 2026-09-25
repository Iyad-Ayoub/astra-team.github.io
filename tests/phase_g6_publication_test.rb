require 'minitest/autorun'
class PhaseG6PublicationTest < Minitest::Test
  APP = File.expand_path('../assets/js/admin/app.js', __dir__)
  def setup; @app = File.read(APP); end
  def test_publication_is_fixed_branch_and_main_pr_only
    assert_includes @app, "'cms-publish/news/' + id"
    assert_includes @app, "githubOperation('ensure_branch'"
    assert_includes @app, "githubOperation('create_pr'"
    refute_includes @app, 'merge: true'
  end
  def test_publication_rereads_draft_and_copies_controlled_media
    %w[readGithubDraft readMediaIndex githubMediaBlob publicNewsPath publicMediaPath cover_media_id].each { |item| assert_includes @app, item }
    assert_includes @app, "'_news/' + publicSlug(record) + '.md'"
  end
  def test_public_slug_is_human_readable_sanitized_and_collision_safe
    assert_includes @app, "function publicSlug(record, published)"
    assert_includes @app, "replace(/[^a-z0-9]+/g, '-')"
    assert_includes @app, "record.id.replace(/^news-/, '').slice(-8)"
    assert_includes @app, "'_news/' + publicSlug(record) + '.md'"
  end
  def test_submitted_status_is_derived_and_reused
    %w[loadPublicationStatus setPublicationStatus Submitted html_url].each { |item| assert_includes @app, item }
    assert_includes @app, "button.disabled = value !== 'Draft'"
  end
  def test_legacy_news_type_cannot_be_published
    assert_includes @app, "validNewsTypes.indexOf(record.type) === -1"
    assert_includes @app, "payload.type === 'news'"
  end
  def test_permissions_and_duplicate_prs_are_checked
    assert_includes @app, 'verifyGithubRepositoryAccess(session)'
    assert_includes @app, "githubOperation('pulls'"
    assert_includes @app, "githubOperation('ensure_branch'"
  end
end
