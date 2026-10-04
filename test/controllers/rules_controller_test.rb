require 'test_helper'

class RulesControllerTest < ActionDispatch::IntegrationTest
  test 'signed out can read the rules page' do
    get rules_path

    assert_response :success
    assert_select 'h1', text: /How we play/
    assert_select 'section h3', minimum: 1
  end

  test 'links to the schedule instead of listing season dates' do
    get rules_path

    assert_select 'a[href=?]', season_match_nights_path(Season.default)
    assert_select 'h3', text: /Season dates/, count: 0
  end
end
