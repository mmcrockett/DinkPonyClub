require 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |options|
    if ENV['SYSTEM_TEST_DOCKER'] == '1'
      options.binary = ENV.fetch('CHROME_BIN')
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
    end
  end

  def sign_in_as(player, return_to: root_path)
    visit test_sign_in_path(player, return_to: return_to)

    assert_current_path return_to
  end
end
