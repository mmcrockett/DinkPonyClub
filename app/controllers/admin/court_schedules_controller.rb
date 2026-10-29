# frozen_string_literal: true

module Admin
  class CourtSchedulesController < ApplicationController
    before_action :require_admin
    before_action :set_match_night
    before_action :reject_canceled_night

    def update
      form = CourtScheduleForm.new(match_night: @match_night, cells: cells)

      if form.save
        redirect_to_night notice: t('.saved', label: @match_night.label)
      else
        redirect_to_night alert: t('.invalid', errors: form.errors.full_messages.to_sentence)
      end
    end

    private

    def set_match_night
      @match_night = MatchNight.find(params.expect(:match_night_id))
    end

    def reject_canceled_night
      return unless @match_night.canceled?

      redirect_to_night alert: t('admin.court_schedules.canceled', label: @match_night.label)
    end

    def cells
      courts = CourtAssignment::COURTS.map(&:to_s)
      params.fetch(:cells, {}).permit(@match_night.match_slots.ids.to_h { |id| [id.to_s, courts] }).to_h
    end

    def redirect_to_night(**flash)
      redirect_to edit_admin_match_night_path(@match_night), **flash
    end
  end
end
