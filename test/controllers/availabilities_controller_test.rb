require 'test_helper'

class AvailabilitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @match_night = match_nights(:fall_upcoming)
    @slot = match_slots(:fall_future_slot_one)
  end

  test 'redirects to root when signed out' do
    patch match_night_availability_path(@match_night), params: { match_availability: { status: 'in' } }

    assert_redirected_to root_path
  end

  test 'saves status and slot preferences when signed in' do
    sign_in_as_ada

    patch match_night_availability_path(@match_night), params: {
      match_availability: { status: 'in' },
      slot_preferences: { @slot.id.to_s => 'thumbs_up' }
    }

    assert_redirected_to root_path
    availability = @match_night.match_availabilities.find_by!(player: players(:ada))

    assert_predicate availability, :in?
    assert_equal 'thumbs_up', @slot.slot_availabilities.find_by!(player: players(:ada)).preference
  end

  test 'does not write once availability has closed for a non-captain' do
    sign_in_as(players(:grace))
    @match_night.match_availabilities.where(player: players(:grace)).destroy_all

    travel_to @match_night.played_on.in_time_zone.change(hour: 13) do
      patch match_night_availability_path(@match_night), params: { match_availability: { status: 'in' } }
    end

    assert_redirected_to root_path
    assert_nil @match_night.match_availabilities.find_by(player: players(:grace))
  end

  test 'does not write for a canceled night even for an admin' do
    sign_in_as(players(:zoe))
    night = match_nights(:fall_canceled)

    patch match_night_availability_path(night), params: { match_availability: { status: 'in' } }

    assert_nil night.match_availabilities.find_by(player: players(:zoe))
  end

  test 'a captain can still set their own availability after the cutoff' do
    sign_in_as_ada

    travel_to @match_night.played_on.in_time_zone.change(hour: 13) do
      patch match_night_availability_path(@match_night), params: { match_availability: { status: 'out' } }
    end

    assert_redirected_to root_path
    assert_predicate @match_night.match_availabilities.find_by!(player: players(:ada)), :out?
  end

  test 'rejects an invalid status without saving or flashing success' do
    sign_in_as_ada
    availability = match_availabilities(:fall_future_ada)

    patch match_night_availability_path(@match_night), params: { match_availability: { status: 'nope' } }

    assert_redirected_to root_path
    assert_equal I18n.t('availabilities.update.invalid_status'), flash[:alert]
    assert_predicate availability.reload, :in?
  end

  test 'ignores a slot id that belongs to a different match night' do
    sign_in_as_ada
    other_slot = MatchSlot.create!(match_night: match_nights(:fall_week_one), position: 1, starts_at: Time.current)

    patch match_night_availability_path(@match_night), params: {
      match_availability: { status: 'in' },
      slot_preferences: { other_slot.id.to_s => 'thumbs_up' }
    }

    assert_redirected_to root_path
    assert_nil other_slot.slot_availabilities.find_by(player: players(:ada))
  end

  test 'a captain can set a teammate after the cutoff' do
    sign_in_as_ada

    travel_to @match_night.played_on.in_time_zone.change(hour: 13) do
      patch match_night_player_availability_path(@match_night, players(:grace)),
            params: { match_availability: { status: 'out' } }
    end

    assert_redirected_to root_path
    assert_predicate @match_night.match_availabilities.find_by!(player: players(:grace)), :out?
  end

  test 'a captain cannot set a player on another team' do
    sign_in_as_ada

    patch match_night_player_availability_path(@match_night, players(:sam)),
          params: { match_availability: { status: 'out' } }

    assert_redirected_to root_path
    assert_equal I18n.t('authentication.require_captain_or_admin'), flash[:alert]
    assert_nil @match_night.match_availabilities.find_by(player: players(:sam))
  end

  test 'an admin can set any rostered player' do
    sign_in_as(players(:zoe))

    patch match_night_player_availability_path(@match_night, players(:sam)),
          params: { match_availability: { status: 'in' } }

    assert_redirected_to root_path
    assert_predicate @match_night.match_availabilities.find_by!(player: players(:sam)), :in?
  end

  test 'a non-captain cannot set another player' do
    sign_in_as(players(:grace))

    patch match_night_player_availability_path(@match_night, players(:sam)),
          params: { match_availability: { status: 'in' } }

    assert_redirected_to root_path
    assert_nil @match_night.match_availabilities.find_by(player: players(:sam))
  end

  test 'refuses a player with no roster spot in the season' do
    sign_in_as_ada

    patch match_night_player_availability_path(@match_night, players(:wade)),
          params: { match_availability: { status: 'in' } }

    assert_redirected_to root_path
    assert_equal I18n.t('availabilities.update_for_player.not_on_roster'), flash[:alert]
  end

  test 'an admin cannot change team availability on past dates' do
    sign_in_as(players(:zoe))
    availability = match_availabilities(:fall_future_ada)

    travel_to @match_night.played_on.in_time_zone + 1.day do
      patch match_night_player_availability_path(@match_night, players(:ada)),
            params: { match_availability: { status: 'out' } }
    end

    assert_predicate availability.reload, :in?
    assert_equal I18n.t('availabilities.update.closed'), flash[:alert]
  end

  test 'a captain cannot change team availability on a canceled night' do
    sign_in_as_ada
    @match_night.update!(canceled: true)

    patch match_night_player_availability_path(@match_night, players(:grace)),
          params: { match_availability: { status: 'in' } }

    assert_equal I18n.t('availabilities.update.closed'), flash[:alert]
    assert_predicate @match_night.match_availabilities.find_by!(player: players(:grace)), :out?
  end

  test 'a captain cannot change their own availability on a past night' do
    sign_in_as_ada
    availability = match_availabilities(:fall_future_ada)

    travel_to @match_night.played_on.in_time_zone + 1.day do
      patch match_night_availability_path(@match_night), params: { match_availability: { status: 'out' } }
    end

    assert_predicate availability.reload, :in?
    assert_equal I18n.t('availabilities.update.closed'), flash[:alert]
  end

  private

  def sign_in_as_ada
    sign_in_as(players(:ada))
  end

  def sign_in_as(player)
    mock_google_auth(email: player.email)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
