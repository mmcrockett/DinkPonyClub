# frozen_string_literal: true

module Admin
  class PaymentRequestsController < ApplicationController
    include SeasonScoped

    before_action :require_admin

    def create
      return redirect_to admin_players_path, alert: t('.no_season') unless current_season

      recipients, skipped = requested_players.partition { |player| player.email.present? }
      recipients.each { |player| PaymentRequestMailer.request_payment(player, current_season).deliver_later }
      redirect_to destination, notice: notice_for(recipients, skipped)
    end

    private

    def requested_players
      players = Player.active.where(id: Charge.owing_player_ids(current_season)).by_name
      params[:player_id] ? players.where(id: params[:player_id]) : players
    end

    def destination
      return admin_players_path(season: current_season) unless params[:player_id]

      edit_admin_player_path(params[:player_id], season: current_season)
    end

    def notice_for(recipients, skipped)
      message = t('.sent', count: recipients.size)
      return message if skipped.empty?

      "#{message} #{t('.no_email', names: skipped.map(&:full_name).to_sentence)}"
    end
  end
end
