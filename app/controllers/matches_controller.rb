# frozen_string_literal: true

class MatchesController < ApplicationController
  LINE_KEYS = ((1..Lineup::GAMES_PER_LINEUP).flat_map { |n| [:"home_score#{n}", :"away_score#{n}"] } +
               [{ home_player_ids: [], away_player_ids: [] }]).freeze

  before_action :require_sign_in
  before_action :set_match
  before_action :require_match_captain_or_admin, only: %i[edit update]

  def show
    load_form_and_rosters
  end

  def edit
    load_form_and_rosters
  end

  def update
    @form = ScorecardForm.new(match: @match, lines: lines_params)
    return render_stale if stale?

    if @form.save
      render_saved
    else
      render_invalid
    end
  end

  private

  def stale?
    params[:fingerprint].present? && params[:fingerprint] != @form.fingerprint
  end

  def render_saved
    respond_to do |format|
      format.html { redirect_to match_path(@match), notice: t('matches.update.saved') }
      format.json { render json: { fingerprint: @form.fingerprint, saved_at: Time.current.iso8601 } }
    end
  end

  def render_invalid
    respond_to do |format|
      format.html do
        load_rosters
        render :edit, status: :unprocessable_content
      end
      format.json { render json: { errors: @form.errors.full_messages }, status: :unprocessable_content }
    end
  end

  def render_stale
    respond_to do |format|
      format.html { redirect_to edit_match_path(@match), alert: t('matches.stale') }
      format.json { render json: { errors: [t('matches.stale')] }, status: :conflict }
    end
  end

  def set_match
    scope = action_name == 'update' ? Match : Match.includes(:season, :home_team, :away_team, lineups: :games)
    @match = scope.find(params.expect(:id))
  end

  def load_form_and_rosters
    @form = ScorecardForm.from_match(@match)
    load_rosters
  end

  def load_rosters
    @home_roster = side_players(@match.home_team, :home_player_ids)
    @away_roster = side_players(@match.away_team, :away_player_ids)
    @players_by_id = (@home_roster + @away_roster).index_by { |player| player.id.to_s }
  end

  def side_players(team, ids_method)
    roster = team.roster_for(@match.season).to_a
    extra_ids = @form.lines.flat_map(&ids_method) - roster.map { |player| player.id.to_s }
    roster + Player.where(id: extra_ids).by_name.to_a
  end

  def require_match_captain_or_admin
    return if can_edit_scorecard?(@match)

    alert_key = captain_or_admin?(@match.season) ? 'matches.locked' : 'matches.forbidden'
    respond_to do |format|
      format.html { redirect_to match_path(@match), alert: t(alert_key) }
      format.json { render json: { errors: [t(alert_key)] }, status: :forbidden }
    end
  end

  # filter is dynamic per line position; params.expect can't describe that shape.
  def lines_params
    filter = @match.line_positions.to_h { |position| [position.to_s, LINE_KEYS] }
    params.require(:scorecard).permit(lines: filter).fetch(:lines, {}) # rubocop:disable Rails/StrongParametersExpect
  end
end
