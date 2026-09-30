require 'test_helper'

class PlayerTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate players(:ada), :valid?
  end

  test 'requires a first and last name' do
    player = Player.new

    assert_not player.valid?
    assert_includes player.errors[:first_name], "can't be blank"
    assert_includes player.errors[:last_name], "can't be blank"
  end

  test 'allows more than one player with no email' do
    assert_predicate players(:grace), :valid?
    assert_predicate players(:sam), :valid?
  end

  test 'rejects a duplicate email' do
    player = Player.new(first_name: 'Someone', last_name: 'Else', email: players(:ada).email)

    assert_not player.valid?
    assert_includes player.errors[:email], 'has already been taken'
  end

  test 'normalizes email casing and whitespace' do
    player = Player.new(first_name: 'A', last_name: 'B', email: '  ALT@Example.COM ')

    assert_equal 'alt@example.com', player.email
  end

  test 'full_name joins first and last name' do
    assert_equal 'Ada Testerson', players(:ada).full_name
  end

  test 'initials combine first and last initial' do
    assert_equal 'AT', players(:ada).initials
  end

  test 'normalizes contact_email and phone' do
    player = Player.new(first_name: 'A', last_name: 'B', contact_email: ' Me@Example.COM ', phone: '  ')

    assert_equal 'me@example.com', player.contact_email
    assert_nil player.phone
  end

  test 'rejects a malformed contact_email' do
    player = players(:ada)
    player.contact_email = 'not an email'

    assert_not player.valid?
    assert_predicate player.errors[:contact_email], :any?
  end

  test 'rejects an overlong contact_email and phone' do
    player = players(:ada)
    player.contact_email = "#{'a' * 250}@example.test"
    player.phone = '5' * 41

    assert_not player.valid?
    assert_predicate player.errors[:contact_email], :any?
    assert_predicate player.errors[:phone], :any?
  end

  test 'authenticate_from_google returns nil for an inactive player' do
    auth = OmniAuth::AuthHash.new(
      provider: 'google_oauth2',
      uid: players(:wade).google_uid,
      info: { email: players(:wade).email },
      extra: { raw_info: { email_verified: true } }
    )

    assert_nil Player.authenticate_from_google(auth)
  end

  test 'admins scope returns only admin players' do
    assert_includes Player.admins, players(:zoe)
    assert_not_includes Player.admins, players(:ada)
  end

  test 'locate_by_email! finds a player case-insensitively' do
    assert_equal players(:ada), Player.locate_by_email!(' ADA@Example.TEST ')
  end

  test 'locate_by_email! raises when no player matches' do
    assert_raises(ActiveRecord::RecordNotFound) do
      Player.locate_by_email!('nobody@example.test')
    end
  end

  test 'next_match_night returns the earliest upcoming match night for the player team' do
    assert_equal match_nights(:fall_upcoming), players(:ada).next_match_night(seasons(:fall))
  end

  test 'next_match_night returns nil without a roster spot in the season' do
    assert_nil players(:zoe).next_match_night(seasons(:fall))
  end

  test 'captain_in? is true for a captain in that season' do
    assert players(:ada).captain_in?(seasons(:fall))
  end

  test 'captain_in? is false for a non-captain in that season' do
    assert_not players(:grace).captain_in?(seasons(:fall))
  end

  test 'captain_in? is false once the captain is deactivated' do
    captain = players(:ada)
    captain.update!(status: 'inactive')

    assert_not captain.captain_in?(seasons(:fall))
  end

  test 'captain_of_team? is false once the captain is deactivated' do
    captain = players(:ada)
    team = captain.roster_spots.captains.find_by(season: seasons(:fall)).team_id
    captain.update!(status: 'inactive')

    assert_not captain.captain_of_team?(seasons(:fall), team)
  end

  test 'redeem_magic_link signs in the player once' do
    token = players(:ada).generate_token_for(:magic_link)

    assert_equal players(:ada), Player.redeem_magic_link(token)
    assert_nil Player.redeem_magic_link(token)
  end

  test 'redeem_magic_link refuses an inactive player' do
    assert_nil Player.redeem_magic_link(players(:wade).generate_token_for(:magic_link))
  end

  test 'redeem_magic_link refuses an expired token' do
    token = players(:ada).generate_token_for(:magic_link)

    travel 25.hours do
      assert_nil Player.redeem_magic_link(token)
    end
  end

  test 'redeem_magic_link refuses a garbage token' do
    assert_nil Player.redeem_magic_link('not-a-token')
  end
end
