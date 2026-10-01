# frozen_string_literal: true

class PaymentRequestMailer < ApplicationMailer
  helper ApplicationHelper

  def request_payment(player, season)
    @player = player
    @season = season
    @charges = Charge.owing_for(player, season).to_a
    return if @charges.empty?

    @total_cents = @charges.sum(&:balance_cents)
    @venmo_url = venmo_url

    total = ActiveSupport::NumberHelper.number_to_currency(@total_cents / 100.0)
    mail to: player.email, subject: default_i18n_subject(season: season.name, total: total)
  end

  private

  def venmo_url
    username = Rails.configuration.x.venmo_username
    return if username.blank?

    query = { txn: 'pay', amount: format('%.2f', @total_cents / 100.0), note: venmo_note }
            .map { |key, value| "#{key}=#{ERB::Util.url_encode(value)}" }.join('&')
    "https://venmo.com/#{ERB::Util.url_encode(username)}?#{query}"
  end

  def venmo_note
    "DinkPonyClub #{@charges.map { |charge| charge.fee.name.downcase }.to_sentence}"
  end
end
