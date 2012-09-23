class AddSourceToPics < ActiveRecord::Migration
  def change
    add_column :pics, :source, :string
  end
end
