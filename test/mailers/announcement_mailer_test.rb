require 'test_helper'

class AnnouncementMailerTest < ActionMailer::TestCase
  test 'addresses the player with the subject, body and reply-to' do
    mail = AnnouncementMailer.announce(players(:ada), 'Rain out', 'Cancelled.', reply_to: 'zoe@example.com')

    assert_equal [players(:ada).email], mail.to
    assert_equal 'Rain out', mail.subject
    assert_equal ['zoe@example.com'], mail.reply_to
    assert_includes mail.text_part.body.to_s, "Hi #{players(:ada).first_name},"
    assert_includes mail.text_part.body.to_s, 'Cancelled.'
  end

  test 'strips script tags from the html body' do
    mail = AnnouncementMailer.announce(players(:ada), 'Hi', '<script>x</script>')

    assert_not_includes mail.html_part.body.to_s, '<script>'
  end
end
