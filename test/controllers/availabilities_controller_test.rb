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

  test 'does not write once availability has closed' do
    sign_in_as_ada
    @match_night.match_availabilities.where(player: players(:ada)).destroy_all

    travel_to @match_night.played_on.in_time_zone.change(hour: 13) do
      patch match_night_availability_path(@match_night), params: { match_availability: { status: 'in' } }
    end

    assert_redirected_to root_path
    assert_nil @match_night.match_availabilities.find_by(player: players(:ada))
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

  private

  def sign_in_as_ada
    mock_google_auth(email: players(:ada).email)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
