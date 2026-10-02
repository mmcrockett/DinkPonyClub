require 'application_system_test_case'

class ScheduleAvailabilityTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  test 'setting availability from the schedule updates without a full page reload' do
    sign_in_as players(:ada), return_to: season_match_nights_path(seasons(:fall))

    within("##{dom_id(match_nights(:fall_upcoming))}") do
      assert_selector 'label', exact_text: 'In'

      find('label', text: 'Maybe').click
    end

    within("##{dom_id(match_nights(:fall_upcoming))}") do
      assert_selector 'input[type=radio][value=maybe]:checked', visible: false
    end

    visit season_match_nights_path(seasons(:fall))

    within("##{dom_id(match_nights(:fall_upcoming))}") do
      assert_selector 'input[type=radio][value=maybe]:checked', visible: false
    end
  end

  test 'setting a slot preference saves and persists' do
    sign_in_as players(:ada), return_to: season_match_nights_path(seasons(:fall))
    slot = match_slots(:fall_future_slot_one)
    selector = "input[name='slot_preferences[#{slot.id}]']"

    within("##{dom_id(match_nights(:fall_upcoming))}") do
      first('label', text: 'Rather not', visible: :all).click
    end

    assert_selector "#{selector}[value=thumbs_down]:checked", visible: false
    page.document.synchronize do
      saved = slot.slot_availabilities.find_by!(player: players(:ada)).preference
      raise Capybara::ExpectationNotMet, "preference still #{saved}" unless saved == 'thumbs_down'
    end
  end
end
