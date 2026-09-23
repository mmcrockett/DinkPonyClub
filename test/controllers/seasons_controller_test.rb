# frozen_string_literal: true

require 'test_helper'

class SeasonsControllerTest < ActionDispatch::IntegrationTest
  test 'index lists every season' do
    get seasons_path

    assert_response :success
    assert_select 'body', text: /#{seasons(:fall).name}/
  end
end
