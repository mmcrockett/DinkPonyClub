require 'application_system_test_case'

class AvailabilityTest < ApplicationSystemTestCase
  test 'toggling out greys the slot ratings, toggling back in lets you save a preference' do
    sign_in_as players(:ada)

    assert_text slot_label(:fall_future_slot_one)

    find('label.availability-toggle').click

    assert_selector '[data-availability-target="slots"].opacity-40'
    assert_no_selector '[data-availability-target="slots"] input:not(:disabled)'

    find('label.availability-toggle').click

    assert_no_selector '[data-availability-target="slots"].opacity-40'

    choose_slot_preference(slot_label(:fall_future_slot_two), 'thumbs_up')
    click_button 'Save'

    visit root_path

    assert_selector "input[type=radio][value='thumbs_up']:checked", visible: false
  end

  private

  def slot_label(fixture_name)
    match_slots(fixture_name).starts_at.strftime('%-l:%M %p')
  end

  def choose_slot_preference(slot_time, preference)
    row = all('.availability-slot-row').find { |element| element.text.include?(slot_time) }

    within(row) do
      find("label[data-preference='#{preference}']").click
    end
  end
end
