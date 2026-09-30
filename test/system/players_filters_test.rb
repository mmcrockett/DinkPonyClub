require 'application_system_test_case'

class PlayersFiltersTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  test 'typing in the search filters the table and keeps focus in the field' do
    sign_in_as players(:ada), return_to: players_path

    assert_selector "##{dom_id(players(:sam), :stats)}"

    fill_in 'q', with: 'gra'

    assert_no_selector "##{dom_id(players(:sam), :stats)}"
    assert_equal 'q', evaluate_script('document.activeElement.id')

    send_keys 'ce'

    assert_field 'q', with: 'grace'
    assert_current_path(/q=grace/)
  end

  test 'clicking a column header sorts, and clicking again reverses' do
    sign_in_as players(:ada), return_to: players_path

    click_link 'Player'

    assert_current_path(/dir=desc/)
    assert_selector 'th[aria-sort=descending]', text: /player/i

    click_link 'Player'

    assert_current_path(/dir=asc/)
    assert_selector 'th[aria-sort=ascending]', text: /player/i
  end
end
