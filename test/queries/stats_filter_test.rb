require 'test_helper'

class StatsFilterTest < ActiveSupport::TestCase
  setup do
    @alpha = Team.new(id: 1, name: 'Alpha')
    @bravo = Team.new(id: 2, name: 'Bravo')
    @rows = [
      row('Zed', 'Zulu', @alpha, 0.5),
      row('Amy', 'Able', @bravo, 0.9),
      row('Mo', 'Middle', nil, 0.2),
      row('Bea', 'Bench', @alpha, nil)
    ]
  end

  test 'defaults to name order' do
    assert_equal ['Amy Able', 'Bea Bench', 'Mo Middle', 'Zed Zulu'], names(StatsFilter.new(@rows))
  end

  test 'unknown sort falls back to name' do
    assert_equal 'name', StatsFilter.new(@rows, sort: 'bogus').sort
  end

  test 'searches by name case-insensitively' do
    assert_equal ['Zed Zulu'], names(StatsFilter.new(@rows, q: 'zUL'))
  end

  test 'filters by team id' do
    assert_equal ['Bea Bench', 'Zed Zulu'], names(StatsFilter.new(@rows, team: '1'))
  end

  test 'filters to substitutes' do
    assert_equal ['Mo Middle'], names(StatsFilter.new(@rows, team: StatsFilter::SUBSTITUTES))
  end

  test 'hides substitutes' do
    assert_equal ['Amy Able', 'Bea Bench', 'Zed Zulu'], names(StatsFilter.new(@rows, hide_substitutes: '1'))
  end

  test 'sorts by win pct descending with zero-game players last' do
    assert_equal ['Amy Able', 'Zed Zulu', 'Mo Middle', 'Bea Bench'], names(StatsFilter.new(@rows, sort: 'win_pct_desc'))
  end

  test 'sorts by win pct ascending with zero-game players last' do
    assert_equal ['Mo Middle', 'Zed Zulu', 'Amy Able', 'Bea Bench'], names(StatsFilter.new(@rows, sort: 'win_pct_asc'))
  end

  test 'sorts by team with substitutes last' do
    assert_equal ['Bea Bench', 'Zed Zulu', 'Amy Able', 'Mo Middle'], names(StatsFilter.new(@rows, sort: 'team'))
  end

  private

  def row(first_name, last_name, team, win_pct)
    PlayerStats::Row.new(player: Player.new(first_name: first_name, last_name: last_name), team: team,
                         win_pct: win_pct)
  end

  def names(filter)
    filter.rows.map { |row| row.player.full_name }
  end
end
