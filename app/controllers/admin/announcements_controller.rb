# frozen_string_literal: true

module Admin
  class AnnouncementsController < ApplicationController
    include SeasonScoped

    before_action :require_admin
    before_action :require_season

    def new
      @form = AnnouncementForm.new
    end

    def create
      @form = AnnouncementForm.new(announcement_params)
      return render :new, status: :unprocessable_content unless @form.valid?

      recipients, skipped = @form.recipients(@season).partition { |player| player.email.present? }
      recipients.each { |player| deliver(player) }
      redirect_to new_admin_announcement_path(season: @season), notice: notice_for(recipients, skipped)
    end

    private

    def require_season
      @season = current_season
      redirect_to admin_players_path, alert: t('admin.announcements.no_season') unless @season
    end

    def announcement_params
      params.expect(announcement: %i[subject body audience])
    end

    def deliver(player)
      AnnouncementMailer.announce(player, @form.subject, @form.body, reply_to: current_player.email).deliver_later
    end

    def notice_for(recipients, skipped)
      message = t('.sent', count: recipients.size)
      return message if skipped.empty?

      "#{message} #{t('.no_email', names: skipped.map(&:full_name).to_sentence)}"
    end
  end
end
