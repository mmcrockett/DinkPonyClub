# frozen_string_literal: true

class TeamsController < ApplicationController
  include SeasonScoped

  before_action :require_sign_in

  def index
    @season = current_season
    @rows = Standings.new(@season).rows
  end

  def show
    @season = current_season
    @team = Team.find(params.expect(:id))
    load_standing
    @roster_spots = @season.roster_spots.where(team: @team).includes(:player).sort_by { |spot| spot.player.full_name }
    @matches = @team.matches_in(@season).chronological
                    .includes(:season, :match_night, :home_team, :away_team, lineups: :games)
  end

  private

  def load_standing
    rows = Standings.new(@season).rows
    @row = rows.find { |row| row.team == @team }
    @rank = rows.index(@row)&.succ
  end
end
