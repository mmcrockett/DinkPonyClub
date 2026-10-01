# frozen_string_literal: true

module SeasonScoped
  extend ActiveSupport::Concern

  included do
    helper_method :current_season
  end

  private

  def current_season
    @current_season ||= requested_season || Season.default
  end

  def requested_season
    return Season.find(params.expect(:season_id)) if params.key?(:season_id)

    Season.find_by(id: params[:season])
  end

  def redirect_to_season_scope
    return if params[:season_id] || current_season.nil?

    query = request.query_parameters.except('season').symbolize_keys
    redirect_to url_for(request.path_parameters.merge(query).merge(season_id: current_season, only_path: true))
  end
end
