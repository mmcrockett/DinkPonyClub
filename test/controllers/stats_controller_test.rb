require 'test_helper'

class StatsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    @substitute = Player.create!(first_name: 'Sub', last_name: 'Stitute')
    @bench = Player.create!(first_name: 'Bench', last_name: 'Warmer')
    RosterSpot.create!(season: seasons(:fall), team: teams(:bravo), player: @bench)
    add_sub_line
  end

  test 'redirects to root when signed out' do
    get stats_path

    assert_redirected_to root_path
  end

  test 'lists rostered players and substitutes' do
    sign_in_as(players(:ada))

    get stats_path

    assert_response :success
    %i[ada grace sam ben].each { |name| assert_select "##{dom_id(players(name), :stats)}" }
    assert_select "##{dom_id(@substitute, :stats)}", text: /Substitute/
  end

  test 'shows a dash for a player with no games' do
    sign_in_as(players(:ada))

    get stats_path

    assert_select "##{dom_id(@bench, :stats)} td", text: '-'
  end

  test 'shows win pct, sweep bonus and points' do
    sign_in_as(players(:ada))

    get stats_path

    assert_select "##{dom_id(@substitute, :stats)}" do
      assert_select 'td', text: '100%'
      assert_select 'td', text: '0.5'
      assert_select 'td', text: '3.5'
    end
  end

  test 'searches by name' do
    sign_in_as(players(:ada))

    get stats_path(q: 'grace')

    assert_select 'tbody tr', count: 1
    assert_select "##{dom_id(players(:grace), :stats)}"
  end

  test 'filters by team' do
    sign_in_as(players(:ada))

    get stats_path(team: teams(:bravo).id)

    assert_equal [players(:ben), @bench, players(:sam)].map { |p| dom_id(p, :stats) }.sort, row_ids.sort
  end

  test 'filters to substitutes' do
    sign_in_as(players(:ada))

    get stats_path(team: 'substitutes')

    assert_equal [dom_id(@substitute, :stats)], row_ids
  end

  test 'hides substitutes' do
    sign_in_as(players(:ada))

    get stats_path(hide_substitutes: '1')

    assert_select "##{dom_id(@substitute, :stats)}", count: 0
    assert_select "##{dom_id(players(:ada), :stats)}"
  end

  test 'shows a message when filters match nobody' do
    sign_in_as(players(:ada))

    get stats_path(q: 'nobody')

    assert_select 'table', count: 0
    assert_select 'p', text: 'No players match these filters.'
  end

  test 'sorts by name by default' do
    sign_in_as(players(:ada))

    get stats_path

    assert_equal ids(players(:ada), players(:ben), @bench, players(:grace), players(:sam), @substitute), row_ids
  end

  test 'sorts by win pct descending with zero-game players last' do
    sign_in_as(players(:ada))

    get stats_path(sort: 'win_pct_desc')

    assert_equal ids(@substitute, players(:ben), players(:ada), players(:grace), players(:sam), @bench), row_ids
  end

  test 'sorts by win pct ascending with zero-game players last' do
    sign_in_as(players(:ada))

    get stats_path(sort: 'win_pct_asc')

    assert_equal ids(players(:ada), players(:grace), players(:sam), players(:ben), @substitute, @bench), row_ids
  end

  test 'sorts by team with substitutes last' do
    sign_in_as(players(:ada))

    get stats_path(sort: 'team')

    assert_equal ids(players(:ada), players(:grace), players(:ben), @bench, players(:sam), @substitute), row_ids
  end

  test 'scopes to the requested season' do
    sign_in_as(players(:ada))

    get stats_path(season: seasons(:spring).id)

    assert_equal ids(players(:ada)), row_ids
  end

  test 'shows an empty state for a season with no roster' do
    season = Season.create!(name: 'Winter 2027', starts_on: Date.new(2027, 1, 4))
    sign_in_as(players(:ada))

    get stats_path(season: season.id)

    assert_response :success
    assert_select 'p', text: 'No players are rostered for this season yet.'
  end

  test 'sidebar links to stats' do
    sign_in_as(players(:ada))

    get stats_path

    assert_select "a[href='#{stats_path}']", text: /Stats/
  end

  private

  def add_sub_line
    match = Match.create!(season: seasons(:fall), match_night: match_nights(:fall_week_one),
                          home_team: teams(:bravo), away_team: teams(:alpha))
    lineup = match.lineups.create!(position: 2)
    3.times do |index|
      lineup.games.create!(number: index + 1, home_score: 11, away_score: 3,
                           home_player_a: @substitute, home_player_b: players(:ben),
                           away_player_a: players(:grace), away_player_b: players(:ada))
    end
  end

  def ids(*players)
    players.map { |player| dom_id(player, :stats) }
  end

  def row_ids
    css_select('tbody tr').pluck('id')
  end

  def sign_in_as(player)
    mock_google_auth(email: player.email)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
