# frozen_string_literal: true

class PlayerCareer
  Row = Struct.new(:season, :team, :captain, :games, :wins, :losses, :win_pct, keyword_init: true) do
    def substitute?
      team.nil?
    end
  end

  attr_reader :player

  def initialize(player)
    @player = player
  end

  def rows
    @rows ||= seasons.filter_map { |season| row_for(season) }
  end

  def totals
    games = rows.sum(&:games)
    wins = rows.sum(&:wins)

    Row.new(games: games, wins: wins, losses: games - wins, win_pct: (wins.to_f / games unless games.zero?))
  end

  private

  def seasons
    rostered = player.roster_spots.select(:season_id)
    played = Match.joins(lineups: :games).merge(Game.involving(player)).select(:season_id)

    Season.where(id: rostered).or(Season.where(id: played)).chronological
  end

  def row_for(season)
    stats = PlayerStats.new(season).rows.find { |row| row.player == player }
    return unless stats

    Row.new(season: season, **stats.to_h.slice(:team, :captain, :games, :wins, :losses, :win_pct))
  end
end
