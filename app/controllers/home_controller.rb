# frozen_string_literal: true

class HomeController < ApplicationController
  include SeasonScoped
  include UpNext

  def index
    return unless signed_in? && current_season

    @season = current_season
    load_up_next(@season)
    @rows = Standings.new(@season).rows
  end
end
