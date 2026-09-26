require 'application_system_test_case'

class SidebarTest < ApplicationSystemTestCase
  test 'desktop: starts expanded with labels visible' do
    visit root_path

    assert_selector 'aside#sidebar'
    assert_selector 'body[data-sidebar="expanded"]'
    assert_text 'Seasons'
  end

  test 'desktop: toggle collapses the sidebar and the state survives navigation' do
    visit root_path

    find('button[aria-label="Toggle menu"]').click

    assert_selector 'body[data-sidebar="collapsed"]'

    find(:link, title: 'Seasons').click

    assert_selector 'body[data-sidebar="collapsed"]'
  end

  test 'desktop: the toggle stays clickable after expanding' do
    visit root_path

    button = find('button[aria-label="Toggle menu"]')
    button.click

    assert_selector 'body[data-sidebar="collapsed"]'

    find('button[aria-label="Toggle menu"]').click

    assert_selector 'body[data-sidebar="expanded"]'
  end

  test 'mobile: drawer starts closed, opens on click, and Escape closes it' do
    Capybara.current_session.current_window.resize_to(390, 844)

    visit root_path

    assert_selector 'body[data-drawer="closed"]'

    find('button[aria-label="Toggle menu"]').click

    assert_selector 'body[data-drawer="open"]'
    assert_text 'Seasons'

    find('body').send_keys(:escape)

    assert_selector 'body[data-drawer="closed"]'
  ensure
    Capybara.current_session.current_window.resize_to(1400, 1400)
  end

  test 'mobile: reloading does not persist the drawer as open' do
    Capybara.current_session.current_window.resize_to(390, 844)

    visit root_path
    find('button[aria-label="Toggle menu"]').click

    assert_selector 'body[data-drawer="open"]'

    visit root_path

    assert_selector 'body[data-drawer="closed"]'
  ensure
    Capybara.current_session.current_window.resize_to(1400, 1400)
  end

  test 'signed-out sidebar offers Google sign-in' do
    visit root_path

    assert_selector 'button[title="Sign in with Google"]'
  end
end
