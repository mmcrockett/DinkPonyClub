# frozen_string_literal: true

module Clubhouse
  class BaseController < ApplicationController
    before_action :authorize_member
    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: 'Record not found.' }, status: :not_found
    end

    private

    def current_season
      return @current_season if defined?(@current_season)

      @current_season = ClubhouseSeason.find_by(current: true)
    end

    def access
      @access ||= Access.new(current_player, current_season&.snapshot)
    end

    def authorize_member
      response.headers['Cache-Control'] = 'private, no-store'
      unless current_player&.active?
        render json: { error: 'Sign in with your league Google account.' }, status: :unauthorized
        return
      end
      return if access.allowed?

      render json: { error: 'Your account is not linked to the league roster. Ask the organizer.' },
             status: :forbidden
    end
  end
end
