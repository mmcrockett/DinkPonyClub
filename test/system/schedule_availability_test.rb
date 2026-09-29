require 'application_system_test_case'

class ScheduleAvailabilityTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  test 'setting availability from the schedule updates without a full page reload' do
    sign_in_as players(:ada), return_to: match_nights_path

    within("##{dom_id(match_nights(:fall_upcoming))}") do
      assert_selector 'label', text: "I'm in"

      find('label', text: 'Maybe').click
    end

    within("##{dom_id(match_nights(:fall_upcoming))}") do
      assert_selector 'input[type=radio][value=maybe]:checked', visible: false
    end

    visit match_nights_path

    within("##{dom_id(match_nights(:fall_upcoming))}") do
      assert_selector 'input[type=radio][value=maybe]:checked', visible: false
    end
  end
end
