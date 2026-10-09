# frozen_string_literal: true

class PlayerStats
  Row = Struct.new(:player, :season, :team, :captain, :games, :wins, :losses, :win_pct, :pupr, :rating,
                   :rated_games, keyword_init: true) do
    def substitute?
      team.nil?
    end
  end

  attr_reader :season

  def initialize(season, ratings: nil, lifetime: false)
    @season = season
    @ratings = ratings
    @lifetime = lifetime
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

  def games_by_player_id
    @games_by_player_id ||= season_games.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |game, memo|
      Game::PLAYER_COLUMNS.each { |column| memo[game[column]] << game }
    end
  end

  def season_games
    return Game.all.to_a if @lifetime

    Game.joins(:lineup)
        .where(lineups: { match_id: season.matches.select(:id) })
        .to_a
  end

  def row_for(player, team, captain)
    games = games_by_player_id.fetch(player.id, [])
    wins = wins_for(player, games)

    Row.new(
      player: player, season: season, team: team, captain: captain, games: games.size,
      wins: wins, losses: games.size - wins, win_pct: win_pct(wins, games.size),
      **rating_attributes(player)
    )
  end

  def rating_attributes(player)
    rating = @ratings&.for(player.id)

    { pupr: rating&.pupr, rating: rating&.elo&.round, rated_games: rating&.games }
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
end
