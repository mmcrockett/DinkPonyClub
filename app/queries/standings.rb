# frozen_string_literal: true

class Standings
  Row = Struct.new(:team, :played, :wins, :losses, :ties, :points_for, :points_against, :diff,
                   :streak, :form, :next_opponent, keyword_init: true)

  MATCH_INCLUDES = [:season, :match_night, :home_team, :away_team, { lineups: :games }].freeze
  FORM_LENGTH = 5

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
                                      .merge(MatchNight.where(playoff: false, canceled: false))
                                      .includes(MATCH_INCLUDES).to_a
  end

  def completed_results
    @completed_results ||= regular_season_matches.map { |match| MatchResult.new(match) }.select(&:complete?)
                                                 .sort_by { |result| [result.match.played_on, result.match.id] }
  end

  def upcoming_matches
    @upcoming_matches ||= regular_season_matches.reject { |match| match.complete? || match.played_on < Date.current }
                                                .sort_by { |match| [match.played_on, match.id] }
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
    outcomes = results.map { |result, _side| outcome_for(result, team) }

    Row.new(
      team: team, played: results.size, **record_for(results, team), **points_summary(results),
      streak: streak_for(outcomes), form: outcomes.last(FORM_LENGTH), next_opponent: next_opponent_for(team)
    )
  end

  def points_summary(results)
    points_for = results.sum { |result, side| points_earned(result, side) }
    points_against = results.sum { |result, side| points_earned(result, side == :home ? :away : :home) }

    { points_for: points_for, points_against: points_against, diff: points_for - points_against }
  end

  def record_for(results, team)
    {
      wins: results.count { |result, _side| result.winner == team },
      losses: results.count { |result, _side| result.winner.present? && result.winner != team },
      ties: results.count { |result, _side| result.winner.nil? }
    }
  end

  def outcome_for(result, team)
    return 'T' if result.winner.nil?

    result.winner == team ? 'W' : 'L'
  end

  def streak_for(outcomes)
    return if outcomes.empty?

    "#{outcomes.last}#{outcomes.reverse.take_while { |outcome| outcome == outcomes.last }.size}"
  end

  def next_opponent_for(team)
    match = upcoming_matches.find { |candidate| [candidate.home_team, candidate.away_team].include?(team) }
    return unless match

    match.home_team == team ? match.away_team : match.home_team
  end

  def points_earned(result, side)
    side == :home ? result.home_points : result.away_points
  end
end
