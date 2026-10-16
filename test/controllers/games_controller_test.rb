require 'test_helper'

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @match = matches(:scorecard_match)
    travel_to @match.played_on.in_time_zone.change(hour: 20)
    ScorecardForm.new(match: @match, lines: seated_lines).save
    @home = [players(:sc_home_captain), players(:sc_home_player1)]
    @away = [players(:sc_away_captain), players(:sc_away_player1)]
  end

  test 'records a game for a line and returns the new fingerprint' do
    sign_in_as players(:sc_home_captain)

    patch game_path(1, 1), params: score_params('11', '4')

    assert_response :success
    assert_equal ScorecardForm.new(match: @match).fingerprint, response.parsed_body['fingerprint']
    game = @match.lineups.find_by(position: 1).games.find_by(number: 1)

    assert_equal [11, 4], [game.home_score, game.away_score]
  end

  test 'updates an existing game in place' do
    sign_in_as players(:sc_home_captain)
    patch game_path(1, 1), params: score_params('11', '4')
    game = @match.lineups.find_by(position: 1).games.find_by(number: 1)

    patch game_path(1, 1), params: score_params('11', '9')

    updated = @match.lineups.find_by(position: 1).games.find_by(number: 1)

    assert_equal [game.id, 9], [updated.id, updated.away_score]
  end

  test 'blank scores remove the game' do
    sign_in_as players(:sc_home_captain)
    patch game_path(1, 1), params: score_params('11', '4')

    patch game_path(1, 1), params: score_params('', '')

    assert_response :success
    assert_equal 0, @match.lineups.find_by(position: 1).games.count
  end

  test 'rejects a tie with the game errors' do
    sign_in_as players(:sc_home_captain)

    patch game_path(1, 1), params: score_params('11', '11')

    assert_response :unprocessable_content
    assert_predicate response.parsed_body['errors'], :any?
  end

  test 'a non-captain is forbidden' do
    sign_in_as players(:sc_home_player1)

    patch game_path(1, 1), params: score_params('11', '4')

    assert_response :forbidden
  end

  test 'an unknown line or game number is not found' do
    sign_in_as players(:sc_home_captain)

    patch game_path(9, 1), params: score_params('11', '4')

    assert_response :not_found

    patch game_path(1, 4), params: score_params('11', '4')

    assert_response :not_found
  end

  private

  def game_path(line, number)
    match_lineup_game_path(@match, line, number, format: :json)
  end

  def score_params(home, away)
    { game: { home_score: home, away_score: away,
              home_player_ids: @home.map { |p| p.id.to_s }, away_player_ids: @away.map { |p| p.id.to_s } } }
  end

  def seated_lines
    (1..5).to_h do |position|
      [position.to_s, { home_player_ids: [players(:sc_home_captain).id.to_s, players(:sc_home_player1).id.to_s],
                        away_player_ids: [players(:sc_away_captain).id.to_s, players(:sc_away_player1).id.to_s] }]
    end
  end

  def sign_in_as(player)
    mock_google_auth(email: player.email, uid: player.google_uid)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
