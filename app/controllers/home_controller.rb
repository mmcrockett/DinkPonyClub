# frozen_string_literal: true

class HomeController < ApplicationController
  include SeasonScoped

  def index
    return unless signed_in? && current_season

    @season = current_season
    @next_match_night = next_match_night
    @can_enter_results = captain_or_admin?(@season)
    @availabilities = my_availabilities
    standings = Standings.new(@season)
    @rows = standings.rows
  end

  private

  def next_match_night
    @season.match_nights.upcoming.where(canceled: false).chronological
           .includes(MatchNightsController::MATCH_NIGHT_INCLUDES).first
  end

  def my_availabilities
    return {} unless @next_match_night

    availability = @next_match_night.match_availabilities.find { |a| a.player_id == current_player.id }
    availability ? { @next_match_night.id => availability } : {}
  end
end
