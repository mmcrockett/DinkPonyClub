# frozen_string_literal: true

class AvailabilitiesController < ApplicationController
  before_action :require_sign_in
  before_action :set_match_night

  def update
    return unless authorize_update?

    ActiveRecord::Base.transaction do
      save_status!(current_player, status_param)
      save_slot_preferences!
    end

    redirect_to after_update_path, notice: t('.saved')
  end

  def update_for_player
    return unless authorize_update_for_player?

    save_status!(@target_player, status_param)

    redirect_to after_update_path, notice: t('.saved', name: @target_player.full_name)
  end

  private

  def set_match_night
    @match_night = MatchNight.find(params.expect(:match_night_id))
  end

  def authorize_update?
    return deny?(t('.closed')) unless can_edit_own_availability?
    return deny?(t('.invalid_status')) unless valid_status?(status_param)

    true
  end

  def authorize_update_for_player?
    return deny?(t('authentication.require_captain_or_admin')) unless captain_or_admin?(@match_night.season)

    return deny?(t('availabilities.update.closed')) if @match_night.past? || @match_night.canceled?

    roster_spot = authorized_roster_spot
    return false unless roster_spot
    return deny?(t('.invalid_status')) unless valid_status?(status_param)

    @target_player = roster_spot.player
    true
  end

  def authorized_roster_spot
    roster_spot = RosterSpot.find_by(season: @match_night.season, player_id: params[:player_id])
    return deny?(t('.not_on_roster')) unless roster_spot
    return deny?(t('authentication.require_captain_or_admin')) unless admin? || captain_for_team?(roster_spot.team_id)

    roster_spot
  end

  def deny?(alert)
    redirect_to after_update_path, alert: alert
    false
  end

  def can_edit_own_availability?
    !@match_night.canceled? && (@match_night.availability_open? || captain_or_admin?(@match_night.season))
  end

  def captain_for_team?(team_id)
    current_player.captain_of_team?(@match_night.season, team_id)
  end

  def valid_status?(status)
    MatchAvailability.statuses.key?(status)
  end

  def status_param
    params.dig(:match_availability, :status)
  end

  def save_status!(player, status)
    availability = @match_night.match_availabilities.find_or_initialize_by(player: player)
    availability.update!(status: status)
  end

  def save_slot_preferences!
    slot_preferences.each do |match_slot_id, preference|
      slot = @match_night.match_slots.find_by(id: match_slot_id)
      next unless slot && SlotAvailability.preferences.key?(preference)

      slot.slot_availabilities.find_or_initialize_by(player: current_player).update!(preference: preference)
    end
  end

  def slot_preferences
    params.fetch(:slot_preferences, {}).to_unsafe_h
  end

  def after_update_path
    return root_path unless turbo_frame_request?

    match_night_path(@match_night, view: params[:view])
  end
end
