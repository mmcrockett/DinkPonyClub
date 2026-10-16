# frozen_string_literal: true

class GamesController < ApplicationController
  include ScorecardAccess

  before_action :require_sign_in
  before_action :set_match
  before_action :require_match_captain_or_admin
  before_action :reject_stale
  before_action :reject_invalid

  def update
    lineup.record_game!(number, **game_params)
    render json: { fingerprint: form.fingerprint, saved_at: Time.current.iso8601 }
  rescue ActiveRecord::RecordInvalid => e
    render_errors(e.record.errors.full_messages)
  end

  private

  def set_match
    @match = Match.includes(:season).find(params.expect(:match_id))
  end

  def form
    @form ||= ScorecardForm.new(match: @match)
  end

  def reject_stale
    return unless params[:fingerprint].present? && params[:fingerprint] != form.fingerprint

    render_errors([t('matches.stale')], :conflict)
  end

  def reject_invalid
    line = ScorecardForm::Line.new(form, position, line_attrs)
    render_errors(line.errors.full_messages) unless line.valid?
  end

  def render_errors(messages, status = :unprocessable_content)
    render json: { errors: messages }, status: status
  end

  def lineup
    @match.lineups.find_by!(position: position)
  end

  def position
    params.expect(:lineup_position).to_i
  end

  def number
    params[:number].to_i.tap do |value|
      raise ActiveRecord::RecordNotFound unless (1..Lineup::GAMES_PER_LINEUP).cover?(value)
    end
  end

  def line_attrs
    scores = { "home_score#{number}" => game_params[:home_score], "away_score#{number}" => game_params[:away_score] }
    game_params.slice(:home_player_ids, :away_player_ids).merge(scores)
  end

  def game_params
    @game_params ||= params.expect(game: [:home_score, :away_score, { home_player_ids: [], away_player_ids: [] }])
                           .to_h.symbolize_keys.reverse_merge(home_player_ids: [], away_player_ids: [])
  end
end
