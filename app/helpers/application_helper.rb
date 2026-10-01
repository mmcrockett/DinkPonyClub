# frozen_string_literal: true

module ApplicationHelper
  def dollars(cents)
    number_to_currency(cents / 100.0)
  end

  def dollars_input_value(cents)
    format('%.2f', cents / 100.0)
  end
end
