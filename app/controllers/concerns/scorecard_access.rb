# frozen_string_literal: true

module ScorecardAccess
  private

  def require_match_captain_or_admin
    return if can_edit_scorecard?(@match)

    alert_key = captain_or_admin?(@match.season) ? 'matches.locked' : 'matches.forbidden'
    respond_to do |format|
      format.html { redirect_to match_path(@match), alert: t(alert_key) }
      format.json { render json: { errors: [t(alert_key)] }, status: :forbidden }
    end
  end
end
