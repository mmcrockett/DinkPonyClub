require 'test_helper'

class StandingsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  test 'redirects to root when signed out' do
    get standings_path

    assert_redirected_to root_path
  end

  test 'ranks teams by wins then point differential' do
    sign_in_as_ada

    get standings_path

    assert_response :success
    assert_operator response.body.index(dom_id(teams(:alpha), :standings)),
                    :<, response.body.index(dom_id(teams(:bravo), :standings))
  end

  test 'shows the leader on the first podium card' do
    sign_in_as_ada

    get standings_path

    assert_select "##{dom_id(teams(:alpha), :podium)}", text: /Leading the pack/i
    assert_select "##{dom_id(teams(:alpha), :podium)}", text: /1-0/
  end

  test 'counts posted results' do
    sign_in_as_ada

    get standings_path

    assert_select 'span', text: '1 result posted'
  end

  test 'excludes playoff results' do
    complete_playoff_match
    sign_in_as_ada

    get standings_path

    assert_select 'span', text: '1 result posted'
    assert_select "##{dom_id(teams(:alpha), :podium)}", text: /1-0/
  end

  test 'footnote reports the season sweep bonus' do
    sign_in_as_ada

    get standings_path

    assert_select 'p', text: /a three-game line sweep adds 0.5/
  end

  test 'scopes the table to the requested season' do
    sign_in_as_ada

    get standings_path(season: seasons(:spring).id)

    assert_response :success
    assert_select "##{dom_id(teams(:alpha), :standings)}", count: 1
    assert_select "##{dom_id(teams(:bravo), :standings)}", count: 0
    assert_select 'span', text: '0 results posted'
  end

  private

  def complete_playoff_match
    night = MatchNight.create!(season: seasons(:fall), played_on: Date.new(2026, 10, 1),
                               label: 'Final', playoff: true)
    match = Match.create!(season: seasons(:fall), match_night: night,
                          home_team: teams(:bravo), away_team: teams(:alpha))
    sweep!(match.lineups.create!(position: 1))
  end

  def sweep!(lineup)
    3.times do |index|
      lineup.games.create!(number: index + 1, home_score: 11, away_score: 4,
                           home_player_a: players(:sam), home_player_b: players(:ben),
                           away_player_a: players(:ada), away_player_b: players(:grace))
    end
  end

  def sign_in_as_ada
    sign_in_as(players(:ada))
  end

  def sign_in_as(player)
    mock_google_auth(email: player.email)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
