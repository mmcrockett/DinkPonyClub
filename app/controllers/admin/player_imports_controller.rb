# frozen_string_literal: true

module Admin
  class PlayerImportsController < ApplicationController
    include SeasonScoped

    before_action :require_admin

    def new; end

    def create
      result = League::PlayerImport.new(params.expect(player_import: [:lines])[:lines]).call
      redirect_to new_admin_player_import_path(season: current_season),
                  notice: t('.summary', read: result.read, added: result.added,
                                        existed: result.existed, junk: result.junk)
    end
  end
end
