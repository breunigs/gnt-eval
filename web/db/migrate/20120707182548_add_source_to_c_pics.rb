class AddSourceToCPics < ActiveRecord::Migration
  def change
    add_column :c_pics, :source, :string
  end
end
