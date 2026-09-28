# frozen_string_literal: true

class AvailabilitiesController < ApplicationController
  before_action :require_sign_in
  before_action :set_match_night

  def update
    return redirect_to(root_path, alert: t('.closed')) unless @match_night.availability_open?

    ActiveRecord::Base.transaction do
      save_status!
      save_slot_preferences!
    end

    redirect_to root_path, notice: t('.saved')
  end

  private

  def set_match_night
    @match_night = MatchNight.find(params.expect(:match_night_id))
  end

  def save_status!
    availability = @match_night.match_availabilities.find_or_initialize_by(player: current_player)
    status = params.dig(:match_availability, :status)
    return unless MatchAvailability.statuses.key?(status)

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
end
