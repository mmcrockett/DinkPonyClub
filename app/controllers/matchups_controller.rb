# frozen_string_literal: true

class MatchupsController < ApplicationController
  include SeasonScoped

  before_action :require_sign_in
  before_action :redirect_to_season_scope
  before_action -> { require_captain_or_admin(current_season) }

  def show
    @season = current_season
    @teams = selectable_teams
    @team = @teams.find { |team| team.id.to_s == params[:team_id] } || @teams.first
    @match = next_match_for(@team)
    @board = MatchupBoard.new(@match, @team) if @match
    @editable = @match.present? && @match.lineups.none?
  end

  private

  def selectable_teams
    teams = Team.where(id: RosterSpot.where(season: @season).select(:team_id)).order(:name)
    admin? ? teams.to_a : teams.where(id: captain_team_ids_in(@season.id)).to_a
  end

  def next_match_for(team)
    return unless team

    Match.chronological.where(season: @season)
         .merge(MatchNight.upcoming.where(canceled: false))
         .where('matches.home_team_id = :id OR matches.away_team_id = :id', id: team.id).first
  end
end
