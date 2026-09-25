# frozen_string_literal: true

require 'test_helper'

class PwaTest < ActionDispatch::IntegrationTest
  test 'manifest is reachable while signed out and has the expected shape' do
    get pwa_manifest_path(format: :json)

    assert_response :success
    manifest = response.parsed_body

    assert_equal '/', manifest['start_url']
    assert_equal 'standalone', manifest['display']
    assert_equal 3, manifest['icons'].size
  end

  test 'service worker is reachable while signed out' do
    get pwa_service_worker_path(format: :js)

    assert_response :success
    assert_match(/javascript/, response.media_type)
  end
end
