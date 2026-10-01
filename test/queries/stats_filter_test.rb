require 'test_helper'

class StatsFilterTest < ActiveSupport::TestCase
  setup do
    @alpha = Team.new(id: 1, name: 'Alpha')
    @bravo = Team.new(id: 2, name: 'Bravo')
    @rows = [
      row('Zed', 'Zulu', @alpha, 0.5, games: 4, wins: 2, losses: 2),
      row('Amy', 'Able', @bravo, 0.9, games: 10, wins: 9, losses: 1),
      row('Mo', 'Middle', nil, 0.2, games: 0, wins: 1, losses: 1),
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

  test 'unknown direction falls back to the column default' do
    assert_equal 'asc', StatsFilter.new(@rows, sort: 'name', dir: 'sideways').direction
    assert_equal 'desc', StatsFilter.new(@rows, sort: 'wins', dir: 'sideways').direction
  end

  test 'sorts by name descending' do
    assert_equal ['Zed Zulu', 'Mo Middle', 'Bea Bench', 'Amy Able'], names(StatsFilter.new(@rows, dir: 'desc'))
  end

  test 'win pct defaults to descending with zero-game players last' do
    assert_equal ['Amy Able', 'Zed Zulu', 'Mo Middle', 'Bea Bench'], names(StatsFilter.new(@rows, sort: 'win_pct'))
  end

  test 'sorts by win pct ascending with zero-game players last' do
    assert_equal ['Mo Middle', 'Zed Zulu', 'Amy Able', 'Bea Bench'],
                 names(StatsFilter.new(@rows, sort: 'win_pct', dir: 'asc'))
  end

  test 'sorts by team with substitutes last' do
    assert_equal ['Bea Bench', 'Zed Zulu', 'Amy Able', 'Mo Middle'], names(StatsFilter.new(@rows, sort: 'team'))
  end

  test 'sorts by team descending with substitutes still last' do
    assert_equal ['Amy Able', 'Bea Bench', 'Zed Zulu', 'Mo Middle'],
                 names(StatsFilter.new(@rows, sort: 'team', dir: 'desc'))
  end

  test 'sorts by games, wins and losses with name as the tiebreak' do
    assert_equal ['Amy Able', 'Zed Zulu', 'Bea Bench', 'Mo Middle'], names(StatsFilter.new(@rows, sort: 'games'))
    assert_equal ['Amy Able', 'Zed Zulu', 'Mo Middle', 'Bea Bench'], names(StatsFilter.new(@rows, sort: 'wins'))
    assert_equal ['Bea Bench', 'Amy Able', 'Mo Middle', 'Zed Zulu'],
                 names(StatsFilter.new(@rows, sort: 'losses', dir: 'asc'))
  end

  test 'next direction reverses the active column and uses the default for others' do
    filter = StatsFilter.new(@rows, sort: 'wins', dir: 'desc')

    assert_equal 'asc', filter.next_direction('wins')
    assert_equal 'desc', filter.next_direction('games')
    assert_equal 'asc', filter.next_direction('name')
  end

  private

  def row(first_name, last_name, team, win_pct, **counts)
    PlayerStats::Row.new(player: Player.new(first_name: first_name, last_name: last_name), team: team,
                         win_pct: win_pct, games: 0, wins: 0, losses: 0, **counts)
  end

  def names(filter)
    filter.rows.map { |row| row.player.full_name }
  end
end
