# frozen_string_literal: true

module TableFingerprint
  def self.for(*tables)
    selects = tables.map { |name| "(SELECT COUNT(*) FROM #{name}), (SELECT MAX(updated_at) FROM #{name})" }
    ApplicationRecord.connection.select_rows("SELECT #{selects.join(', ')}").first
  end
end
