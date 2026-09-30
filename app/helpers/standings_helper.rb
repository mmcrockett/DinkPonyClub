# frozen_string_literal: true

module StandingsHelper
  PODIUM_KEYS = { 1 => 'first', 2 => 'second', 3 => 'third' }.freeze

  def podium_label(rank)
    t("standings.show.podium.#{PODIUM_KEYS.fetch(rank)}")
  end

  def standings_diff(diff)
    diff.positive? ? "+#{format_points(diff)}" : format_points(diff)
  end
end
