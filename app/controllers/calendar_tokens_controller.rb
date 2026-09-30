# frozen_string_literal: true

class CalendarTokensController < ApplicationController
  before_action :require_sign_in

  def create
    current_player.regenerate_calendar_token!
    redirect_to profile_path, notice: t('.regenerated')
  end
end
