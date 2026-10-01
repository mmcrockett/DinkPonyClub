require 'application_system_test_case'

class HomeTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  test 'setting availability on the up-next card saves without leaving the homepage' do
    sign_in_as players(:ada), return_to: root_path

    within("##{dom_id(match_nights(:fall_upcoming))}") do
      find('label', exact_text: 'Out').click
    end

    within("##{dom_id(match_nights(:fall_upcoming))}") do
      assert_selector 'input[type=radio][value=out]:checked', visible: false
    end

    assert_current_path root_path
    availability = MatchAvailability.find_by(match_night: match_nights(:fall_upcoming), player: players(:ada))

    assert_equal 'out', availability.status
  end
end
