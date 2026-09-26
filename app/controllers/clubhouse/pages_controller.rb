# frozen_string_literal: true

module Clubhouse
  class PagesController < ApplicationController
    before_action :require_sign_in
    layout 'clubhouse'

    def show
      unless current_player.active?
        redirect_to root_path, alert: t('clubhouse.inactive')
        return
      end
      if ClubhouseSeason.find_by(current: true)
        render :show
      elsif admin?
        redirect_to clubhouse_setup_path
      else
        redirect_to root_path, alert: t('clubhouse.preparing')
      end
    end

    def setup
      return redirect_to root_path unless admin?

      render :setup
    end

    def import
      return head :forbidden unless admin? && current_player.active?

      upload = params[:season_file]
      unless upload.respond_to?(:read) && upload.size <= 2.megabytes
        raise Import::Invalid,
              'Choose a JSON season file under 2 MB.'
      end

      document = JSON.parse(upload.read)
      items = document.is_a?(Array) ? document : [document]
      raise Import::Invalid, 'Choose at most 20 seasons.' if items.size > 20

      ClubhouseSeason.transaction do
        items.each { |item| Import.create!(item, current: item['id'] == params[:current_slug]) }
      end
      redirect_to clubhouse_path, notice: t('clubhouse.imported')
    rescue JSON::ParserError, Import::Invalid, ActiveRecord::RecordInvalid => e
      redirect_to clubhouse_setup_path, alert: e.message
    end
  end
end
