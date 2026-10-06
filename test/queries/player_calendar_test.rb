require 'test_helper'

class PlayerCalendarTest < ActiveSupport::TestCase
  test 'lists the nights where the player team plays and nights with no matches yet, in order' do
    calendar = build(players(:ada), seasons(:fall))

    assert_equal %i[fall_week_one fall_upcoming fall_canceled fall_playoff].map { |name| match_nights(name) },
                 calendar.match_nights
  end

  test 'leaves out a night where only other teams play' do
    RosterSpot.create!(season: seasons(:fall), team: teams(:sc_other), player: players(:zoe))
    Match.create!(season: seasons(:fall), match_night: match_nights(:fall_playoff),
                  home_team: teams(:bravo), away_team: teams(:sc_other))

    assert_not_includes build(players(:ada), seasons(:fall)).match_nights, match_nights(:fall_playoff)
  end

  test 'has no nights and no last_modified without a roster spot' do
    calendar = build(players(:zoe), seasons(:fall))

    assert_empty calendar.match_nights
    assert_nil calendar.last_modified
  end

  test 'has no nights without a season' do
    assert_empty build(players(:ada), nil).match_nights
  end

  test 'last_modified follows a slot edit' do
    calendar_before = build(players(:ada), seasons(:fall)).last_modified

    travel 1.minute do
      match_slots(:fall_future_slot_two).update!(starts_at: match_slots(:fall_future_slot_two).starts_at + 15.minutes)
    end

    assert_operator build(players(:ada), seasons(:fall)).last_modified, :>, calendar_before
  end

  test 'last_modified follows the player own availability change' do
    calendar_before = build(players(:ada), seasons(:fall)).last_modified

    travel 1.minute do
      match_availabilities(:fall_future_ada).update!(status: 'out')
    end

    assert_operator build(players(:ada), seasons(:fall)).last_modified, :>, calendar_before
  end

  test 'cache_key changes when a slot is deleted' do
    before = build(players(:ada), seasons(:fall)).cache_key

    match_slots(:fall_future_slot_three).destroy!

    assert_not_equal before, build(players(:ada), seasons(:fall)).cache_key
  end

  test 'cache_key includes the default start hour so a change to it busts subscriber caches' do
    assert_includes build(players(:ada), seasons(:fall)).cache_key, PlayerCalendar::DEFAULT_HOUR
  end

  test 'last_modified follows a team rename' do
    calendar_before = build(players(:ada), seasons(:fall)).last_modified

    travel 1.minute do
      teams(:alpha).update!(name: 'Renamed Alpha')
    end

    assert_operator build(players(:ada), seasons(:fall)).last_modified, :>, calendar_before
  end

  private

  def build(player, season)
    PlayerCalendar.new(player, season, night_url: ->(night) { "https://example.test/schedule/#{night.id}" })
  end
end
