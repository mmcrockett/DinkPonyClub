# frozen_string_literal: true

class MagicLinksController < ApplicationController
  rate_limit to: 5, within: 15.minutes, only: :create,
             with: -> { redirect_to sign_in_path, alert: t('magic_links.create.rate_limited') }

  # Email clients prefetch links, so the emailed GET only renders a button;
  # the POST from that button is what consumes the single-use token.
  def show
    @token = params[:token].to_s
    return if Player.find_by_token_for(:magic_link, @token)&.active?

    redirect_to sign_in_path, alert: t('magic_links.invalid')
  end

  def create
    player = Player.active.find_by(email: params[:email].to_s.strip.downcase.presence)
    MagicLinkMailer.sign_in(player).deliver_later if player

    redirect_to sign_in_path, notice: t('.sent')
  end

  def redeem
    player = Player.redeem_magic_link(params[:token].to_s)
    return redirect_to sign_in_path, alert: t('magic_links.invalid') unless player

    sign_in(player)
    redirect_to profile_path, notice: t('.welcome', first_name: player.first_name)
  end
end
