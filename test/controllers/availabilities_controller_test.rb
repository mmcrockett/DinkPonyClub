require 'test_helper'

class AvailabilitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @match = matches(:fall_future)
    @slot = match_slots(:fall_future_slot_one)
  end

  test 'redirects to root when signed out' do
    patch match_availability_path(@match), params: { playing: '1' }

    assert_redirected_to root_path
  end

  test 'saves playing status and slot preferences when signed in' do
    sign_in_as_ada

    patch match_availability_path(@match), params: {
      playing: '1',
      slot_preferences: { @slot.id.to_s => 'thumbs_up' }
    }

    assert_redirected_to root_path
    availability = @match.match_availabilities.find_by!(player: players(:ada))

    assert_predicate availability, :playing?
    assert_equal 'thumbs_up', @slot.slot_availabilities.find_by!(player: players(:ada)).preference
  end

  test 'does not write once availability has closed' do
    sign_in_as_ada
    @match.match_availabilities.where(player: players(:ada)).destroy_all

    travel_to @match.played_on.in_time_zone.change(hour: 13) do
      patch match_availability_path(@match), params: { playing: '1' }
    end

    assert_redirected_to root_path
    assert_nil @match.match_availabilities.find_by(player: players(:ada))
  end

  test 'ignores a slot id that belongs to a different match' do
    sign_in_as_ada
    other_match_slot = MatchSlot.create!(match: matches(:fall_alpha_bravo), position: 1, starts_at: Time.current)

    patch match_availability_path(@match), params: {
      playing: '1',
      slot_preferences: { other_match_slot.id.to_s => 'thumbs_up' }
    }

    assert_redirected_to root_path
    assert_nil other_match_slot.slot_availabilities.find_by(player: players(:ada))
  end

  private

  def sign_in_as_ada
    mock_google_auth(email: players(:ada).email)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
