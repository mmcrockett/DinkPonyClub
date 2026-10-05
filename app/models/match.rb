# frozen_string_literal: true

class Match < ApplicationRecord
  belongs_to :season
  belongs_to :match_night
  belongs_to :home_team, class_name: 'Team'
  belongs_to :away_team, class_name: 'Team'
  has_many :lineups, -> { order(:position) }, dependent: :destroy, inverse_of: :match
  has_many :games, through: :lineups
  has_many :lineup_picks, dependent: :destroy

  delegate :played_on, to: :match_night

  validate :teams_are_different
  validate :teams_rostered_in_season
  validate :season_matches_night

  after_update :drop_stale_lineup_picks, if: -> { saved_change_to_home_team_id? || saved_change_to_away_team_id? }

  scope :chronological, -> { joins(:match_night).merge(MatchNight.chronological) }

  def complete?
    lineups.any? && lineups.all?(&:complete?)
  end

  private

  def drop_stale_lineup_picks
    lineup_picks.where.not(team_id: [home_team_id, away_team_id]).delete_all
  end

  def teams_are_different
    return if home_team_id != away_team_id

    errors.add(:away_team, 'must be different from the home team')
  end

  def teams_rostered_in_season
    return unless season && home_team && away_team

    errors.add(:home_team, 'has no roster for this season') if home_team.roster_for(season).none?
    errors.add(:away_team, 'has no roster for this season') if away_team.roster_for(season).none?
  end

  def season_matches_night
    return unless season_id && match_night&.season_id

    return if season_id == match_night.season_id

    errors.add(:match_night, "must belong to this match's season")
  end
end
