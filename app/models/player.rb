# frozen_string_literal: true

class Player < ApplicationRecord
  has_many :roster_spots, dependent: :destroy
  has_many :teams, through: :roster_spots
  has_many :seasons, through: :roster_spots

  enum :status, { active: 'active', inactive: 'inactive' }

  normalizes :email, with: ->(email) { email.strip.downcase.presence }

  validates :first_name, :last_name, presence: true
  validates :email, uniqueness: true, allow_nil: true

  scope :by_name, -> { order(:first_name, :last_name) }
  scope :admins, -> { where(admin: true) }

  def self.authenticate_from_google(auth)
    return nil unless auth.extra.raw_info.email_verified

    email = auth.info.email.to_s.strip.downcase.presence
    player = find_by(google_uid: auth.uid) || (email && find_by(email: email))
    return nil unless player&.active?

    player.record_google_sign_in!(auth, email)
    player
  end

  def self.locate_by_email!(email)
    normalized = email.to_s.strip.downcase
    find_by(email: normalized) || raise(ActiveRecord::RecordNotFound, "No player with email #{normalized}.")
  end

  def record_google_sign_in!(auth, email)
    update!(google_uid: auth.uid, email: self.email || email,
            avatar_url: auth.info.image, last_signed_in_at: Time.current)
  end

  def full_name
    "#{first_name} #{last_name}"
  end
end
