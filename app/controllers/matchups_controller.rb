# frozen_string_literal: true

class MatchupsController < ApplicationController
  include SeasonScoped

  before_action :require_sign_in
  before_action :redirect_to_season_scope
  before_action -> { require_captain_or_admin(current_season) }

  def show
    @season = current_season
    @teams = selectable_teams
    @team = @teams.find { |team| team.id.to_s == params[:team_id] } || default_team
    @match = match_for(@team)
    @board = MatchupBoard.new(@match, @team) if @match
    @editable = editable?(@match)
  end

  private

  def editable?(match)
    match.present? && !match.match_night.canceled? && match.lineups.none?
  end

  def default_team
    captain_ids = captain_team_ids_in(@season.id)
    @teams.find { |team| captain_ids.include?(team.id) } || @teams.first
  end

  def selectable_teams
    teams = Team.where(id: RosterSpot.where(season: @season).select(:team_id)).order(:name)
    admin? ? teams.to_a : teams.where(id: captain_team_ids_in(@season.id)).to_a
  end

  def match_for(team)
    return unless team

    matches = Match.chronological.where(season: @season)
                   .where('matches.home_team_id = :id OR matches.away_team_id = :id', id: team.id)
    matches.find_by(id: params[:match_id]) || matches.merge(MatchNight.upcoming.where(canceled: false)).first
  end
end
