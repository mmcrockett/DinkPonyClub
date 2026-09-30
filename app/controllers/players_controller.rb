# frozen_string_literal: true

class PlayersController < ApplicationController
  include SeasonScoped

  PLAYER_IN_GAME_SQL = 'games.home_player_a_id = :id OR games.home_player_b_id = :id OR ' \
                       'games.away_player_a_id = :id OR games.away_player_b_id = :id'

  before_action :require_sign_in

  def index
    @season = current_season
    @teams = @season ? @season.teams.order(:name) : []
    @filter = StatsFilter.new(@season ? PlayerStats.new(@season).rows : [], filter_params)
    @rows = @filter.rows
  end

  def show
    @player = Player.find(params.expect(:id))
    @season = current_season
    @row = @season && PlayerStats.new(@season).rows.find { |row| row.player == @player }
    @show_contacts = @season.present? && captain_or_admin?(@season)
    @line_results = @season ? line_results : []
  end

  private

  def filter_params
    params.permit(:q, :team, :hide_substitutes, :sort, :dir)
  end

  def line_results
    Game.joins(lineup: { match: :match_night })
        .where(matches: { season_id: @season.id })
        .where(PLAYER_IN_GAME_SQL, id: @player.id)
        .includes(:home_player_a, :home_player_b, :away_player_a, :away_player_b,
                  lineup: { match: %i[match_night home_team away_team] })
        .order('match_nights.played_on', 'lineups.position', 'games.number')
        .group_by(&:lineup)
  end
end
