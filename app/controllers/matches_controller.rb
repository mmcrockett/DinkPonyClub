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
    if @form.save
      redirect_to match_path(@match), notice: t('.saved')
    else
      load_rosters
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_match
    @match = Match.find(params.expect(:id))
  end

  def load_form_and_rosters
    @form = ScorecardForm.from_match(@match)
    load_rosters
  end

  def load_rosters
    @home_roster = @match.home_team.roster_for(@match.season)
    @away_roster = @match.away_team.roster_for(@match.season)
    @players_by_id = Player.where(id: @home_roster + @away_roster).index_by { |player| player.id.to_s }
  end

  def require_match_captain_or_admin
    return if admin? || @match.captained_by?(current_player)

    redirect_to match_path(@match), alert: t('matches.forbidden')
  end

  # filter is dynamic per line position; params.expect can't describe that shape.
  def lines_params
    filter = ScorecardForm::POSITIONS.to_h { |position| [position.to_s, LINE_KEYS] }
    params.require(:scorecard).permit(lines: filter).fetch(:lines, {}) # rubocop:disable Rails/StrongParametersExpect
  end
end
