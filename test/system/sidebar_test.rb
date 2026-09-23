require 'application_system_test_case'

class SidebarTest < ApplicationSystemTestCase
  test 'rail is visible on load with the panel closed' do
    visit root_path

    assert_selector 'nav[aria-label="Main"]', visible: :visible
    assert_selector '#sidebar-panel', visible: :hidden
  end

  test 'hamburger opens the labeled panel and Escape closes it' do
    visit root_path

    find('button[aria-label="Expand menu"]').click

    assert_selector '#sidebar-panel', visible: :visible
    assert_text 'Seasons'

    find('body').send_keys(:escape)

    assert_selector '#sidebar-panel', visible: :hidden
  end

  test 'signed-out rail offers Google sign-in' do
    visit root_path

    assert_selector 'button[title="Sign in with Google"]'
  end
end
