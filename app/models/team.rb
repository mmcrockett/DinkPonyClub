# frozen_string_literal: true

class Team < ApplicationRecord
  has_many :roster_spots, dependent: :destroy
  has_many :players, through: :roster_spots
  has_many :seasons, -> { distinct }, through: :roster_spots
  has_many :home_matches, class_name: 'Match', foreign_key: :home_team_id, dependent: :destroy,
                          inverse_of: :home_team
  has_many :away_matches, class_name: 'Match', foreign_key: :away_team_id, dependent: :destroy,
                          inverse_of: :away_team

  validates :name, presence: true, uniqueness: true

  def roster_for(season)
    Player.joins(:roster_spots)
          .where(roster_spots: { team_id: id, season_id: season.id })
          .by_name
  end

  def matches_in(season)
    Match.where(season: season).where(home_team: self).or(Match.where(season: season).where(away_team: self))
  end
end
