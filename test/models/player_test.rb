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
end
