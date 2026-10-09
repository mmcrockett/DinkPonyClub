# frozen_string_literal: true

class PlayerRatings
  Rating = Struct.new(:elo, :games) do
    def pupr
      (PUPR_CENTER + ((elo - BASE) / ELO_PER_PUPR)).clamp(2.0, 8.0).round(2)
    end
  end
  Played = Data.define(:home, :away, :home_score, :away_score, :position, :season_id, :game_id)

  BASE = 1500
  LINE_STEP = 170
  K = 24
  PUPR_CENTER = 3.5
  ELO_PER_PUPR = 400.0
  MAX_MARGIN_BONUS = 0.5
  MAX_MARGIN = 11
  DEFAULT_LINES = 4
  PLUCKED = (Game::PLAYER_COLUMNS.map { |column| "games.#{column}" } +
             %w[games.home_score games.away_score lineups.position matches.season_id games.id]).freeze

  include Seeding

  def initialize(season)
    @season = season
  end

  def for(player_id)
    ratings[player_id]
  end

  def elo_change(game_id, player_id)
    ratings
    @changes[[game_id, player_id]]
  end

  private

  def ratings
    @ratings ||= begin
      table = {}
      @changes = {}
      played_games.each { |played| rate(table, played) }
      seed_roster(table)
      table
    end
  end

  def played_games
    cutoff = @season.match_nights.maximum(:played_on) || Date.current

    Game.joins(lineup: { match: :match_night })
        .where(match_nights: { played_on: ..cutoff })
        .order('match_nights.played_on', 'match_nights.id', 'matches.id', 'lineups.position', 'games.number')
        .pluck(*PLUCKED)
        .map { |ids| played_from(ids) }
  end

  def played_from(values)
    Played.new(home: values[0..1], away: values[2..3], home_score: values[4], away_score: values[5],
               position: values[6], season_id: values[7], game_id: values[8])
  end

  def rate(table, played)
    home, away = [played.home, played.away].map { |ids| ids.map { |id| entry(table, id, played) } }
    delta = delta_for(played, home, away)

    home.each { |rating| apply(rating, delta) }
    away.each { |rating| apply(rating, -delta) }
    record_change(played, delta)
  end

  def delta_for(played, home, away)
    K * multiplier(played) * (outcome(played) - expected(home, away))
  end

  def record_change(played, delta)
    played.home.each { |id| @changes[[played.game_id, id]] = delta }
    played.away.each { |id| @changes[[played.game_id, id]] = -delta }
  end

  def apply(rating, delta)
    rating.elo += delta
    rating.games += 1
  end

  def expected(home, away)
    1 / (1 + (10**((average(away) - average(home)) / 400.0)))
  end

  def average(side)
    side.sum(&:elo) / side.size
  end

  def outcome(played)
    played.home_score > played.away_score ? 1.0 : 0.0
  end

  def multiplier(played)
    margin = (played.home_score - played.away_score).abs
    1 + (MAX_MARGIN_BONUS * ((margin - 2).clamp(0, MAX_MARGIN - 2) / (MAX_MARGIN - 2.0)))
  end

  def entry(table, player_id, played)
    table[player_id] ||= begin
      tier = tier_from_rank(draft_ranks[[played.season_id, player_id]]) || played.position
      Rating.new(seed(tier, line_count(played.season_id)), 0)
    end
  end

  def seed_roster(table)
    count = line_count(@season.id)

    @season.roster_spots.each do |spot|
      tier = tier_from_rank(spot.draft_rank)
      table[spot.player_id] ||= Rating.new(seed(tier, count), 0) if tier
    end
  end
end
