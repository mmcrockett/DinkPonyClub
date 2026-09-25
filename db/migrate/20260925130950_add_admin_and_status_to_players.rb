# frozen_string_literal: true

class AddAdminAndStatusToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :admin, :boolean, null: false, default: false
    add_column :players, :status, :string, limit: 20, null: false, default: 'active'
  end
end
