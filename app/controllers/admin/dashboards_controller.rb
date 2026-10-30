# frozen_string_literal: true

module Admin
  class DashboardsController < ApplicationController
    include SeasonScoped

    before_action :require_admin

    def show
      @season = current_season
      @backup_warning = DatabaseBackup.warn?
    end
  end
end
