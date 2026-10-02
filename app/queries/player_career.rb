# frozen_string_literal: true

class PlayerCareer
  attr_reader :player

  def initialize(player)
    @player = player
  end

  def rows
    @rows ||= seasons.filter_map { |season| PlayerStats.new(season).rows.find { |row| row.player == player } }
  end

  def totals
    games = rows.sum(&:games)
    wins = rows.sum(&:wins)

    PlayerStats::Row.new(player: player, games: games, wins: wins, losses: games - wins,
                         win_pct: (wins.to_f / games unless games.zero?))
  end

  private

  def seasons
    rostered = player.roster_spots.select(:season_id)
    played = Match.joins(lineups: :games).merge(Game.involving(player)).select(:season_id)

    Season.where(id: rostered).or(Season.where(id: played)).chronological
  end
end
