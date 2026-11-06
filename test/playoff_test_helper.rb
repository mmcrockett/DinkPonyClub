module PlayoffTestHelper
  Bracket = Struct.new(:season, :night, :teams, :players, keyword_init: true)

  def build_playoff_season
    season = Season.create!(name: 'Playoff Season')
    teams = %w[One Two Three Four].map { |name| Team.create!(name: "Seed #{name}") }
    players = teams.index_with { |team| roster_players_for(season, team) }
    night = season.match_nights.create!(played_on: Date.new(2026, 11, 1), label: 'Playoffs', playoff: true)
    regular_season_results(season, teams, players)
    Bracket.new(season: season, night: night, teams: teams, players: players)
  end

  def sweep(home_score, away_score)
    Array.new(3) { [home_score, away_score] }
  end

  def score_match!(match, players, scores, position: 1)
    lineup = match.lineups.create!(position: position)
    home = players[match.home_team]
    away = players[match.away_team]
    scores.each_with_index do |(home_points, away_points), index|
      lineup.games.create!(number: index + 1, home_score: home_points, away_score: away_points,
                           home_player_a: home[0], home_player_b: home[1],
                           away_player_a: away[0], away_player_b: away[1])
    end
  end

  private

  def roster_players_for(season, team)
    Array.new(2) { |i| Player.create!(first_name: team.name, last_name: "Player#{i}") }
         .each { |player| RosterSpot.create!(season: season, team: team, player: player) }
  end

  def regular_season_results(season, teams, players)
    one, two, three, four = teams
    [[one, four, 11, 2], [two, three, 11, 5]].each_with_index do |(home, away, home_score, away_score), index|
      night = season.match_nights.create!(played_on: Date.new(2026, 10, 1 + index), label: "Week #{index + 1}")
      match = night.matches.create!(season: season, home_team: home, away_team: away)
      score_match!(match, players, sweep(home_score, away_score))
    end
  end
end
