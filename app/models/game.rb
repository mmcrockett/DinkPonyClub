# frozen_string_literal: true

class Game < ApplicationRecord
  WINNING_SCORE = 11
  WIN_BY = 2
  PLAYER_COLUMNS = %i[home_player_a_id home_player_b_id away_player_a_id away_player_b_id].freeze

  scope :involving, ->(player) { PLAYER_COLUMNS.map { |column| where(column => player.id) }.reduce(:or) }

  belongs_to :lineup
  belongs_to :home_player_a, class_name: 'Player'
  belongs_to :home_player_b, class_name: 'Player'
  belongs_to :away_player_a, class_name: 'Player'
  belongs_to :away_player_b, class_name: 'Player'

  validates :number, presence: true, inclusion: { in: 1..3 }, uniqueness: { scope: :lineup_id }
  validates :home_score, :away_score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :final_score
  validate :distinct_players
  validate :player_not_in_another_lineup

  def home_players
    [home_player_a, home_player_b]
  end

  def away_players
    [away_player_a, away_player_b]
  end

  def players
    home_players + away_players
  end

  def winning_side
    home_won? ? :home : :away
  end

  def home_won?
    home_score > away_score
  end

  def away_won?
    away_score > home_score
  end

  private

  def final_score
    return if home_score.blank? || away_score.blank?

    leader = [home_score, away_score].max
    trailer = [home_score, away_score].min

    return if leader >= WINNING_SCORE && (leader - trailer) >= WIN_BY

    errors.add(:base, "must be played to #{WINNING_SCORE}, win by #{WIN_BY}")
  end

  def distinct_players
    return if players.compact.uniq.size == players.compact.size

    errors.add(:base, 'players must be distinct within a game')
  end

  def player_not_in_another_lineup
    return unless lineup&.match
    return unless players.compact.intersect?(taken_players)

    errors.add(:base, 'players can only appear in one lineup per match')
  end

  def taken_players
    lineup.match.lineups.where.not(id: lineup.id).flat_map { |other| other.games.flat_map(&:players) }.compact
  end
end
