# frozen_string_literal: true

class MatchNightsController < ApplicationController
  include SeasonScoped
  include SlotPreferences
  include CurrentAvailabilities

  before_action :require_sign_in
  before_action :redirect_to_season_scope, only: :index

  RESULT_INCLUDES = { matches: [:home_team, :away_team, { lineups: :games }] }.freeze
  MATCH_NIGHT_INCLUDES = RESULT_INCLUDES.merge(match_slots: []).freeze

  def index
    @season = current_season
    @can_enter_results = captain_or_admin?(@season)
    @team_view = params[:view] == 'availability' && @can_enter_results
    @match_nights = load_match_nights(@season)
    @next_match_night = next_match_night_of(@match_nights)
    @weeks_completed = weeks_completed_in(@match_nights)
    load_team_view(@season) if @team_view
    @availabilities = current_player_availabilities(@match_nights)
    @slot_preferences = current_player_slot_preferences(@match_nights)
  end

  def show
    @match_night = MatchNight.includes(MATCH_NIGHT_INCLUDES).find(params.expect(:id))
    @season = @match_night.season
    @can_enter_results = captain_or_admin?(@season)
    @team_view = params[:view] == 'availability' && @can_enter_results
    load_team_view(@season, [@match_night]) if @team_view
    @availabilities = current_player_availabilities([@match_night])
    @slot_preferences = current_player_slot_preferences([@match_night])
  end

  private

  def load_match_nights(season)
    return [] unless season

    nights = season.match_nights.chronological.includes(MATCH_NIGHT_INCLUDES)
    @team_view ? nights.includes(:match_availabilities) : nights
  end

  def load_team_view(season, match_nights = [])
    ActiveRecord::Associations::Preloader.new(records: match_nights, associations: :match_availabilities).call
    @team_rosters = team_rosters_for(season)
    @captain_team_ids = current_player.roster_spots.captains.where(season: season).pluck(:team_id)
  end

  def team_rosters_for(season)
    season.roster_spots.includes(:team, :player).group_by(&:team).sort_by { |team, _| team.name.downcase }
          .map { |team, spots| [team, spots.map(&:player).sort_by { |player| player.full_name.downcase }] }
  end

  def next_match_night_of(match_nights)
    match_nights.find { |night| night.played_on >= Date.current && !night.canceled? }
  end

  def weeks_completed_in(match_nights)
    match_nights.count { |night| !night.playoff? && night.complete? }
  end
end
