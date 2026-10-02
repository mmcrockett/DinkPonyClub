# frozen_string_literal: true

module StandingsHelper
  PODIUM_KEYS = { 1 => 'first', 2 => 'second', 3 => 'third' }.freeze

  def podium_label(rank)
    t("standings.show.podium.#{PODIUM_KEYS.fetch(rank)}")
  end

  FORM_CHIP_CLASSES = { 'W' => 'bg-dpc-green', 'L' => 'bg-red-700', 'T' => 'bg-gray-400' }.freeze

  def form_chip_classes(outcome)
    FORM_CHIP_CLASSES.fetch(outcome)
  end

  def standings_diff(diff)
    diff.positive? ? "+#{format_points(diff)}" : format_points(diff)
  end
end
