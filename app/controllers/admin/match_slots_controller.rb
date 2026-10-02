# frozen_string_literal: true

module Admin
  class MatchSlotsController < ApplicationController
    before_action :require_admin
    before_action :set_match_night
    before_action :reject_canceled_night, only: :create

    def create
      slot = @match_night.match_slots.new(starts_at: starts_at, position: next_position)

      if slot.save
        redirect_back_to_schedule notice: t('.created', time: slot.label, label: @match_night.label)
      else
        redirect_back_to_schedule alert: t('.invalid', errors: slot.errors.full_messages.to_sentence)
      end
    end

    def destroy
      slot = @match_night.match_slots.find(params.expect(:id))
      slot.destroy!

      redirect_back_to_schedule notice: t('.removed', time: slot.label, label: @match_night.label)
    end

    private

    def set_match_night
      @match_night = MatchNight.find(params.expect(:match_night_id))
    end

    def reject_canceled_night
      return unless @match_night.canceled?

      redirect_back_to_schedule alert: t('admin.match_slots.create.canceled', label: @match_night.label)
    end

    def starts_at
      time = params.expect(match_slot: [:starts_at]).fetch(:starts_at)
      Time.zone.parse("#{@match_night.played_on} #{time}") if time.present?
    rescue ArgumentError
      nil
    end

    def next_position
      (@match_night.match_slots.maximum(:position) || 0) + 1
    end

    def redirect_back_to_schedule(**flash)
      redirect_to admin_match_nights_path(season: @match_night.season), **flash
    end
  end
end
