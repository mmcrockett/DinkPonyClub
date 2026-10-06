# frozen_string_literal: true

class AnnouncementMailer < ApplicationMailer
  def announce(player, subject, body, reply_to: nil)
    @player = player
    @body = body
    mail to: player.email, subject: subject, reply_to: reply_to
  end
end
