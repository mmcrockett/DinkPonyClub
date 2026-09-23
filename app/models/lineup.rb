# frozen_string_literal: true

class Lineup < ApplicationRecord
  GAMES_PER_LINEUP = 3
  SWEEP_BONUS = 1

  belongs_to :match
  belongs_to :home_player_one, class_name: 'Player'
  belongs_to :home_player_two, class_name: 'Player'
  belongs_to :away_player_one, class_name: 'Player'
  belongs_to :away_player_two, class_name: 'Player'
  has_many :games, -> { order(:number) }, dependent: :destroy, inverse_of: :lineup

  validates :position, presence: true, uniqueness: { scope: :match_id }
  validate :distinct_players
  validate :players_on_their_team
  validate :player_not_in_another_lineup
  validate :at_most_three_games

  scope :ordered, -> { order(:position) }

  def home_players
    [home_player_one, home_player_two]
  end

  def away_players
    [away_player_one, away_player_two]
  end

  def players
    home_players + away_players
  end

  def match_points_for(side)
    won = games.count { |game| game.winning_side == side }
    won += SWEEP_BONUS if complete? && won == GAMES_PER_LINEUP
    won
  end

  def points_scored_for(side)
    games.sum { |game| side == :home ? game.home_score : game.away_score }
  end

  def complete?
    games.size == GAMES_PER_LINEUP
  end

  private

  def distinct_players
    return if players.compact.uniq.size == players.compact.size

    errors.add(:base, 'players must be distinct within a lineup')
  end

  def players_on_their_team
    return unless match&.season && match.home_team && match.away_team

    errors.add(:base, 'home players must be on the home team roster for this season') unless rostered?(:home)
    errors.add(:base, 'away players must be on the away team roster for this season') unless rostered?(:away)
  end

  def rostered?(side)
    team = side == :home ? match.home_team : match.away_team
    roster = team.roster_for(match.season)
    (side == :home ? home_players : away_players).all? { |player| roster.include?(player) }
  end

  def player_not_in_another_lineup
    return unless match

    other_lineups = match.lineups.where.not(id: id)
    taken = other_lineups.flat_map(&:players).compact

    return unless players.compact.intersect?(taken)

    errors.add(:base, 'players can only appear in one lineup per match')
  end

  def at_most_three_games
    return if games.size <= GAMES_PER_LINEUP

    errors.add(:base, "cannot have more than #{GAMES_PER_LINEUP} games")
  end
end
