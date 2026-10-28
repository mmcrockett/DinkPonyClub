# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :require_sign_in
  before_action :set_player

  def show
    load_show_data
  end

  def update
    if @player.update(params.expect(player: %i[school_id]))
      redirect_to profile_path, notice: t('.saved')
    else
      load_show_data
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_player
    @player = current_player
  end

  def load_show_data
    @roster_spots = @player.roster_spots.includes(:team, :season)
    @calendar_url = schedule_calendar_url(token: @player.calendar_token)
    @webcal_url = schedule_calendar_url(token: @player.calendar_token, protocol: 'webcal')
  end
end
