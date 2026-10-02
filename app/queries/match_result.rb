# frozen_string_literal: true

class MatchResult
  attr_reader :match

  def initialize(match)
    @match = match
  end

  def home_points
    lineups.sum { |lineup| match_points_for(lineup, :home) }
  end

  def away_points
    lineups.sum { |lineup| match_points_for(lineup, :away) }
  end

  def home_points_scored
    lineups.sum { |lineup| points_scored_for(lineup, :home) }
  end

  def away_points_scored
    lineups.sum { |lineup| points_scored_for(lineup, :away) }
  end

  def point_differential
    home_points_scored - away_points_scored
  end

  def winner
    points_winner || differential_winner
  end

  def outcome_for(team)
    return 'T' if winner.nil?

    winner == team ? 'W' : 'L'
  end

  delegate :complete?, to: :match

  private

  def lineups
    match.lineups
  end

  def match_points_for(lineup, side)
    won = lineup.games.count { |game| game.winning_side == side }
    won += match.season.sweep_bonus if lineup.complete? && won == Lineup::GAMES_PER_LINEUP
    won
  end

  def points_scored_for(lineup, side)
    lineup.games.sum { |game| side == :home ? game.home_score : game.away_score }
  end

  def points_winner
    return match.home_team if home_points > away_points
    return match.away_team if away_points > home_points

    nil
  end

  def differential_winner
    return match.home_team if point_differential.positive?
    return match.away_team if point_differential.negative?

    nil
  end
end
