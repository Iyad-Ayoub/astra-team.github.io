require 'minitest/autorun'

class PhaseG5MediaLibraryTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  APP = File.join(ROOT, 'assets/js/admin/app.js')
  MEDIA = File.join(ROOT, '_pages/admin/media.html')
  FORM = File.join(ROOT, '_includes/admin/news_form.html')

  def setup
    @app = File.read(APP)
  end

  def test_media_has_fixed_draft_only_paths_and_metadata_index
    assert_includes @app, "var githubMediaRoot = 'cms/media/news';"
    assert_includes @app, "var githubMediaIndexPath = githubMediaRoot + '/index.json';"
    assert_includes @app, "branch: githubDraftBranch"
    assert_includes @app, "return githubMediaRoot + '/' + id + '.' + extension;"
    assert_includes @app, '/^media-[a-z0-9]+$/'
    refute_match(/branch:\s*['"]main['"]/, @app)
  end

  def test_image_signatures_and_size_limit_are_enforced
    %w[image/jpeg image/png image/webp 0xff 0x89 0x52 0x57 maxMediaBytes].each { |marker| assert_includes @app, marker }
    assert_includes @app, '5 * 1024 * 1024'
    assert_includes @app, 'Only valid JPEG, PNG, and WebP image files are allowed.'
    refute_includes @app, 'image/svg+xml'
  end

  def test_upload_rechecks_session_and_repository_access
    upload = @app.split('async function uploadMedia', 2).last.split('function verifyGithubRepositoryAccess', 2).first
    assert_includes upload, 'storedGithubSession()'
    assert_includes upload, 'Your GitHub session has expired. Sign in again before uploading.'
    assert_includes upload, 'verifyGithubRepositoryAccess(session)'
    assert_includes upload, 'ensureGithubDraftBranch(session)'
    assert_includes upload, "method: 'PUT'"
  end

  def test_media_is_listed_and_previewed_from_authenticated_api_not_token_urls
    assert_includes @app, 'async function readMediaIndex(session)'
    assert_includes @app, 'async function githubMediaBlob(session, item)'
    assert_includes @app, "Accept: 'application/vnd.github.raw'"
    assert_includes @app, 'URL.createObjectURL(blob)'
    refute_includes @app, 'access_token='
  end

  def test_news_cover_reference_is_controlled_and_backward_compatible
    assert_includes @app, 'cover_media_id'
    assert_includes @app, "if (!Object.prototype.hasOwnProperty.call(record, 'cover_media_id')) record.cover_media_id = null;"
    assert_includes @app, 'Choose a cover image from the CMS media library.'
    assert_includes File.read(FORM), 'admin-news-cover-media-id'
    assert_includes File.read(MEDIA), 'admin-media-upload-form'
  end
end
