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

  SLOT_PREFERENCE_CHECKED_CLASSES = {
    'thumbs_up' => 'has-checked:border-dpc-green has-checked:bg-dpc-green',
    'meh' => 'has-checked:border-amber-400 has-checked:bg-amber-400',
    'thumbs_down' => 'has-checked:border-red-700 has-checked:bg-red-700'
  }.freeze

  SLOT_PREFERENCE_SELECTED_CLASSES = {
    'thumbs_up' => 'border-dpc-green bg-dpc-green',
    'meh' => 'border-amber-400 bg-amber-400',
    'thumbs_down' => 'border-red-700 bg-red-700'
  }.freeze

  def slot_preference_label(preference)
    t("match_nights.schedule.slot_preference.#{preference}")
  end

  def slot_preference_aria_label(preference)
    t("match_nights.schedule.slot_preference_aria.#{preference}")
  end

  def slot_preference_marks(slots, preferences)
    safe_join(slots.map { |slot| slot_preference_mark(slot, preferences[slot.id]) })
  end

  def slot_preference_mark(slot, preference)
    glyph = preference ? slot_preference_label(preference) : '?'
    description = "#{slot.label}: #{slot_preference_aria_label(preference || 'none')}"
    tag.span(class: preference ? nil : 'text-gray-400', title: description) do
      safe_join([tag.span(glyph, aria: { hidden: true }), tag.span(description, class: 'sr-only')])
    end
  end

  def slot_preference_checked_classes(preference)
    SLOT_PREFERENCE_CHECKED_CLASSES.fetch(preference)
  end

  def slot_preference_selected_classes(preference)
    SLOT_PREFERENCE_SELECTED_CLASSES.fetch(preference)
  end

  def availability_status_label(status)
    t("match_nights.schedule.availability.#{status}")
  end

  def team_availability_classes(status)
    AVAILABILITY_SELECTED_CLASSES.fetch(status, 'border-gray-300 bg-white text-dpc-navy')
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
