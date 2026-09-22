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
end
