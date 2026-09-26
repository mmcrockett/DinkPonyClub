# frozen_string_literal: true

class AvailabilitiesController < ApplicationController
  before_action :require_sign_in
  before_action :set_match

  def update
    return redirect_to(root_path, alert: t('.closed')) unless @match.availability_open?

    ActiveRecord::Base.transaction do
      save_playing!
      save_slot_preferences!
    end

    redirect_to root_path, notice: t('.saved')
  end

  private

  def set_match
    @match = Match.find(params.expect(:match_id))
  end

  def save_playing!
    availability = @match.match_availabilities.find_or_initialize_by(player: current_player)
    availability.update!(playing: ActiveModel::Type::Boolean.new.cast(params[:playing]))
  end

  def save_slot_preferences!
    slot_preferences.each do |match_slot_id, preference|
      slot = @match.match_slots.find_by(id: match_slot_id)
      next unless slot && SlotAvailability.preferences.key?(preference)

      slot.slot_availabilities.find_or_initialize_by(player: current_player).update!(preference: preference)
    end
  end

  def slot_preferences
    params.fetch(:slot_preferences, {}).to_unsafe_h
  end
end
