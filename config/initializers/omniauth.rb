# frozen_string_literal: true

# CI runs the test suite without RAILS_MASTER_KEY (see .github/workflows/ci.yml),
# so credentials must fall back to nil rather than raise -- OmniAuth.config.test_mode
# stands in for real values whenever this returns nil.
google_credential = lambda do |key|
  ENV["GOOGLE_#{key.to_s.upcase}"].presence ||
    Rails.application.credentials.dig(:google, key)
rescue ActiveSupport::MessageEncryptor::InvalidMessage
  nil
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           google_credential.call(:client_id),
           google_credential.call(:client_secret),
           scope: 'email,profile',
           prompt: 'select_account',
           access_type: 'online'
end

OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.logger = Rails.logger
