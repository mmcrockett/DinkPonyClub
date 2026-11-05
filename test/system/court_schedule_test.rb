require 'application_system_test_case'

class CourtScheduleTest < ApplicationSystemTestCase
  setup do
    @night = match_nights(:fall_upcoming)
    @slot = match_slots(:fall_future_slot_two)
    @match = matches(:fall_future)
    LineupPick.create!(match: @match, team: teams(:alpha), player: players(:ada), position: 2, seat: 1)
    sign_in_as players(:zoe), return_to: edit_admin_match_night_path(@night)
  end

  test 'choosing a line greys it out elsewhere and shows its players' do
    select_line(1, 'L2:')

    assert_selector "select[name='cells[#{@slot.id}][2]'] option[disabled]", text: /\AL2:/
    assert_text players(:ada).full_name
  end

  test 'placing lines drops them from the unplaced list until every line is placed' do
    select_line(1, 'L2:')

    assert_no_selector "li[data-line='#{@match.id}-2']"
    assert_selector "li[data-line='#{@match.id}-3']"
    assert_no_text 'Every line is placed.'

    select_line(2, 'L3:')
    select_line(3, 'L4:')
    select_line(4, 'L5:')

    assert_text 'Every line is placed.'
    assert_no_text 'Not placed yet'
  end

  private

  def select_line(court, prefix)
    field = find("select[name='cells[#{@slot.id}][#{court}]']")
    field.find('option', text: /\A#{Regexp.escape(prefix)}/).select_option
  end
end
