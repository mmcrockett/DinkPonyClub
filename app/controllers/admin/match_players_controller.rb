# frozen_string_literal: true

module Admin
  class MatchPlayersController < ApplicationController
    before_action :require_admin
    before_action :set_match
    before_action :require_scored

    def edit
      @form = ScorecardForm.from_match(@match)
      load_choices
    end

    def update
      @form = ScorecardForm.new(match: @match, lines: lines_attrs)
      return redirect_to(edit_admin_match_players_path(@match), alert: t('matches.stale')) if stale?

      if @form.save
        redirect_to match_path(@match), notice: t('.saved')
      else
        load_choices
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_match
      @match = Match.includes(:season, :home_team, :away_team).find(params.expect(:match_id))
    end

    def require_scored
      redirect_to match_path(@match), alert: t('admin.match_players.unscored') unless @match.lineups.any?
    end

    def stale?
      params[:fingerprint].present? && params[:fingerprint] != @form.fingerprint
    end

    def lines_attrs
      submitted = submitted_players
      ScorecardForm.from_match(@match).lines.to_h do |line|
        [line.position, score_attrs(line).merge(submitted.fetch(line.position.to_s, {}).to_h.symbolize_keys)]
      end
    end

    def submitted_players
      filter = @match.line_positions.to_h { |position| [position.to_s, [{ home_player_ids: [], away_player_ids: [] }]] }
      params.fetch(:lines, {}).permit(filter)
    end

    def score_attrs(line)
      line.scores.each_with_index.with_object({}) do |((home, away), index), attrs|
        attrs[:"home_score#{index + 1}"] = home
        attrs[:"away_score#{index + 1}"] = away
      end
    end

    def load_choices
      on_lines = @form.lines.flat_map(&:all_player_ids)
      everyone = Player.active.or(Player.where(id: on_lines)).by_name.to_a
      @players_by_id = everyone.index_by { |player| player.id.to_s }
      @choices = { home: choices_for(@match.home_team, everyone), away: choices_for(@match.away_team, everyone) }
    end

    def choices_for(team, everyone)
      roster = team.roster_for(@match.season).to_a
      [[t('admin.match_players.edit.roster'), options(roster)],
       [t('admin.match_players.edit.others'), options(everyone - roster)]]
    end

    def options(players)
      players.map { |player| [player.full_name, player.id.to_s] }
    end
  end
end
