# frozen_string_literal: true

class LineupPick < ApplicationRecord
  SEATS = (1..3).to_a.freeze

  belongs_to :match
  belongs_to :team
  belongs_to :player

  validates :position, inclusion: { in: ScorecardForm::POSITIONS }
  validates :seat, inclusion: { in: SEATS }
  validates :player_id, uniqueness: { scope: :match_id }
  validate :team_is_in_match

  scope :ordered, -> { order(:position, :seat) }

  private

  def team_is_in_match
    return unless match && team

    errors.add(:team, 'must be playing in this match') unless [match.home_team_id, match.away_team_id].include?(team_id)
  end
end
