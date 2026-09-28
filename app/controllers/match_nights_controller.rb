# frozen_string_literal: true

class MatchNightsController < ApplicationController
  include SeasonScoped

  before_action :require_sign_in

  def index
    @season = current_season
    @match_nights = load_match_nights(@season)
    @next_match_night = next_match_night_of(@match_nights)
    @weeks_completed = weeks_completed_in(@match_nights)
    @team_view = params[:view] == 'availability' && captain_or_admin?(@season)
    @availabilities = current_player_availabilities(@match_nights)
  end

  def show
    @match_night = MatchNight.find(params.expect(:id))
    @season = @match_night.season
    @team_view = params[:view] == 'availability' && captain_or_admin?(@season)
    @availabilities = current_player_availabilities([@match_night])
  end

  private

  def load_match_nights(season)
    return [] unless season

    season.match_nights.chronological
          .includes(matches: [:home_team, :away_team, { lineups: :games }], match_availabilities: :player)
  end

  def current_player_availabilities(match_nights)
    MatchAvailability.where(match_night: match_nights, player: current_player).index_by(&:match_night_id)
  end

  def next_match_night_of(match_nights)
    match_nights.find { |night| night.played_on >= Date.current && !night.canceled? }
  end

  def weeks_completed_in(match_nights)
    match_nights.count { |night| !night.playoff? && night.complete? }
  end
end
