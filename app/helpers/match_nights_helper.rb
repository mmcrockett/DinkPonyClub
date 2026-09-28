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

  AVAILABILITY_STATUS_KEYS = { 'in' => 'im_in', 'maybe' => 'maybe', 'out' => 'im_out' }.freeze

  def availability_status_label(status)
    t("match_nights.schedule.#{AVAILABILITY_STATUS_KEYS.fetch(status)}")
  end
end
