# frozen_string_literal: true

module Dollars
  def self.to_cents(value)
    (BigDecimal(value.to_s.delete('$,').strip) * 100).round
  rescue ArgumentError
    nil
  end
end
