# frozen_string_literal: true

class SeasonsController < ApplicationController
  include SeasonScoped
  include UpNext

  before_action :require_sign_in, only: :show

  def index
    @seasons = Season.chronological
  end

  def show
    @season = current_season
    load_up_next(@season)
    @rows = Standings.new(@season).rows
    nights = @season.match_nights.chronological.includes(MatchNightsController::MATCH_NIGHT_INCLUDES).to_a
    @recent_night = nights.reverse.find(&:complete?)
    @weeks_completed = nights.count { |night| !night.playoff? && night.complete? }
  end

  private

  def requested_season
    Season.find(params.expect(:id)) if params.key?(:id)
  end

  def season_switch_path(season, except: [])
    return super unless action_name == 'show'

    season_path(season)
  end
end
