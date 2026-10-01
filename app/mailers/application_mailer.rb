# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  FALLBACK_FROM = 'no-reply@dinkponyclub.org'

  default from: lambda {
    email_address_with_name(Rails.configuration.x.mail_from.presence || FALLBACK_FROM, 'Dink Pony Club')
  }
  layout 'mailer'
end
