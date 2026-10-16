# frozen_string_literal: true

class GamesController < ApplicationController
  include ScorecardAccess

  before_action :require_sign_in
  before_action :set_match
  before_action :require_match_captain_or_admin

  def update
    lineup = @match.lineups.find_by!(position: params.expect(:lineup_position))
    lineup.record_game!(number, **game_params)
    render json: { fingerprint: ScorecardForm.new(match: @match).fingerprint, saved_at: Time.current.iso8601 }
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
  end

  private

  def set_match
    @match = Match.includes(:season).find(params.expect(:match_id))
  end

  def number
    params[:number].to_i.tap do |value|
      raise ActiveRecord::RecordNotFound unless (1..Lineup::GAMES_PER_LINEUP).cover?(value)
    end
  end

  def game_params
    params.expect(game: [:home_score, :away_score, { home_player_ids: [], away_player_ids: [] }])
          .to_h.symbolize_keys.reverse_merge(home_player_ids: [], away_player_ids: [])
  end
end
