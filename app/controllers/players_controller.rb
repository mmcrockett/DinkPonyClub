# frozen_string_literal: true

class PlayersController < ApplicationController
  include SeasonScoped

  PLAYER_IN_GAME_SQL = 'games.home_player_a_id = :id OR games.home_player_b_id = :id OR ' \
                       'games.away_player_a_id = :id OR games.away_player_b_id = :id'

  before_action :require_sign_in
  before_action :set_player, only: %i[show edit update]
  before_action :require_self_or_admin, only: %i[edit update]

  def index
    @season = current_season
    rows = @season ? PlayerStats.new(@season).rows : []
    @substitute_count = rows.count(&:substitute?)
    @rostered_count = rows.size - @substitute_count
    @rows = directory_rows(rows)
    @teams = @season ? @season.teams.order(:name) : Team.none
    @show_contacts = @season.present? && captain_or_admin?(@season)
  end

  def show
    @season = current_season
    @row = @season && PlayerStats.new(@season).rows.find { |row| row.player == @player }
    @show_contacts = @season.present? && captain_or_admin?(@season)
    @line_results = @season ? line_results : []
  end

  def edit; end

  def update
    if @player.update(params.expect(player: %i[phone contact_email]))
      redirect_to player_path(@player), notice: t('.updated')
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_player
    @player = Player.find(params.expect(:id))
  end

  def require_self_or_admin
    return if @player == current_player || admin?

    redirect_to root_path, alert: t('players.forbidden')
  end

  def directory_rows(rows)
    PlayerDirectory.new(rows, query: params[:q], team: params[:team],
                              hide_substitutes: params[:hide_substitutes] == '1', sort: params[:sort]).rows
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
