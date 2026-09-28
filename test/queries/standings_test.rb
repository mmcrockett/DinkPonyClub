require 'test_helper'

class StandingsTest < ActiveSupport::TestCase
  test 'orders teams by wins then point differential' do
    rows = Standings.new(seasons(:fall)).rows

    assert_equal [teams(:alpha), teams(:bravo)], rows.map(&:team)
    assert_equal [1, 0], rows.map(&:wins)
    assert_equal [1, 1], rows.map(&:played)
  end

  test 'reports points for, points against, and diff from the match result' do
    row = Standings.new(seasons(:fall)).rows.find { |candidate| candidate.team == teams(:alpha) }

    assert_equal 2, row.points_for
    assert_equal 1, row.points_against
    assert_equal 1, row.diff
  end

  test 'excludes playoff nights' do
    playoff_night = MatchNight.create!(season: seasons(:fall), played_on: Date.new(2026, 10, 1),
                                       label: 'Final', playoff: true)
    match = Match.create!(season: seasons(:fall), match_night: playoff_night,
                          home_team: teams(:bravo), away_team: teams(:alpha))
    lineup = match.lineups.create!(position: 1)
    lineup.games.create!(number: 1, home_score: 11, away_score: 4,
                         home_player_a: players(:sam), home_player_b: players(:ben),
                         away_player_a: players(:ada), away_player_b: players(:grace))
    lineup.games.create!(number: 2, home_score: 11, away_score: 6,
                         home_player_a: players(:sam), home_player_b: players(:ben),
                         away_player_a: players(:ada), away_player_b: players(:grace))
    lineup.games.create!(number: 3, home_score: 11, away_score: 8,
                         home_player_a: players(:sam), home_player_b: players(:ben),
                         away_player_a: players(:ada), away_player_b: players(:grace))

    rows = Standings.new(seasons(:fall)).rows

    assert_equal [1, 1], rows.map(&:played)
  end

  test 'ties count neither as a win nor a loss' do
    charlie = tied_match_for.team

    row = Standings.new(seasons(:fall)).rows.find { |candidate| candidate.team == charlie }

    assert_equal 0, row.wins
    assert_equal 0, row.losses
    assert_equal 1, row.ties
  end

  private

  TiedMatch = Struct.new(:team, :match)

  def tied_match_for
    charlie = Team.create!(name: 'Charlie')
    delta = Team.create!(name: 'Delta')
    home_players = new_roster_for(charlie)
    away_players = new_roster_for(delta)
    match = new_match_between(charlie, delta)

    build_split_lineup!(match, 1, [11, 4], [6, 11], [11, 9], players: home_players[0, 2] + away_players[0, 2])
    build_split_lineup!(match, 2, [4, 11], [11, 6], [9, 11], players: home_players[2, 2] + away_players[2, 2])

    TiedMatch.new(charlie, match)
  end

  def new_match_between(home_team, away_team)
    tied_night = MatchNight.create!(season: seasons(:fall), played_on: Date.new(2026, 9, 21), label: 'Week 2')
    Match.create!(season: seasons(:fall), match_night: tied_night, home_team: home_team, away_team: away_team)
  end

  def new_roster_for(team)
    Array.new(4) { |i| Player.create!(first_name: team.name, last_name: "Player#{i}") }
         .each { |player| RosterSpot.create!(season: seasons(:fall), team: team, player: player) }
  end

  def build_split_lineup!(match, position, *score_pairs, players:)
    home_a, home_b, away_a, away_b = players
    lineup = match.lineups.create!(position: position)
    score_pairs.each_with_index do |(home_score, away_score), index|
      lineup.games.create!(number: index + 1, home_score: home_score, away_score: away_score,
                           home_player_a: home_a, home_player_b: home_b,
                           away_player_a: away_a, away_player_b: away_b)
    end
  end
end
