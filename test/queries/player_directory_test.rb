require 'test_helper'

class PlayerDirectoryTest < ActiveSupport::TestCase
  Row = PlayerStats::Row

  setup do
    @ada = Row.new(player: players(:ada), team: teams(:alpha), win_pct: 0.5)
    @ben = Row.new(player: players(:ben), team: teams(:bravo), win_pct: 0.75)
    @sub = Row.new(player: players(:zoe), team: nil, win_pct: nil)
    @rows = [@sub, @ben, @ada]
  end

  test 'sorts by name by default' do
    assert_equal [@ada, @ben, @sub], PlayerDirectory.new(@rows).rows
  end

  test 'sorts by win rate descending with no-game players last' do
    assert_equal [@ben, @ada, @sub], PlayerDirectory.new(@rows, sort: 'win_pct').rows
  end

  test 'sorts by team with substitutes last' do
    assert_equal [@ada, @ben, @sub], PlayerDirectory.new(@rows, sort: 'team').rows
  end

  test 'filters by case-insensitive name search' do
    assert_equal [@ben], PlayerDirectory.new(@rows, query: ' STUB ').rows
  end

  test 'filters by team id or the substitutes bucket' do
    assert_equal [@ada], PlayerDirectory.new(@rows, team: teams(:alpha).id.to_s).rows
    assert_equal [@sub], PlayerDirectory.new(@rows, team: PlayerDirectory::SUBSTITUTES).rows
  end

  test 'hides substitutes' do
    assert_equal [@ada, @ben], PlayerDirectory.new(@rows, hide_substitutes: true).rows
  end
end
