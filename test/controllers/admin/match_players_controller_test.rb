require 'test_helper'

module Admin
  class MatchPlayersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @match = matches(:scorecard_match)
      travel_to @match.played_on.in_time_zone.change(hour: 20)
      ScorecardForm.new(match: @match, lines: scored_lines).save
    end

    test 'redirects a captain and a signed-out visitor' do
      get edit_admin_match_players_path(@match)

      assert_redirected_to root_path

      sign_in_as players(:sc_home_captain)
      get edit_admin_match_players_path(@match)

      assert_redirected_to root_path
    end

    test 'redirects to the match when nothing is scored' do
      @match.lineups.destroy_all
      sign_in_as players(:zoe)

      get edit_admin_match_players_path(@match)

      assert_redirected_to match_path(@match)
    end

    test 'renders the seat selects for an admin' do
      sign_in_as players(:zoe)

      get edit_admin_match_players_path(@match)

      assert_response :success
      assert_select 'select[name="lines[1][away_player_ids][]"]', count: 3
    end

    test 'swaps a player and keeps the scores' do
      sign_in_as players(:zoe)

      patch admin_match_players_path(@match), params: { lines: swapped_lines }

      assert_redirected_to match_path(@match)
      game = @match.reload.lineups.find_by(position: 1).games.find_by(number: 1)

      assert_equal [11, 4], [game.home_score, game.away_score]
      assert_includes game.away_player_ids, players(:sc_away_player2).id
      assert_not_includes game.away_player_ids, players(:sc_away_player1).id
    end

    test 'rebuilds the picks for the swapped player' do
      sign_in_as players(:zoe)

      patch admin_match_players_path(@match), params: { lines: swapped_lines }

      assert_includes @match.lineup_picks.where(team: @match.away_team).pluck(:player_id), players(:sc_away_player2).id
    end

    test 'rejects an invalid line and changes nothing' do
      sign_in_as players(:zoe)
      lines = swapped_lines.merge('1' => { home_player_ids: [players(:sc_home_captain).id], away_player_ids: [] })

      patch admin_match_players_path(@match), params: { lines: lines }

      assert_response :unprocessable_content
      assert_away_player_unchanged
    end

    test 'rejects a stale fingerprint' do
      sign_in_as players(:zoe)

      patch admin_match_players_path(@match), params: { lines: swapped_lines, fingerprint: 'old' }

      assert_redirected_to edit_admin_match_players_path(@match)
      assert_away_player_unchanged
    end

    private

    def assert_away_player_unchanged
      game = @match.reload.lineups.find_by(position: 1).games.first

      assert_includes game.away_player_ids, players(:sc_away_player1).id
    end

    def scored_lines
      (1..5).to_h do |position|
        [position.to_s, { home_player_ids: [players(:sc_home_captain).id.to_s, players(:sc_home_player1).id.to_s],
                          away_player_ids: [players(:sc_away_captain).id.to_s, players(:sc_away_player1).id.to_s],
                          home_score1: '11', away_score1: '4' }]
      end
    end

    def swapped_lines
      (1..5).to_h do |position|
        [position.to_s, { home_player_ids: [players(:sc_home_captain).id.to_s, players(:sc_home_player1).id.to_s],
                          away_player_ids: [players(:sc_away_captain).id.to_s, players(:sc_away_player2).id.to_s] }]
      end
    end
  end
end
