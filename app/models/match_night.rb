# frozen_string_literal: true

class MatchNight < ApplicationRecord
  belongs_to :season
  has_many :matches, dependent: :destroy
  has_many :match_availabilities, dependent: :destroy
  has_many :match_slots, -> { order(:starts_at) }, dependent: :destroy, inverse_of: :match_night
  has_many :slot_availabilities, through: :match_slots
  has_many :games, through: :matches

  validates :played_on, presence: true
  validates :label, presence: true, length: { maximum: 60 }
  validate :played_on_unchanged_once_played, on: :update
  before_validation :clear_default_lines_count
  validate :lines_count_within_season, if: -> { lines_count && lines_count_changed? }
  validate :lines_count_unchanged_once_played, on: :update

  after_update :move_slots_to_played_on, if: :saved_change_to_played_on?
  after_update :drop_picks_beyond_line_count, if: :saved_change_to_lines_count?

  scope :chronological, -> { order(:played_on) }
  scope :upcoming, -> { where(played_on: Date.current..) }
  scope :without_matches, -> { where.not(id: Match.select(:match_night_id)) }

  AVAILABILITY_CUTOFF_HOUR = 12

  def line_count
    lines_count || season.lines_per_match
  end

  def line_positions
    (1..line_count).to_a
  end

  def availability_cutoff_at
    played_on&.in_time_zone&.change(hour: AVAILABILITY_CUTOFF_HOUR)
  end

  def availability_open?
    played_on.present? && Time.current < availability_cutoff_at
  end

  def results_locked_at
    played_on&.next_day&.end_of_day
  end

  def results_locked?
    played_on.present? && Time.current > results_locked_at
  end

  def past?
    played_on.present? && played_on < Date.current
  end

  def played?
    games.exists?
  end

  def complete?
    !canceled? && matches.any? && matches.all?(&:complete?)
  end

  private

  def played_on_unchanged_once_played
    return unless played_on_changed? && played?

    errors.add(:played_on, 'cannot change after a game has been played')
  end

  def clear_default_lines_count
    self.lines_count = nil if lines_count == season&.lines_per_match
  end

  def lines_count_within_season
    return if lines_count.between?(1, season.lines_per_match)

    errors.add(:lines_count, "must be between 1 and #{season.lines_per_match}")
  end

  def lines_count_unchanged_once_played
    return unless lines_count_changed? && played?

    errors.add(:lines_count, 'cannot change after a game has been played')
  end

  def drop_picks_beyond_line_count
    LineupPick.where(match_id: matches.select(:id), position: (line_count + 1)..).delete_all
  end

  def move_slots_to_played_on
    match_slots.each do |slot|
      time = slot.starts_at.in_time_zone
      slot.update!(starts_at: Time.zone.local(played_on.year, played_on.month, played_on.day, time.hour, time.min))
    end
  end
end
