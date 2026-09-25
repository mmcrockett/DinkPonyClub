# frozen_string_literal: true

module Admin
  class PlayersController < ApplicationController
    before_action :require_admin
    before_action :set_player, only: %i[edit update]

    def index
      @players = Player.by_name
    end

    def new
      @player = Player.new
    end

    def edit; end

    def create
      @player = Player.new(player_params)

      if @player.save
        redirect_to admin_players_path, notice: t('.created', name: @player.full_name)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @player.update(player_params)
        redirect_to admin_players_path, notice: t('.updated', name: @player.full_name)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_player
      @player = Player.find(params.expect(:id))
    end

    def player_params
      params.expect(player: %i[first_name last_name email avatar_url status])
    end
  end
end
