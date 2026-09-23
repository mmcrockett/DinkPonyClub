# frozen_string_literal: true

class Season < ApplicationRecord
  has_many :roster_spots, dependent: :destroy
  has_many :players, through: :roster_spots
  has_many :teams, -> { distinct }, through: :roster_spots
  has_many :matches, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  scope :chronological, -> { order(:starts_on) }

  Standing = Struct.new(:team, :matches_played, :matches_won, :points, :points_scored, :points_allowed,
                        keyword_init: true) do
    def point_differential
      points_scored - points_allowed
    end
  end

  def standings
    teams.map { |team| standing_for(team) }
         .sort_by { |standing| [-standing.points, -standing.point_differential] }
  end

  private

  def standing_for(team)
    home = matches.where(home_team: team)
    away = matches.where(away_team: team)

    Standing.new(
      team: team,
      matches_played: home.count + away.count,
      matches_won: matches_won_by(team, home, away),
      points: home.sum(:home_match_points) + away.sum(:away_match_points),
      points_scored: home.sum(:home_points_scored) + away.sum(:away_points_scored),
      points_allowed: points_allowed_for(home, away)
    )
  end

  def matches_won_by(team, home, away)
    home.count { |match| match.winner == team } + away.count { |match| match.winner == team }
  end

  def points_allowed_for(home, away)
    home.sum(:away_points_scored) + away.sum(:home_points_scored)
  end
end
