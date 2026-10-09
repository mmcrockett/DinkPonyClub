# frozen_string_literal: true

class StandingsController < ApplicationController
  include SeasonScoped

  before_action :require_sign_in
  before_action :redirect_to_season_scope

  def show
    @season = current_season
    standings = Standings.new(@season, lifetime: lifetime_period?) if @season
    @rows = standings&.rows || []
    @results_posted = standings&.results_posted || 0
  end
end
