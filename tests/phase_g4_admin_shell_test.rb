require 'minitest/autorun'

class PhaseG4AdminShellTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  LAYOUT = File.join(ROOT, '_layouts/admin.html')
  PAGES = {
    dashboard: 'index.html',
    news: 'news/index.html',
    news_new: 'news/new.html',
    news_edit: 'news/edit.html',
    media: 'media.html'
  }.freeze

  def test_shared_shell_has_all_destinations_and_accessible_active_state
    shell = File.read(LAYOUT)
    assert_includes shell, 'class="astra-admin-sidebar"'
    %w[/admin/ /admin/news/ /admin/media/].each { |route| assert_includes shell, "{{ '#{route}' | relative_url }}" }
    assert_includes shell, 'aria-current="page"'
    assert_includes shell, 'admin-github-avatar'
    assert_includes shell, 'admin-github-login'
    assert_includes shell, 'admin-github-logout'
  end

  def test_each_route_selects_the_correct_active_destination
    pages = PAGES.transform_values { |path| File.read(File.join(ROOT, '_pages/admin', path)) }
    assert_includes pages[:dashboard], 'admin_active: dashboard'
    assert_includes pages[:news], 'admin_active: news'
    assert_includes pages[:news_new], 'admin_active: news'
    assert_includes pages[:news_edit], 'admin_active: news'
    assert_includes pages[:media], 'admin_active: media'
  end

  def test_shell_is_responsive_and_does_not_change_public_styles
    css = File.read(File.join(ROOT, 'assets/css/admin.css'))
    assert_includes css, '.astra-admin-panel { display: grid; grid-template-columns: 208px minmax(0, 1fr);'
    assert_includes css, '@media (max-width: 760px)'
    assert_includes css, 'grid-template-columns: repeat(3, minmax(0, 1fr));'
    refute File.exist?(File.join(ROOT, 'assets/css/main.scss')) && File.read(File.join(ROOT, 'assets/css/main.scss')).include?('astra-admin-sidebar')
  end
end
