# frozen_string_literal: true

class PlayerStats
  PLAYER_COLUMNS = %i[home_player_a_id home_player_b_id away_player_a_id away_player_b_id].freeze

  Row = Struct.new(:player, :team, :captain, :games, :wins, :losses, :win_pct, :sweep_bonus_count, :points,
                   keyword_init: true) do
    def substitute?
      team.nil?
    end
  end

  attr_reader :season

  def initialize(season)
    @season = season
  end

  def rows
    roster_spots = season.roster_spots.includes(:player, :team).to_a

    roster_spots.map { |roster_spot| row_for(roster_spot.player, roster_spot.team, roster_spot.captain) } +
      substitutes(roster_spots).map { |player| row_for(player, nil, false) }
  end

  private

  def substitutes(roster_spots)
    Player.where(id: games_by_player_id.keys - roster_spots.map(&:player_id))
  end

  def row_for(player, team, captain)
    games = games_by_player_id.fetch(player.id, [])
    wins = wins_for(player.id, games)
    sweeps = sweep_bonus_count_for(player.id, games)

    Row.new(player:, team:, captain:, games: games.size, wins:, losses: games.size - wins,
            win_pct: win_pct(wins, games.size), sweep_bonus_count: sweeps, points: points(wins, sweeps))
  end

  def points(wins, sweeps)
    wins + (sweeps * season.sweep_bonus)
  end

  def wins_for(player_id, games)
    games.count { |game| game.winning_side == side_of(game, player_id) }
  end

  def win_pct(wins, total_games)
    return nil if total_games.zero?

    wins.to_f / total_games
  end

  def games_by_player_id
    @games_by_player_id ||= season_games.each_with_object({}) do |game, index|
      PLAYER_COLUMNS.each { |column| (index[game.public_send(column)] ||= []) << game }
    end
  end

  def season_games
    Game.joins(:lineup)
        .where(lineups: { match_id: season.matches.select(:id) })
        .includes(lineup: :games)
        .to_a
  end

  def side_of(game, player_id)
    [game.home_player_a_id, game.home_player_b_id].include?(player_id) ? :home : :away
  end

  def sweep_bonus_count_for(player_id, games)
    games.group_by(&:lineup).count do |lineup, lineup_games|
      next false unless lineup.complete?

      side = side_of(lineup_games.first, player_id)
      lineup_games.all? { |game| game.winning_side == side }
    end
  end
end
