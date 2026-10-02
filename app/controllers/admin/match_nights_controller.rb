# frozen_string_literal: true

module Admin
  class MatchNightsController < ApplicationController
    include SeasonScoped

    before_action :require_admin
    before_action :require_season, only: %i[index create]

    def index
      @match_nights = season_nights
      @match_night = @season.match_nights.new
    end

    def create
      @match_night = @season.match_nights.new(match_night_params)

      if @match_night.save
        redirect_to admin_match_nights_path(season: @season), notice: t('.created', label: @match_night.label)
      else
        @match_nights = season_nights
        render :index, status: :unprocessable_content
      end
    end

    def update
      match_night = MatchNight.find(params.expect(:id))
      match_night.update!(canceled: true)

      redirect_to admin_match_nights_path(season: match_night.season),
                  notice: t('.canceled', label: match_night.label)
    end

    private

    def season_nights
      @season.match_nights.chronological.to_a
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
