# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_player
    helper_method :current_player, :signed_in?, :admin?, :captain_or_admin?, :captain_team_ids_in, :can_edit_scorecard?
  end

  private

  def set_current_player
    Current.player = Player.active.find_by(id: session[:player_id])
  end

  def current_player
    Current.player
  end

  def signed_in?
    current_player.present?
  end

  def admin?
    current_player&.admin?
  end

  def captain_or_admin?(season)
    @captain_or_admin_in ||= {}
    @captain_or_admin_in.fetch(season.id) do
      @captain_or_admin_in[season.id] = admin? || current_player&.captain_in?(season)
    end
  end

  def can_edit_scorecard?(match)
    admin? || (captain_or_admin?(match.season) && !match.results_locked?)
  end

  def captain_team_ids_in(season_id)
    @captain_team_ids_in ||= {}
    @captain_team_ids_in[season_id] ||= current_player.roster_spots.captains.where(season_id: season_id).pluck(:team_id)
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

  def require_admin
    return if admin?

    redirect_to root_path, alert: t('authentication.require_admin')
  end

  def require_captain_or_admin(season)
    return if captain_or_admin?(season)

    redirect_to root_path, alert: t('authentication.require_captain_or_admin')
  end
end
