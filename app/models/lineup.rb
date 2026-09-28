# frozen_string_literal: true

class Lineup < ApplicationRecord
  GAMES_PER_LINEUP = 3

  belongs_to :match
  has_many :games, -> { order(:number) }, dependent: :destroy, inverse_of: :lineup

  validates :position, presence: true, uniqueness: { scope: :match_id }
  validate :at_most_three_games

  scope :ordered, -> { order(:position) }

  def complete?
    games.size == GAMES_PER_LINEUP
  end

  private

  def at_most_three_games
    return if games.size <= GAMES_PER_LINEUP

    errors.add(:base, "cannot have more than #{GAMES_PER_LINEUP} games")
  end
end
