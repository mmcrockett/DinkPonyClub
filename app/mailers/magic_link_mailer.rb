# frozen_string_literal: true

class MagicLinkMailer < ApplicationMailer
  def sign_in(player)
    @player = player
    @url = magic_link_url(token: player.generate_token_for(:magic_link))

    mail to: player.email
  end
end
