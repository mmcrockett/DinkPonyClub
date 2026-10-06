# frozen_string_literal: true

class AnnouncementForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  AUDIENCES = %w[roster all].freeze

  attribute :subject, :string
  attribute :body, :string
  attribute :audience, :string, default: 'roster'

  validates :subject, :body, presence: true
  validates :audience, inclusion: { in: AUDIENCES }

  def recipients(season, audience: self.audience)
    audience == 'all' ? Player.active.by_name : season.players.active.by_name
  end
end
