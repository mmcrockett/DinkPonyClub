# frozen_string_literal: true

class PlayerStats
  Row = Struct.new(:player, :team, :games, :wins, :losses, :win_pct, :sweep_bonus_count, :points, keyword_init: true)

  attr_reader :season

  def initialize(season)
    @season = season
  end

  def rows
    season.roster_spots.includes(:player, :team).map { |roster_spot| row_for(roster_spot) }
  end

  private

  def row_for(roster_spot)
    player = roster_spot.player
    games = games_for(player)
    wins = wins_for(player, games)
    sweep_bonus_count = sweep_bonus_count_for(player, games)

    Row.new(
      player: player, team: roster_spot.team, games: games.size,
      wins: wins, losses: games.size - wins, win_pct: win_pct(wins, games.size),
      sweep_bonus_count: sweep_bonus_count, points: wins + (sweep_bonus_count * season.sweep_bonus)
    )
  end

  def wins_for(player, games)
    games.count { |game| game.winning_side == side_of(game, player) }
  end

  def win_pct(wins, total_games)
    return nil if total_games.zero?

    wins.to_f / total_games
  end

  def games_for(player)
    Game.joins(:lineup)
        .where(lineups: { match_id: season.matches.select(:id) })
        .where(
          'home_player_a_id = :id OR home_player_b_id = :id OR away_player_a_id = :id OR away_player_b_id = :id',
          id: player.id
        )
        .to_a
  end

  def side_of(game, player)
    game.home_players.include?(player) ? :home : :away
  end

  def sweep_bonus_count_for(player, games)
    games.group_by(&:lineup).count do |lineup, lineup_games|
      next false unless lineup.complete?

      side = side_of(lineup_games.first, player)
      lineup_games.all? { |game| game.winning_side == side }
    end
  end
end
