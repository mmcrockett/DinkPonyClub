# frozen_string_literal: true

class Team < ApplicationRecord
  has_many :roster_spots, dependent: :destroy
  has_many :players, through: :roster_spots
  has_many :seasons, -> { distinct }, through: :roster_spots

  validates :name, presence: true, uniqueness: true

  def roster_for(season)
    Player.joins(:roster_spots)
          .where(roster_spots: { team_id: id, season_id: season.id })
          .by_name
  end
end
