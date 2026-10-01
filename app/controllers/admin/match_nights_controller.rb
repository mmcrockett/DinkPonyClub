# frozen_string_literal: true

module Admin
  class MatchNightsController < ApplicationController
    before_action :require_admin

    def update
      match_night = MatchNight.find(params.expect(:id))
      match_night.update!(params.expect(match_night: [:canceled]))

      redirect_back_or_to match_nights_path(season: match_night.season_id),
                          notice: t(match_night.canceled? ? '.canceled' : '.restored', label: match_night.label)
    end
  end
end
