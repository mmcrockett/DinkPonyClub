# frozen_string_literal: true

class StatsController < ApplicationController
  include SeasonScoped

  before_action :require_sign_in

  def show
    @season = current_season
    @teams = @season ? @season.teams.order(:name) : []
    @filter = StatsFilter.new(@season ? PlayerStats.new(@season).rows : [], filter_params)
    @rows = @filter.rows
  end

  private

  def filter_params
    params.permit(:q, :team, :hide_substitutes, :sort)
  end
end
