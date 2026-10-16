# frozen_string_literal: true

# Lets system tests (and local development) skip the OAuth redirect chain, which Capybara races.
# The real flow stays covered by SessionsControllerTest.
class TestSessionsController < ApplicationController
  before_action :block_outside_local

  def create
    sign_in(Player.find(params.expect(:player_id)))
    redirect_to params[:return_to].presence || root_path
  end

  private

  def block_outside_local
    head :not_found unless Rails.env.local?
  end
end
