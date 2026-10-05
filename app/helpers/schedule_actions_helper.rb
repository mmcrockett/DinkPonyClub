# frozen_string_literal: true

module ScheduleActionsHelper
  def schedule_icon_link(icon, label, path)
    link_to path, title: label, class: 'inline-flex h-8 w-8 items-center justify-center rounded-md border ' \
                                       'border-gray-200 text-dpc-green hover:bg-gray-50' do
      safe_join([render('shared/icon', name: icon, class: 'h-5 w-5'), tag.span(label, class: 'sr-only')])
    end
  end

  def scorecard_icon_link(match)
    if match.complete?
      schedule_icon_link('document-text', t('match_nights.schedule.scorecard'), match_path(match))
    elsif can_edit_scorecard?(match)
      schedule_icon_link('pencil-square', t('match_nights.schedule.enter_results'), edit_match_path(match))
    end
  end

  def lineup_icon_link(match, team, lineup_teams)
    return unless lineup_teams.include?(team)

    schedule_icon_link('clipboard-document-list', t('match_nights.schedule.set_lineup', team: team.name),
                       edit_match_team_lineup_path(match, team))
  end
end
