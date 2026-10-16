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
    game = games.find { |existing| existing.number == number } || games.build(number: number)
    return game.destroy if home_score.blank? && away_score.blank?

    home, away = [home_player_ids, away_player_ids].map { |ids| ids.compact_blank.map(&:to_i) }
    ensure_same_players!(game, home, away)
    game.update!(home_score: home_score, away_score: away_score, **player_columns(number, home, away))
  end

  private

  def player_columns(number, home, away)
    home_pair, away_pair = [home, away].map { |ids| Game.pair_for(ids, number - 1) }
    { home_player_a_id: home_pair[0], home_player_b_id: home_pair[1],
      away_player_a_id: away_pair[0], away_player_b_id: away_pair[1] }
  end

  def same_players?(game, home, away)
    ((game.home_player_ids - home) + (game.away_player_ids - away)).empty?
  end

  def ensure_same_players!(game, home, away)
    return if games.all? { |other| other == game || same_players?(other, home, away) }

    errors.add(:base, 'players must match the rest of the line')
    raise ActiveRecord::RecordInvalid, self
  end

  def at_most_three_games
    return if games.size <= GAMES_PER_LINEUP

    errors.add(:base, "cannot have more than #{GAMES_PER_LINEUP} games")
  end
end
