# frozen_string_literal: true

class Game < ApplicationRecord
  WINNING_SCORE = 11
  WIN_BY = 2

  belongs_to :lineup

  validates :number, presence: true, inclusion: { in: 1..3 }, uniqueness: { scope: :lineup_id }
  validates :home_score, :away_score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :final_score

  after_destroy :recalculate_match_score
  after_save :recalculate_match_score

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

  def recalculate_match_score
    # Fetch a fresh Match rather than reusing `lineup.match`: within this
    # callback the in-memory `lineup`/`match` association targets may not yet
    # include this very game, since it is still being saved.
    Match.find(lineup.match_id).recalculate_score!
  end
end
