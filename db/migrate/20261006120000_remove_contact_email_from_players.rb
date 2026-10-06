class RemoveContactEmailFromPlayers < ActiveRecord::Migration[8.1]
  def change
    remove_column :players, :contact_email, :string, limit: 254
  end
end
