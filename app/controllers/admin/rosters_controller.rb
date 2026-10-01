# frozen_string_literal: true

module Admin
  class RostersController < ApplicationController
    include SeasonScoped

    before_action :require_admin

    def show
      @season = current_season
      @spots_by_team = roster_spots_by_team
    end

    def update
      @season = Season.find(params.expect(:season))
      assign_captains(Array(params[:captain_ids]).compact_blank.map(&:to_i))
      redirect_to admin_roster_path(season: @season), notice: t('.saved', season: @season.name)
    end

    private

    def assign_captains(captain_ids)
      RosterSpot.transaction do
        @season.roster_spots.each do |spot|
          spot.update!(captain: captain_ids.include?(spot.id))
        end
      end
    end

    def roster_spots_by_team
      return {} unless @season

      @season.roster_spots
             .includes(:team, :player)
             .sort_by { |spot| [spot.team.name, spot.player.last_name, spot.player.first_name] }
             .group_by(&:team)
    end
  end
end
