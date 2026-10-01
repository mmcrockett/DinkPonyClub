# frozen_string_literal: true

require 'test_helper'

class MagicLinkMailerTest < ActionMailer::TestCase
  test 'sign_in emails a working link to the player' do
    player = players(:ada)
    mail = MagicLinkMailer.sign_in(player)

    assert_equal [player.email], mail.to
    assert_equal ['no-reply@dinkponyclub.org'], mail.from
    assert_equal I18n.t('magic_link_mailer.sign_in.subject'), mail.subject

    token = mail.text_part.body.to_s[/token=([^\s&]+)/, 1]

    assert_equal player, Player.find_by_token_for(:magic_link, CGI.unescape(token))
    assert_includes mail.html_part.body.to_s, 'http://example.com/sign_in/link?token='
  end
end
