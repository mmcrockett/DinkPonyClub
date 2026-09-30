# frozen_string_literal: true

class Standings
  Row = Struct.new(:team, :played, :wins, :losses, :ties, :points_for, :points_against, :diff, keyword_init: true)

  MATCH_INCLUDES = [:season, :home_team, :away_team, { lineups: :games }].freeze

  attr_reader :season

  def initialize(season)
    @season = season
  end

  def rows
    season.teams.map { |team| row_for(team) }
          .sort_by { |row| [-row.wins, -row.diff] }
  end

  def results_posted
    completed_results.size
  end

  private

  def regular_season_matches
    @regular_season_matches ||= season.matches.joins(:match_night)
                                      .merge(MatchNight.where(playoff: false))
                                      .includes(MATCH_INCLUDES).to_a
  end

  def completed_results
    @completed_results ||= regular_season_matches.map { |match| MatchResult.new(match) }.select(&:complete?)
  end

  def results_for(team)
    completed_results.filter_map do |result|
      side = side_for(result, team)
      [result, side] if side
    end
  end

  def side_for(result, team)
    return :home if result.match.home_team == team
    return :away if result.match.away_team == team

    nil
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
