# frozen_string_literal: true

class ClubhouseSeason < ApplicationRecord
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]{1,60}\z/ }
  validates :payload, presence: true

  def snapshot
    payload.deep_dup.merge('revision' => lock_version)
  end
end
