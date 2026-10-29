require 'test_helper'

class CourtScheduleFormTest < ActiveSupport::TestCase
  setup do
    @night = match_nights(:fall_upcoming)
    @match = matches(:fall_future)
    @one = match_slots(:fall_future_slot_one)
    @two = match_slots(:fall_future_slot_two)
  end

  def form(cells)
    CourtScheduleForm.new(match_night: @night, cells: cells)
  end

  test 'replaces the night with the submitted grid' do
    cells = { @one.id => { 1 => '', 2 => "#{@match.id}-2" }, @two.id => { 1 => "#{@match.id}-3" } }

    assert_predicate form(cells), :save
    assert_equal [[@one.id, 2, 2], [@two.id, 1, 3]].sort,
                 @night.court_assignments.pluck(:match_slot_id, :court, :position).sort
  end

  test 'blank cells clear the schedule' do
    assert_predicate form({ @one.id => { 1 => '' } }), :save
    assert_empty @night.court_assignments
  end

  test 'rejects a line placed twice and keeps the existing schedule' do
    cells = { @one.id => { 1 => "#{@match.id}-2" }, @two.id => { 1 => "#{@match.id}-2" } }
    submitted = form(cells)

    assert_not submitted.save
    assert_includes submitted.errors.full_messages, 'A line can only be placed once.'
    assert_equal 1, @night.court_assignments.count
  end

  test 'rejects a line from another night' do
    other = matches(:fall_alpha_bravo)

    assert_not form({ @one.id => { 1 => "#{other.id}-1" } }).save
  end

  test 'rejects a line beyond the night line count' do
    assert_not form({ @one.id => { 1 => "#{@match.id}-9" } }).save
  end
end
