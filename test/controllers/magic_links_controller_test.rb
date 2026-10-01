# frozen_string_literal: true

require 'test_helper'

class MagicLinksControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { Rails.cache.clear }

  test 'emails a sign-in link to an active player' do
    assert_enqueued_email_with MagicLinkMailer, :sign_in, args: [players(:ada)] do
      post magic_link_path, params: { email: ' ADA@example.test ' }
    end

    assert_redirected_to sign_in_path
    assert_equal I18n.t('magic_links.create.sent'), flash[:notice]
  end

  test 'shows the same message and sends nothing for an unknown email' do
    assert_no_enqueued_emails do
      post magic_link_path, params: { email: 'stranger@example.test' }
    end

    assert_redirected_to sign_in_path
    assert_equal I18n.t('magic_links.create.sent'), flash[:notice]
  end

  test 'sends nothing for a blank email even when a player has no email' do
    assert_nil players(:sam).email

    assert_no_enqueued_emails do
      post magic_link_path, params: { email: '  ' }
    end

    assert_redirected_to sign_in_path
    assert_equal I18n.t('magic_links.create.sent'), flash[:notice]
  end

  test 'sends nothing to an inactive player' do
    assert_no_enqueued_emails do
      post magic_link_path, params: { email: players(:wade).email }
    end

    assert_equal I18n.t('magic_links.create.sent'), flash[:notice]
  end

  test 'rate-limits link requests' do
    5.times { post magic_link_path, params: { email: 'stranger@example.test' } }

    assert_no_enqueued_emails do
      post magic_link_path, params: { email: players(:ada).email }
    end

    assert_redirected_to sign_in_path
    assert_equal I18n.t('magic_links.create.rate_limited'), flash[:alert]
  end

  test 'the emailed link renders a sign-in button without consuming the token' do
    token = players(:ada).generate_token_for(:magic_link)

    get magic_link_path(token: token)

    assert_response :success
    assert_select "form[action='#{redeem_magic_link_path}'] input[name=token][value=?]", token
    assert_nil session[:player_id]
    assert_equal players(:ada), Player.find_by_token_for(:magic_link, token)
  end

  test 'an invalid link redirects to sign in' do
    get magic_link_path(token: 'bogus')

    assert_redirected_to sign_in_path
    assert_equal I18n.t('magic_links.invalid'), flash[:alert]
  end

  test 'an inactive player link redirects to sign in' do
    get magic_link_path(token: players(:wade).generate_token_for(:magic_link))

    assert_redirected_to sign_in_path
  end

  test 'redeeming signs the player in' do
    post redeem_magic_link_path, params: { token: players(:ada).generate_token_for(:magic_link) }

    assert_redirected_to profile_path
    assert_equal players(:ada).id, session[:player_id]
    follow_redirect!

    assert_select 'h1', text: players(:ada).full_name
  end

  test 'a link works only once' do
    token = players(:ada).generate_token_for(:magic_link)
    post redeem_magic_link_path, params: { token: token }
    delete sign_out_path

    post redeem_magic_link_path, params: { token: token }

    assert_redirected_to sign_in_path
    assert_equal I18n.t('magic_links.invalid'), flash[:alert]
    assert_nil session[:player_id]
  end

  test 'redeeming refuses an inactive player' do
    post redeem_magic_link_path, params: { token: players(:wade).generate_token_for(:magic_link) }

    assert_redirected_to sign_in_path
    assert_nil session[:player_id]
  end
end
