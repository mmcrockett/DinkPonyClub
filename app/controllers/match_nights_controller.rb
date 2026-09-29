# frozen_string_literal: true

class MatchNightsController < ApplicationController
  include SeasonScoped

  before_action :require_sign_in

  MATCH_NIGHT_INCLUDES = { matches: [:home_team, :away_team, { lineups: :games }], match_availabilities: [] }.freeze

  def index
    @season = current_season
    @match_nights = load_match_nights(@season)
    @next_match_night = next_match_night_of(@match_nights)
    @weeks_completed = weeks_completed_in(@match_nights)
    @team_view = params[:view] == 'availability' && captain_or_admin?(@season)
    @team_rosters = team_rosters_for(@season) if @team_view
    @availabilities = current_player_availabilities(@match_nights)
  end

  def show
    @match_night = MatchNight.includes(MATCH_NIGHT_INCLUDES).find(params.expect(:id))
    @season = @match_night.season
    @team_view = params[:view] == 'availability' && captain_or_admin?(@season)
    @team_rosters = team_rosters_for(@season) if @team_view
    @availabilities = current_player_availabilities([@match_night])
  end

  private

  def load_match_nights(season)
    return [] unless season

    season.match_nights.chronological.includes(MATCH_NIGHT_INCLUDES)
  end

  def current_player_availabilities(match_nights)
    match_nights.each_with_object({}) do |night, memo|
      availability = night.match_availabilities.find { |a| a.player_id == current_player.id }
      memo[night.id] = availability if availability
    end
  end

  def team_rosters_for(season)
    season.teams.order(:name).map { |team| [team, team.roster_for(season)] }
  end

  def next_match_night_of(match_nights)
    match_nights.find { |night| night.played_on >= Date.current && !night.canceled? }
  end

  def weeks_completed_in(match_nights)
    match_nights.count { |night| !night.playoff? && night.complete? }
  end
end
