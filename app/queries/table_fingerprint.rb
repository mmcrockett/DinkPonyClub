# frozen_string_literal: true

module TableFingerprint
  def self.for(*models)
    subqueries = models.flat_map do |model|
      table = model.arel_table
      [table.project(Arel.star.count), table.project(table[:updated_at].maximum)]
    end
    query = Arel::SelectManager.new.project(*subqueries.map { |subquery| Arel::Nodes::Grouping.new(subquery) })
    ApplicationRecord.connection.select_rows(query).first
  end
end
