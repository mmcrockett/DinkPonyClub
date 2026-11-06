require 'test_helper'

module League
  class PlayoffBracketTest < ActiveSupport::TestCase
    setup do
      @setup = build_playoff_season
      @service = PlayoffBracket.new(@setup.night)
    end

    test 'seeds one v four and two v three with the higher seed at home' do
      @service.seed!

      pairs = @setup.night.matches.order(:id).map { |match| [match.home_team, match.away_team] }

      assert_equal [[@setup.teams[0], @setup.teams[3]], [@setup.teams[1], @setup.teams[2]]], pairs
      assert_equal %w[semifinal semifinal], @setup.night.matches.map(&:round)
    end

    test 'refuses to seed a night that is not a playoff night' do
      @setup.night.update!(playoff: false)

      assert_raises(PlayoffBracket::Error) { @service.seed! }
    end

    test 'refuses to seed a night that already has matches' do
      @service.seed!

      assert_raises(PlayoffBracket::Error) { @service.seed! }
    end

    test 'refuses to seed without exactly four teams' do
      @setup.season.matches.destroy_all
      RosterSpot.where(team: @setup.teams.last).destroy_all

      assert_raises(PlayoffBracket::Error) { @service.seed! }
    end

    test 'creates the final from the semifinal winners' do
      @service.seed!
      first, second = @setup.night.matches.order(:id).to_a
      score_match!(first, @setup.players, sweep(5, 11))
      score_match!(second, @setup.players, sweep(11, 5))

      final = @service.create_final!

      assert_predicate final, :final?
      assert_equal [@setup.teams[3], @setup.teams[1]], [final.home_team, final.away_team]
    end

    test 'copies each winner lineup picks from its semifinal into the final' do
      @service.seed!
      first, second = @setup.night.matches.order(:id).to_a
      winner_players = @setup.players[@setup.teams[3]]
      first.lineup_picks.create!(team: @setup.teams[3], player: winner_players[0], position: 1, seat: 1)
      first.lineup_picks.create!(team: @setup.teams[3], player: winner_players[1], position: 1, seat: 2)
      score_match!(first, @setup.players, sweep(5, 11))
      score_match!(second, @setup.players, sweep(11, 5))

      final = @service.create_final!

      assert_equal winner_players.map(&:id), final.lineup_picks.where(team: @setup.teams[3]).ordered.pluck(:player_id)
    end

    test 'refuses to create the final before both semifinals are complete' do
      @service.seed!

      assert_raises(PlayoffBracket::Error) { @service.create_final! }
    end
  end
end
