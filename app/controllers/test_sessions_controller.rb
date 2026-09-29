# frozen_string_literal: true

# Lets system tests skip the OAuth redirect chain, which Capybara races.
# The real flow stays covered by SessionsControllerTest.
class TestSessionsController < ApplicationController
  before_action :block_outside_test

  def create
    sign_in(Player.find(params.expect(:player_id)))
    redirect_to params[:return_to].presence || root_path
  end

  private

  def block_outside_test
    head :not_found unless Rails.env.test?
  end
end
