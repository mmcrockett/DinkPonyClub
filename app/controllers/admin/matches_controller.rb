# frozen_string_literal: true

module Admin
  class MatchesController < ApplicationController
    before_action :require_admin
    before_action :set_match_night
    before_action :reject_canceled_night, only: %i[create update]
    before_action :reject_played_night

    def create
      match = @match_night.matches.new(season: @match_night.season, **match_params)

      if match.save
        redirect_back_to_schedule notice: t('.created', matchup: matchup(match), label: @match_night.label)
      else
        redirect_back_to_schedule alert: t('admin.matches.invalid', errors: match.errors.full_messages.to_sentence)
      end
    end

    def update
      match = @match_night.matches.find(params.expect(:id))

      if match.update(match_params)
        redirect_back_to_schedule notice: t('.updated', matchup: matchup(match), label: @match_night.label)
      else
        redirect_back_to_schedule alert: t('admin.matches.invalid', errors: match.errors.full_messages.to_sentence)
      end
    end

    def destroy
      match = @match_night.matches.find(params.expect(:id))
      match.destroy!

      redirect_back_to_schedule notice: t('.removed', matchup: matchup(match), label: @match_night.label)
    end

    private

    def set_match_night
      @match_night = MatchNight.find(params.expect(:match_night_id))
    end

    def reject_canceled_night
      return unless @match_night.canceled?

      redirect_back_to_schedule alert: t('admin.matches.canceled', label: @match_night.label)
    end

    def reject_played_night
      return unless @match_night.played?

      redirect_back_to_schedule alert: t('admin.matches.played', label: @match_night.label)
    end

    def match_params
      params.expect(match: %i[home_team_id away_team_id])
    end

    def matchup(match)
      "#{match.home_team.name} vs #{match.away_team.name}"
    end

    def redirect_back_to_schedule(**flash)
      redirect_to admin_match_nights_path(season: @match_night.season), **flash
    end
  end
end
