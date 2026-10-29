# frozen_string_literal: true

class CourtScheduleForm
  include ActiveModel::Model

  attr_reader :match_night, :cells

  def initialize(match_night:, cells: {})
    @match_night = match_night
    @cells = cells.to_h.transform_values { |courts| courts.to_h.transform_values(&:to_s) }
  end

  validate :references_exist
  validate :lines_appear_once

  def save
    return false unless valid?

    ActiveRecord::Base.transaction { replace_assignments }
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.record.errors.full_messages.to_sentence)
    false
  end

  private

  def placements
    @placements ||= cells.flat_map do |slot_id, courts|
      courts.filter_map do |court, value|
        match_id, position = value.split('-').map(&:to_i) if value.present?
        [slot_id.to_i, court.to_i, match_id, position] if match_id
      end
    end
  end

  def replace_assignments
    CourtAssignment.where(match_id: match_night.matches.select(:id)).delete_all
    placements.each do |slot_id, court, match_id, position|
      CourtAssignment.create!(match_slot_id: slot_id, court: court, match_id: match_id, position: position)
    end
  end

  def references_exist
    errors.add(:base, 'That time or line is not part of this match night.') unless placements.all? { |p| known?(*p) }
  end

  def known?(slot_id, _court, match_id, position)
    slot_ids.include?(slot_id) && match_ids.include?(match_id) && match_night.line_positions.include?(position)
  end

  def lines_appear_once
    lines = placements.map { |_slot, _court, match_id, position| [match_id, position] }
    errors.add(:base, 'A line can only be placed once.') if lines.uniq.size != lines.size
  end

  def slot_ids
    @slot_ids ||= match_night.match_slots.pluck(:id)
  end

  def match_ids
    @match_ids ||= match_night.matches.pluck(:id)
  end
end
