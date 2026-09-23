# frozen_string_literal: true

class SeasonsController < ApplicationController
  def index
    @seasons = Season.chronological
  end
end
