require 'test_helper'

class MatchNightTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate match_nights(:fall_week_one), :valid?
  end

  test 'availability is open before noon central on match day' do
    night = match_nights(:fall_upcoming)

    travel_to night.played_on.in_time_zone.change(hour: 11, min: 59) do
      assert_predicate night, :availability_open?
    end
  end

  test 'availability closes at noon central on match day' do
    night = match_nights(:fall_upcoming)

    travel_to night.played_on.in_time_zone.change(hour: 12, min: 1) do
      assert_not night.availability_open?
    end
  end

  test 'availability is closed the day after the match' do
    night = match_nights(:fall_upcoming)

    travel_to night.played_on.in_time_zone.change(hour: 11) + 1.day do
      assert_not night.availability_open?
    end
  end

  test 'availability is closed when there is no played_on date' do
    night = MatchNight.new(season: seasons(:fall), label: 'Week 9')

    assert_not night.availability_open?
  end

  test 'chronological orders match nights by played_on' do
    assert_equal [match_nights(:fall_week_one), match_nights(:fall_upcoming)],
                 seasons(:fall).match_nights.chronological.to_a
  end

  test 'upcoming excludes nights before today' do
    assert_includes MatchNight.upcoming, match_nights(:fall_upcoming)
    assert_not_includes MatchNight.upcoming, match_nights(:fall_week_one)
  end

  test 'destroying a match night cascades through matches, availabilities, and slots' do
    night = match_nights(:fall_week_one)

    assert_difference('Match.count' => -1, 'Lineup.count' => -1, 'Game.count' => -3) do
      night.destroy
    end
  end

  test 'destroying a match night destroys its availabilities and slots' do
    night = match_nights(:fall_upcoming)

    assert_difference('MatchAvailability.count' => -2, 'MatchSlot.count' => -3) do
      night.destroy
    end
  end
end
