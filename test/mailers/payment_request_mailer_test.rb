require 'test_helper'

class PaymentRequestMailerTest < ActionMailer::TestCase
  setup do
    @original_username = Rails.configuration.x.venmo_username
    Rails.configuration.x.venmo_username = 'harrison-p'
    charges(:ada_league_fee).update!(amount_cents: 2600, paid_cents: 0)
    charges(:ada_league_fee).roster_spot.charges.create!(fee: fees(:fall_hat), amount_cents: 1000)
  end

  teardown { Rails.configuration.x.venmo_username = @original_username }

  test 'itemizes unpaid fees and totals them' do
    mail = PaymentRequestMailer.request_payment(players(:ada), seasons(:fall))

    assert_equal [players(:ada).email], mail.to
    assert_equal "Dink Pony Club - you owe $36.00 for #{seasons(:fall).name}", mail.subject
    assert_includes mail.text_part.body.to_s, 'League fee: $26.00'
    assert_includes mail.text_part.body.to_s, 'Hat: $10.00'
    assert_includes mail.text_part.body.to_s, 'Total: $36.00'
  end

  test 'links to venmo with the amount and an itemized note' do
    mail = PaymentRequestMailer.request_payment(players(:ada), seasons(:fall))
    url = 'https://venmo.com/harrison-p?txn=pay&amount=36.00&note=DinkPonyClub%20league%20fee%20and%20hat'

    assert_includes mail.text_part.body.to_s, url
    assert_includes mail.html_part.body.to_s, 'Pay $36.00 with Venmo'
  end

  test 'lists only the remaining balance after a partial payment' do
    charges(:ada_league_fee).update!(paid_cents: 1000)

    mail = PaymentRequestMailer.request_payment(players(:ada), seasons(:fall))

    assert_includes mail.text_part.body.to_s, 'League fee: $16.00'
    assert_includes mail.text_part.body.to_s, 'Total: $26.00'
  end

  test 'sends nothing when the balance is cleared before delivery' do
    charges(:ada_league_fee).update!(paid_cents: 2600)
    charges(:ada_league_fee).roster_spot.charges.find_by!(fee: fees(:fall_hat)).update!(paid_cents: 1000)

    assert_no_emails do
      PaymentRequestMailer.request_payment(players(:ada), seasons(:fall)).deliver_now
    end
  end

  test 'omits the venmo link when no username is configured' do
    Rails.configuration.x.venmo_username = nil

    mail = PaymentRequestMailer.request_payment(players(:ada), seasons(:fall))

    assert_not_includes mail.text_part.body.to_s, 'venmo'
  end
end
