# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :require_sign_in

  def show
    @player = current_player
    @roster_spots = @player.roster_spots.includes(:team, :season)
  end
end
