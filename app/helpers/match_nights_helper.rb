# frozen_string_literal: true

module MatchNightsHelper
  def match_night_status_label(match_night)
    return t('match_nights.schedule.canceled') if match_night.canceled?
    return t('match_nights.schedule.playoffs') if match_night.playoff?
    return t('match_nights.schedule.final') if match_night.complete?

    t('match_nights.schedule.scheduled')
  end

  def match_night_status_classes(match_night)
    return 'bg-gray-200 text-gray-600' if match_night.canceled?
    return 'bg-dpc-navy text-white' if match_night.playoff?
    return 'bg-dpc-green text-white' if match_night.complete?

    'bg-gray-100 text-gray-600'
  end

  def match_score_label(match)
    return t('match_nights.schedule.vs') unless match.complete?

    result = MatchResult.new(match)
    "#{format_points(result.home_points)} - #{format_points(result.away_points)}"
  end

  def format_points(points)
    number_with_precision(points, precision: 1, strip_insignificant_zeros: true)
  end

  AVAILABILITY_CHECKED_CLASSES = {
    'in' => 'has-checked:border-dpc-green has-checked:bg-dpc-green has-checked:text-white',
    'maybe' => 'has-checked:border-amber-400 has-checked:bg-amber-400 has-checked:text-dpc-navy',
    'out' => 'has-checked:border-red-700 has-checked:bg-red-700 has-checked:text-white'
  }.freeze

  AVAILABILITY_SELECTED_CLASSES = {
    'in' => 'border-dpc-green bg-dpc-green text-white',
    'maybe' => 'border-amber-400 bg-amber-400 text-dpc-navy',
    'out' => 'border-red-700 bg-red-700 text-white'
  }.freeze

  def availability_status_label(status)
    t("match_nights.schedule.availability.#{status}")
  end

  def availability_select_options(status)
    options = MatchAvailability.statuses.keys.map { |value| [availability_status_label(value), value] }
    status ? options : [[t('match_nights.schedule.availability.unanswered'), ''], *options]
  end

  def availability_checked_classes(status)
    AVAILABILITY_CHECKED_CLASSES.fetch(status)
  end

  def availability_selected_classes(status)
    AVAILABILITY_SELECTED_CLASSES.fetch(status)
  end
end
