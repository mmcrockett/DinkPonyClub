# frozen_string_literal: true

module Admin
  class MatchNightsController < ApplicationController
    before_action :require_admin

    def update
      match_night = MatchNight.find(params.expect(:id))
      match_night.update!(canceled: true)

      redirect_back_or_to season_match_nights_path(match_night.season),
                          notice: t('.canceled', label: match_night.label)
    end
  end
end
