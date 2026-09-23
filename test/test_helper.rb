ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

OmniAuth.config.test_mode = true

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Stubs the next OmniAuth callback with a mock Google identity. Pass
    # verified: false to simulate an unverified Google email.
    def mock_google_auth(email:, uid: 'mock-google-uid', verified: true, image: nil)
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
        provider: 'google_oauth2',
        uid: uid,
        info: { email: email, image: image },
        extra: { raw_info: { email_verified: verified } }
      )
    end
  end
end
