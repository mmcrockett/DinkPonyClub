# frozen_string_literal: true

class LineupPlansController < ApplicationController
  before_action :require_sign_in
  before_action :set_match_and_team
  before_action :require_team_captain_or_admin
  before_action :require_unlocked

  def subs
    board = MatchupBoard.new(@match, @team)
    render partial: 'matchups/sub_sources', locals: { rows: board.sub_options, slots: board.slots }
  end

  def odds
    form = LineupPlanForm.new(match: @match, team: @team, lines: lines_params)
    render json: form.valid? ? odds_payload(form.lines) : {}
  end

  def update
    form = LineupPlanForm.new(match: @match, team: @team, lines: lines_params)
    if form.save
      redirect_to return_path, notice: t('.saved')
    else
      redirect_to return_path, alert: form.errors.full_messages.to_sentence
    end
  end

  private

  def odds_payload(lines)
    odds = MatchupBoard.new(@match, @team).odds(lines)
    (odds.moneylines || {}).merge(lines: odds.line_moneylines)
  end

  def return_path
    url_from(params[:return_to]) || season_matchup_path(@match.season_id, team_id: @team.id, match_id: @match.id)
  end

  def set_match_and_team
    @match = Match.find(params.expect(:match_id))
    @team = [@match.home_team, @match.away_team].find { |team| team.id == params[:team_id].to_i }
    raise ActiveRecord::RecordNotFound unless @team
  end

  def require_team_captain_or_admin
    return if admin? || current_player.captain_of_team?(@match.season, @team.id)

    redirect_to match_path(@match), alert: t('lineup_plans.forbidden')
  end

  def require_unlocked
    return unless @match.match_night.canceled? || @match.lineups.exists?

    redirect_to match_path(@match), alert: t('lineup_plans.locked')
  end

  # filter is dynamic per line position; params.expect can't describe that shape.
  def lines_params
    filter = @match.line_positions.to_h { |position| [position.to_s, []] }
    params.fetch(:lineup, {}).permit(lines: filter).fetch(:lines, {})
  end
end
