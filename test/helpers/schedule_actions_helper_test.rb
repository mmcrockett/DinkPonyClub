require 'test_helper'

class ScheduleActionsHelperTest < ActionView::TestCase
  include MatchNightsHelper

  test 'matchup_center is plain text when the row does not link' do
    assert_equal 'vs', matchup_center(matches(:fall_future), nil)
  end

  test 'matchup_center shows a pencil pill for a linked, unfinished match' do
    html = matchup_center(matches(:fall_future), '/matches/1/edit')

    assert_includes html, ScheduleActionsHelper::MATCHUP_PILL_CLASSES
    assert_includes html, '<svg'
    assert_includes html, 'vs'
  end

  test 'matchup_center shows the score in a pill, without a pencil, for a finished match' do
    html = matchup_center(matches(:fall_alpha_bravo), '/matches/1')

    assert_includes html, ScheduleActionsHelper::MATCHUP_PILL_CLASSES
    assert_includes html, '2 - 1'
    assert_not_includes html, '<svg'
  end
end
