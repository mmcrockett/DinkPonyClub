# frozen_string_literal: true

module SeasonScoped
  extend ActiveSupport::Concern

  included do
    helper_method :current_season, :season_switch_path, :lifetime_period?
  end

  private

  def lifetime_period?
    params[:period] == 'lifetime'
  end

  def current_season
    @current_season ||= requested_season || Season.default
  end

  def requested_season
    return Season.find(params.expect(:season_id)) if params.key?(:season_id)

    Season.find_by(id: params[:season])
  end

  def redirect_to_season_scope
    return if params[:season_id] || current_season.nil?

    redirect_to season_switch_path(current_season, except: %w[season])
  end

  def season_switch_path(season, except: [], period: nil)
    query = request.query_parameters.except(*except).merge({ 'period' => period }.compact)
    url_for(request.path_parameters.merge(season_id: season, params: query, only_path: true))
  end
end
