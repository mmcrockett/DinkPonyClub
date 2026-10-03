# frozen_string_literal: true

class PlayersController < ApplicationController
  include SeasonScoped

  before_action :require_sign_in
  before_action :redirect_to_season_scope

  def index
    @season = current_season
    @teams = @season ? @season.teams.order(:name) : []
    @captain_view = @season.present? && captain_or_admin?(@season)
    @filter = StatsFilter.new(stats_rows, filter_params)
    @rows = @filter.rows
    @owing_ids = @captain_view ? Charge.owing_player_ids(@season) : []
  end

  def show
    @player = Player.find(params.expect(:id))
    @season = current_season
    @career = PlayerCareer.new(@player)
    @row = @career.rows.find { |row| row.season == @season }
    @show_contacts = @season.present? && captain_or_admin?(@season)
    @line_results = @season ? line_results : []
  end

  private

  def stats_rows
    return [] unless @season

    PlayerStats.new(@season, ratings: (PlayerRatings.new(@season) if @captain_view)).rows
  end

  def filter_params
    params.permit(:q, :team, :hide_substitutes, :sort, :dir)
  end

  def line_results
    Game.joins(lineup: { match: :match_night })
        .where(matches: { season_id: @season.id })
        .merge(Game.involving(@player))
        .includes(:home_player_a, :home_player_b, :away_player_a, :away_player_b,
                  lineup: { match: %i[match_night home_team away_team] })
        .order('match_nights.played_on', 'lineups.position', 'games.number')
        .group_by(&:lineup)
  end
end
