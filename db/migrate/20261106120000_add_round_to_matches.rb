class AddRoundToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :round, :string, limit: 20
  end
end
