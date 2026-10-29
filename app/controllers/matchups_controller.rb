# frozen_string_literal: true

class MatchupsController < ApplicationController
  include SeasonScoped

  before_action :require_sign_in
  before_action :redirect_to_season_scope

  def show
    @season = current_season
    @nights = nights
    @night = selected_night
    @match = selected_match
    @team = selected_team
    load_board if @match
    @editable = editable?(@match)
  end

  private

  def load_board
    ratings = PlayerRatings.new(@season)
    @board = MatchupBoard.new(@match, @team, ratings: ratings)
    @line_assignments = @match.court_assignments.includes(:match_slot).index_by(&:position)
    @cards = MatchupCards.new(@night, ratings: ratings, records: records).cards
  end

  def records
    Standings.new(@season).records
  end

  def editable?(match)
    match.present? && !match.match_night.canceled? && match.lineups.none? && can_edit_team?(@team)
  end

  def can_edit_team?(team)
    admin? || captain_team_ids_in(@season.id).include?(team.id)
  end

  def nights
    MatchNight.where(season: @season, id: Match.select(:match_night_id)).chronological.to_a
  end

  def selected_night
    night = @nights.find { |candidate| candidate.id.to_s == params[:night_id] }
    night || requested_match&.match_night || upcoming_night || @nights.last
  end

  def requested_match
    Match.find_by(id: params[:match_id], season: @season)
  end

  def upcoming_night
    @nights.find { |night| night.played_on >= Date.current && !night.canceled? }
  end

  def selected_match
    matches = @night ? @night.matches.order(:id).to_a : []
    requested = matches.find { |match| match.id.to_s == params[:match_id] }
    requested || matches.find { |match| own_match?(match) } || matches.first
  end

  def own_match?(match)
    own_team_ids.intersect?([match.home_team_id, match.away_team_id])
  end

  def selected_team
    return unless @match

    teams = [@match.home_team, @match.away_team]
    teams.find { |team| team.id.to_s == params[:team_id] } ||
      teams.find { |team| own_team_ids.include?(team.id) } || @match.home_team
  end

  def own_team_ids
    @own_team_ids ||= current_player.roster_spots.where(season_id: @season.id).pluck(:team_id)
  end
end
