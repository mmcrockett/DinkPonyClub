# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_player
    helper_method :current_player, :signed_in?
  end

  private

  def set_current_player
    Current.player = Player.find_by(id: session[:player_id])
  end

  def current_player
    Current.player
  end

  def signed_in?
    current_player.present?
  end

  def sign_in(player)
    reset_session
    session[:player_id] = player.id
    Current.player = player
  end

  def sign_out
    reset_session
    Current.player = nil
  end

  def require_sign_in
    return if signed_in?

    redirect_to root_path, alert: t('authentication.require_sign_in')
  end
end
