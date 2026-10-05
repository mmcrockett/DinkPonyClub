# frozen_string_literal: true

class LineupPlansController < ApplicationController
  before_action :require_sign_in
  before_action :set_match_and_team
  before_action :require_team_captain_or_admin
  before_action :require_unlocked

  def edit
    @form = LineupPlanForm.from_match(@match, @team)
    load_availability
  end

  def update
    @form = LineupPlanForm.new(match: @match, team: @team, lines: lines_params)
    if @form.save
      redirect_to edit_match_team_lineup_path(@match, @team), notice: t('.saved')
    else
      load_availability
      render :edit, status: :unprocessable_content
    end
  end

  private

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

  def load_availability
    night = @match.match_night
    @slots = night.match_slots.ordered.to_a
    everyone = @form.roster + @form.eligible_subs
    @statuses = night.match_availabilities.where(player: everyone).to_h { |row| [row.player_id, row.status] }
    @slot_preferences = slot_preferences_by_player
  end

  def slot_preferences_by_player
    rows = SlotAvailability.where(match_slot: @slots, player: @form.roster + @form.subs).group_by(&:player_id)
    rows.transform_values { |list| list.to_h { |row| [row.match_slot_id, row.preference] } }
  end

  # filter is dynamic per line position; params.expect can't describe that shape.
  def lines_params
    filter = @match.line_positions.to_h { |position| [position.to_s, []] }
    params.fetch(:lineup, {}).permit(lines: filter).fetch(:lines, {})
  end
end
