# frozen_string_literal: true

module MatchupSummary
  Summary = Data.define(:names, :pupr, :rating)

  def self.build(players, ratings)
    found = players.filter_map { |player| ratings.for(player.id) }
    Summary.new(names: players.map(&:full_name), pupr: mean(found.map(&:pupr), 2),
                rating: mean(found.map(&:elo), 0)&.to_i)
  end

  def self.mean(values, digits)
    (values.sum / values.size).round(digits) if values.any?
  end
end
