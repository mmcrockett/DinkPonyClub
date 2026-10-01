# frozen_string_literal: true

module Admin
  class FeesController < ApplicationController
    include SeasonScoped

    before_action :require_admin
    before_action :require_season

    def index
      @fees = @season.fees.order(:name)
      @fee = Fee.new(applies_to_all: true)
    end

    def create
      @fee = @season.fees.new(fee_params)

      if @fee.save
        redirect_to admin_fees_path(season: @season), notice: t('.created', name: @fee.name)
      else
        @fees = @season.fees.order(:name)
        render :index, status: :unprocessable_content
      end
    end

    def destroy
      fee = @season.fees.find(params.expect(:id))
      fee.destroy!
      redirect_to admin_fees_path(season: @season), notice: t('.destroyed', name: fee.name)
    end

    private

    def require_season
      @season = current_season
      redirect_to admin_players_path, alert: t('admin.fees.no_season') unless @season
    end

    def fee_params
      params.expect(fee: %i[name amount applies_to_all])
    end
  end
end
