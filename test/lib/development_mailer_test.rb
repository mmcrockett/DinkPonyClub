require 'test_helper'
require 'open3'

class DevelopmentMailerTest < ActiveSupport::TestCase
  test 'development sign-in links use the Docker port when configured' do
    assert_equal 'http://localhost:3312/sign_in/link?token=preview', sign_in_url(port: '3312')
  end

  test 'development sign-in links keep the native default without a port override' do
    assert_equal 'http://localhost:3000/sign_in/link?token=preview', sign_in_url(port: nil)
  end

  private

  def sign_in_url(port:)
    env = { 'RAILS_ENV' => 'development', 'PORT' => port }
    script = "puts MagicLinkMailer.new.send(:magic_link_url, token: 'preview')"
    stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, Rails.root.join('bin/rails').to_s, 'runner', script)

    assert_predicate status, :success?, stderr
    stdout.lines.last.strip
  end
end
