# frozen_string_literal: true

module Admin
  class MatchNightsController < ApplicationController
    include SeasonScoped

    before_action :require_admin
    before_action :require_season, only: %i[index new create]

    def index
      @match_nights = season_nights
      @played_night_ids = @season.match_nights.with_games.ids.to_set
    end

    def new
      @match_night = @season.match_nights.new
    end

    def edit
      @match_night = MatchNight.includes(:match_slots,
                                         matches: [:home_team, :away_team,
                                                   { lineups: :games }]).find(params.expect(:id))
      @season = @match_night.season
      @played = @match_night.played?
      @teams = @season.teams.order(:name).to_a
    end

    def create
      @match_night = @season.match_nights.new(match_night_params)

      if @match_night.save
        redirect_to admin_match_nights_path(season: @season), notice: t('.created', label: @match_night.label)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      match_night = MatchNight.find(params.expect(:id))
      flash_key, message = if match_night.update(params.expect(match_night: %i[label played_on]))
                             [:notice, t('.updated', label: match_night.label)]
                           else
                             [:alert, match_night.errors.full_messages.to_sentence]
                           end

      redirect_to edit_admin_match_night_path(match_night), flash_key => message
    end

    def cancel
      match_night = MatchNight.find(params.expect(:id))
      flash_key, message = if match_night.played?
                             [:alert, t('.played', label: match_night.label)]
                           else
                             match_night.update!(canceled: true)
                             [:notice, t('.canceled', label: match_night.label)]
                           end

      redirect_to admin_match_nights_path(season: match_night.season), flash_key => message
    end

    private

    def season_nights
      @season.match_nights.chronological
             .includes(:match_slots, matches: [:home_team, :away_team, { lineups: :games }]).to_a
    end

    def require_season
      @season = current_season
      redirect_to admin_players_path, alert: t('admin.match_nights.no_season') unless @season
    end

    def match_night_params
      params.expect(match_night: %i[played_on label venue notes playoff])
    end
  end
end
