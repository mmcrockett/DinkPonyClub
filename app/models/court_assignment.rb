# frozen_string_literal: true

class CourtAssignment < ApplicationRecord
  COURTS = (1..4).to_a.freeze

  belongs_to :match
  belongs_to :match_slot

  validates :court, inclusion: { in: COURTS }
  validates :position, inclusion: { in: ->(assignment) { assignment.match&.line_positions || [] } },
                       uniqueness: { scope: :match_id }
  validates :court, uniqueness: { scope: :match_slot_id }
  validate :slot_is_on_the_match_night

  private

  def slot_is_on_the_match_night
    return unless match && match_slot
    return if match_slot.match_night_id == match.match_night_id

    errors.add(:match_slot, "must belong to this match's night")
  end
end
