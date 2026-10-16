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

  def record_game!(number, home_score:, away_score:, home_player_ids:, away_player_ids:)
    game = games.find_or_initialize_by(number: number)
    return game.destroy if home_score.blank? && away_score.blank?

    home, away = [home_player_ids, away_player_ids].map { |ids| Game.pair_for(ids.compact_blank, number - 1) }
    game.update!(home_score: home_score, away_score: away_score,
                 home_player_a_id: home[0], home_player_b_id: home[1],
                 away_player_a_id: away[0], away_player_b_id: away[1])
  end

  private

  def at_most_three_games
    return if games.size <= GAMES_PER_LINEUP

    errors.add(:base, "cannot have more than #{GAMES_PER_LINEUP} games")
  end
end
