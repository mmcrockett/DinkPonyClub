# frozen_string_literal: true

class SessionsController < ApplicationController
  def create
    player = Player.authenticate_from_google(request.env['omniauth.auth'])

    if player
      sign_in(player)
      redirect_to profile_path, notice: t('.welcome', first_name: player.first_name)
    else
      redirect_to root_path, alert: t('.not_on_roster')
    end
  end

  def failure
    redirect_to root_path, alert: t('.failed')
  end

  def destroy
    sign_out
    redirect_to root_path, notice: t('.signed_out')
  end
end
