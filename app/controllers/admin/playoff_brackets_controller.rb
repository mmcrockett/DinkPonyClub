# frozen_string_literal: true

module Admin
  class PlayoffBracketsController < ApplicationController
    before_action :require_admin
    before_action :set_match_night

    def create
      advance(:seed!, t('.seeded', label: @match_night.label))
    end

    def final
      advance(:create_final!, t('.final_created', label: @match_night.label))
    end

    private

    def set_match_night
      @match_night = MatchNight.find(params.expect(:match_night_id))
    end

    def advance(step, notice)
      League::PlayoffBracket.new(@match_night).public_send(step)
      redirect_to edit_admin_match_night_path(@match_night), notice: notice
    rescue League::PlayoffBracket::Error, ActiveRecord::RecordInvalid => e
      redirect_to edit_admin_match_night_path(@match_night), alert: e.message
    end
  end
end
