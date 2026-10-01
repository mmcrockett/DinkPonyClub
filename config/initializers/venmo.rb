# frozen_string_literal: true

# CI has no RAILS_MASTER_KEY, so unreadable credentials must give nil, not raise.
Rails.application.config.x.venmo_username =
  begin
    ENV['VENMO_USERNAME'].presence || Rails.application.credentials.dig(:venmo, :username)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end
