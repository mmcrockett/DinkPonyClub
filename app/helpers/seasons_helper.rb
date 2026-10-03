# frozen_string_literal: true

module SeasonsHelper
  CELEBRATION_SEASON = 'Summer 2026'

  def celebration_season?(season)
    season.name == CELEBRATION_SEASON
  end
end
