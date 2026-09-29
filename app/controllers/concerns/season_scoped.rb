# frozen_string_literal: true

module SeasonScoped
  extend ActiveSupport::Concern

  included do
    helper_method :current_season
  end

  private

  def current_season
    @current_season ||= Season.find_by(id: params[:season]) ||
                        Season.current.first || Season.chronological.last
  end
end
