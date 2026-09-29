# frozen_string_literal: true

class Standings
  Row = Struct.new(:team, :played, :wins, :losses, :ties, :points_for, :points_against, :diff, keyword_init: true)

  attr_reader :season

  def initialize(season)
    @season = season
  end

  def rows
    season.teams.map { |team| row_for(team) }
          .sort_by { |row| [-row.wins, -row.diff] }
  end

  def results_posted
    regular_season_matches.count { |match| MatchResult.new(match).complete? }
  end

  private

  def regular_season_matches
    season.matches.joins(:match_night).merge(MatchNight.where(playoff: false))
  end

  def results_for(team)
    home = regular_season_matches.where(home_team: team).map { |match| [MatchResult.new(match), :home] }
    away = regular_season_matches.where(away_team: team).map { |match| [MatchResult.new(match), :away] }

    (home + away).select { |result, _side| result.complete? }
  end

  def row_for(team)
    results = results_for(team)
    record = record_for(results, team)
    points_for = results.sum { |result, side| points_earned(result, side) }
    points_against = results.sum { |result, side| points_earned(result, side == :home ? :away : :home) }

    Row.new(
      team: team, played: results.size,
      wins: record[:wins], losses: record[:losses], ties: record[:ties],
      points_for: points_for, points_against: points_against, diff: points_for - points_against
    )
  end

  def record_for(results, team)
    {
      wins: results.count { |result, _side| result.winner == team },
      losses: results.count { |result, _side| result.winner.present? && result.winner != team },
      ties: results.count { |result, _side| result.winner.nil? }
    }
  end

  def points_earned(result, side)
    side == :home ? result.home_points : result.away_points
  end
end
