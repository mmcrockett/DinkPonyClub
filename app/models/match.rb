# frozen_string_literal: true

class Match < ApplicationRecord
  belongs_to :season
  belongs_to :home_team, class_name: 'Team'
  belongs_to :away_team, class_name: 'Team'
  has_many :lineups, -> { order(:position) }, dependent: :destroy, inverse_of: :match
  has_many :games, through: :lineups

  validate :teams_are_different
  validate :teams_rostered_in_season

  scope :chronological, -> { order(:played_on) }

  def recalculate_score!
    # These four columns are a pure derivation of the games below - skipping
    # validations/callbacks here avoids re-triggering this same recalculation.
    # rubocop:disable-next Rails/SkipsModelValidations
    update_columns(
      home_match_points: lineups.sum { |lineup| lineup.match_points_for(:home) },
      away_match_points: lineups.sum { |lineup| lineup.match_points_for(:away) },
      home_points_scored: lineups.sum { |lineup| lineup.points_scored_for(:home) },
      away_points_scored: lineups.sum { |lineup| lineup.points_scored_for(:away) }
    )
  end

  def point_differential
    home_points_scored - away_points_scored
  end

  def winner
    return home_team if home_match_points > away_match_points
    return away_team if away_match_points > home_match_points
    return home_team if point_differential.positive?
    return away_team if point_differential.negative?

    nil
  end

  def complete?
    lineups.any? && lineups.all?(&:complete?)
  end

  private

  def teams_are_different
    return if home_team_id != away_team_id

    errors.add(:away_team, 'must be different from the home team')
  end

  def teams_rostered_in_season
    return unless season && home_team && away_team

    errors.add(:home_team, 'has no roster for this season') if home_team.roster_for(season).none?
    errors.add(:away_team, 'has no roster for this season') if away_team.roster_for(season).none?
  end
end
