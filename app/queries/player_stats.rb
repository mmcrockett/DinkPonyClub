# frozen_string_literal: true

class PlayerStats
  Row = Struct.new(:player, :team, :games, :wins, :losses, :win_pct, :sweep_bonus_count, :sweep_bonus_points,
                   :points, keyword_init: true) do
    def substitute?
      team.nil?
    end
  end

  GAME_INCLUDES = { lineup: :games }.freeze
  PLAYER_COLUMNS = %i[home_player_a_id home_player_b_id away_player_a_id away_player_b_id].freeze

  attr_reader :season

  def initialize(season)
    @season = season
  end

  def rows
    roster_spots = season.roster_spots.includes(:player, :team).to_a

    roster_spots.map { |roster_spot| row_for(roster_spot.player, roster_spot.team) } +
      substitutes(roster_spots).map { |player| row_for(player, nil) }
  end

  private

  def substitutes(roster_spots)
    Player.where(id: games_by_player_id.keys - roster_spots.map(&:player_id))
  end

  def games_by_player_id
    @games_by_player_id ||= season_games.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |game, memo|
      PLAYER_COLUMNS.each { |column| memo[game[column]] << game }
    end
  end

  def season_games
    Game.joins(:lineup)
        .where(lineups: { match_id: season.matches.select(:id) })
        .includes(GAME_INCLUDES)
        .to_a
  end

  def row_for(player, team)
    games = games_by_player_id.fetch(player.id, [])
    wins = wins_for(player, games)
    sweep_bonus_count = sweep_bonus_count_for(player, games)
    sweep_bonus_points = sweep_bonus_count * season.sweep_bonus

    Row.new(
      player: player, team: team, games: games.size,
      wins: wins, losses: games.size - wins, win_pct: win_pct(wins, games.size),
      sweep_bonus_count: sweep_bonus_count, sweep_bonus_points: sweep_bonus_points,
      points: wins + sweep_bonus_points
    )
  end

  def wins_for(player, games)
    games.count { |game| game.winning_side == side_of(game, player) }
  end

  def win_pct(wins, total_games)
    return nil if total_games.zero?

    wins.to_f / total_games
  end

  def side_of(game, player)
    [game.home_player_a_id, game.home_player_b_id].include?(player.id) ? :home : :away
  end

  def sweep_bonus_count_for(player, games)
    games.group_by(&:lineup).count do |lineup, lineup_games|
      next false unless lineup.complete?

      side = side_of(lineup_games.first, player)
      lineup_games.all? { |game| game.winning_side == side }
    end
  end
end
