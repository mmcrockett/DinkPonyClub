require 'application_system_test_case'

class ScheduleAvailabilityTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  test 'setting availability from the schedule updates without a full page reload' do
    sign_in_as_ada

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

  private

  def sign_in_as_ada
    mock_google_auth(email: players(:ada).email)
    visit root_path
    click_button 'Sign in with Google'

    assert_text players(:ada).full_name
    visit match_nights_path
  end
end
