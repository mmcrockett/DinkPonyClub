require 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  def sign_in_as(player, return_to: root_path)
    visit test_sign_in_path(player, return_to: return_to)

    assert_current_path return_to
  end
end
