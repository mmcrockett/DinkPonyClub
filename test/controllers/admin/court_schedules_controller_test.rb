require 'test_helper'

module Admin
  class CourtSchedulesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @night = match_nights(:fall_upcoming)
      @match = matches(:fall_future)
      @slot = match_slots(:fall_future_slot_two)
    end

    test 'redirects a non-admin and changes nothing' do
      sign_in_as players(:ada)

      assert_no_difference 'CourtAssignment.count' do
        patch admin_match_night_court_schedule_path(@night),
              params: { cells: { @slot.id => { 1 => "#{@match.id}-2" } } }
      end
      assert_redirected_to root_path
    end

    test 'saves the grid and redirects back to the night' do
      sign_in_as players(:zoe)

      patch admin_match_night_court_schedule_path(@night),
            params: { cells: { @slot.id => { 3 => "#{@match.id}-2" } } }

      assert_redirected_to edit_admin_match_night_path(@night)
      assert_equal [[@slot.id, 3, 2]], @night.court_assignments.pluck(:match_slot_id, :court, :position)
    end

    test 'alerts on a line placed twice and keeps the schedule' do
      sign_in_as players(:zoe)

      assert_no_difference 'CourtAssignment.count' do
        patch admin_match_night_court_schedule_path(@night),
              params: { cells: { @slot.id => { 1 => "#{@match.id}-2", 2 => "#{@match.id}-2" } } }
      end
      assert_predicate flash[:alert], :present?
    end

    test 'refuses a canceled night' do
      sign_in_as players(:zoe)

      assert_no_difference 'CourtAssignment.count' do
        patch admin_match_night_court_schedule_path(match_nights(:fall_canceled)), params: { cells: {} }
      end
      assert_predicate flash[:alert], :present?
    end

    test 'the night edit page shows the grid' do
      sign_in_as players(:zoe)

      get edit_admin_match_night_path(@night)

      assert_response :success
      assert_select 'select[name=?]', "cells[#{@slot.id}][1]"
    end
  end
end
