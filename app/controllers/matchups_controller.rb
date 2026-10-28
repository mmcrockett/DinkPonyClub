# frozen_string_literal: true

class MatchupsController < ApplicationController
  include SeasonScoped

  before_action :require_sign_in
  before_action :redirect_to_season_scope

  def show
    @season = current_season
    @teams = selectable_teams
    @team = @teams.find { |team| team.id.to_s == params[:team_id] } || default_team
    @match = match_for(@team)
    load_board if @match
    @editable = editable?(@match)
  end

  private

  def load_board
    ratings = PlayerRatings.new(@season)
    @board = MatchupBoard.new(@match, @team, ratings: ratings)
    @cards = MatchupCards.new(@match.match_night, ratings: ratings, records: records).cards
  end

  def records
    Standings.new(@season).rows.to_h { |row| [row.team.id, row.record] }
  end

  def editable?(match)
    match.present? && !match.match_night.canceled? && match.lineups.none? && can_edit_team?(@team)
  end

  def can_edit_team?(team)
    admin? || captain_team_ids_in(@season.id).include?(team.id)
  end

  def default_team
    own_ids = captain_team_ids_in(@season.id) + current_player.roster_spots.where(season_id: @season.id).pluck(:team_id)
    own_ids.filter_map { |id| @teams.find { |team| team.id == id } }.first || @teams.first
  end

  def selectable_teams
    Team.where(id: RosterSpot.where(season: @season).select(:team_id)).order(:name).to_a
  end

  def match_for(team)
    return unless team

    matches = Match.chronological.where(season: @season)
                   .where('matches.home_team_id = :id OR matches.away_team_id = :id', id: team.id)
    matches.find_by(id: params[:match_id]) || matches.merge(MatchNight.upcoming.where(canceled: false)).first
  end
end
